---
title: Dynamic UI Testing HTTP Mocking
---

[Joe's post](http://masilotti.com/ui-testing-stub-network-data/) covers everything you need to know about mocking HTTP responses when UI testing. 

I needed to go a step further. I needed to change the HTTP mocked responses **dynamically/on-the-fly** while the app was already running.

Why? To test user interactions. One of the UI test cases I had covered creating a new post in the feed. I needed the mocked response to return a normal feed at first, and then after user has tapped the create post button:

{% highlight swift %}

app.buttons["createPostButton"].tap()

{% endhighlight %}

I needed it to return a **different mocked response** - one with an added post. It's just one of many interaction tests we had in our testing cases. I needed to find a solution.

You have no way of messaging the app's API while running UI tests - it's a different process. You can't dynamically (while running a test) change the stubbed response. There's no way to call [OHHTTPStubs](https://github.com/AliSoftware/OHHTTPStubs) in the app process, from the UI tests process to change the current stubbed response. That leaves us with hosting a mock server, right? There's a mock server running and you contact it if you need to switch the responses dynamically.

I started wondering in which language should I implement the mock server. But then - thank god 🙏🏻 - I consulted [@Cojoj](https://twitter.com/cojoj) and he asked me: *"Why not run the server **inside** the unit tests process?"*. It turned out to be a great idea! I used the awesome [Swifter](https://github.com/httpswift/swifter) framework for that.

• It's very easy to setup.

• It's very easy to maintain.

• No additional CI steps are needed.

• You don't put any testing code into your production code - everything stays in the UI tests target.

All you need is some response JSON files in your UI testing target and this class:

{% highlight swift %}

import Foundation
import Swifter

enum HTTPMethod {
    case POST
    case GET
}

class HTTPDynamicStubs {
    
    var server = HttpServer()
    
    func setUp() {
        setupInitialStubs()
        try! server.start()
    }
    
    func tearDown() {
        server.stop()
    }
    
    func setupInitialStubs() {
        for stub in initialStubs {
            setupStub(url: stub.url, filename: stub.jsonFilename, method: stub.method)
        }
    }
    
    public func setupStub(url: String, filename: String, method: HTTPMethod = .GET) {
        let testBundle = Bundle(for: type(of: self))
        let filePath = testBundle.path(forResource: filename, ofType: "json")
        let fileUrl = URL(fileURLWithPath: filePath!)
        let data = try! Data(contentsOf: fileUrl, options: .uncached)
        let json = dataToJSON(data: data)
        
        let response: ((HttpRequest) -> HttpResponse) = { _ in
            return HttpResponse.ok(.json(json as AnyObject))
        }
        
        switch method  {
        case .GET : server.GET[url] = response
        case .POST: server.POST[url] = response
        }
    }
    
    func dataToJSON(data: Data) -> Any? {
        do {
            return try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
        } catch let myJSONError {
            print(myJSONError)
        }
        return nil
    }
}

struct HTTPStubInfo {
    let url: String
    let jsonFilename: String
    let method: HTTPMethod
}

let initialStubs = [
    HTTPStubInfo(url: "/api/feed", jsonFilename: "feed", method: .GET),
    HTTPStubInfo(url: "/api/createPost", jsonFilename: "createPost", method: .POST),
]

{% endhighlight %}

That's it! It's very easy to use.

{% highlight swift %}

class UITests: XCTestCase {
    
    let app = XCUIApplication()    
    let dynamicStubs = HTTPDynamicStubs()
    
    override func setUp() {
        super.setUp()
        dynamicStubs.setUp()
    }

    override func tearDown() {
        super.tearDown()
        dynamicStubs.tearDown()
    }
    
    func testPostCreation() {
        ...
        // Dynamically change the response to see if the feed gets refreshed and post is there
        dynamicStubs.setupStub(url: "/api/feed", filename: "feedWithCreatedPost")
        app.buttons["createPostButton"].tap()
        ...            
    }

{% endhighlight %}


Of course you have to use `http://localhost:8080/` address in your *production* app for UI testing. Fortunately, that's the only thing that you have to add to your production code. Just make sure it doesn't leak to your production app 😨😎

This approach allows you to push your UI testing to a higher level. I hope you liked it! Reach me on [Twitter](https://twitter.com/MichaelCiurus) if you have any questions or suggestions 😘


