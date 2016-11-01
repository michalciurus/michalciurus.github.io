---
title: RxSwift For Dummies 🐤 Part 3
---

Let's learn about the next building block of RxSwift: **Subjects**

We've learned about the `Observable`, right? I think we can all agree that when you have a reference to an `Observable` it's *output* only. You can subscribe to it's *output*, but you can't change it.

A `Subject` is also an *output* but it's also an **input**! That means that you can **dynamically**/**imperatively** emit new elements in a sequence.

{% highlight swift %}
 let subject = PublishSubject<String>()
 
 // As you can see the subject casts nicely, because it's an Observable subclass
 let observable : Observable<String> = subject
 
 observable
     .subscribe(onNext: { text in
         print(text)
     })
     .addDisposableTo(disposeBag)
 
 // You can call onNext any time you want to emit a new item in the sequence
 subject.onNext("Hey!")
 subject.onNext("I'm back!")
{% endhighlight %}

`onNext` is the method you use to do the *input*.

It will of course print:

{% highlight text %}
"Hey!"
"I'm back!"
{% endhighlight %}

Why do we need subjects? To easily connect the declarative/RxSwift world with the imperative/normal world. Subjects feel more "natural" to programmers used to imperative programming. 

In a perfect, clean RxSwift implementation you [are discouraged to use subjects](https://github.com/ReactiveX/RxSwift/issues/487) - you should have a perfect stream of observables. Let's not bother our heads with it though, I'll explain that in a separate post, please use as much subjects as you want for now 😅

So that's basically it! Let's learn to control subjects now.

### Hot🔥 vs Cold❄️

I foreshadowed it in the first part of the tutorial. Now it's important to grasp, because subjects are the first hot observables we're encountering.

As we already established, when you create/declare an `Observable` using `create` it won't execute until there's an observer that observes on it. It'll start execution at the same moment something calls `subscribe` on it. That's why it's called a cold❄️ observable. If you don't remember you can take a quick look at [Part 1](http://swiftpearls.com/RxSwift-for-dummies-1-Observables.html)

A hot🔥 observable will emit it's elements even it if has no observers. And that's exactly what subjects do. 

{% highlight swift %}
 let subject = PublishSubject<String>()
 let observable : Observable<String> = subject
 // the observable is not being observed yet, so this value will not be caught by anything and won't be printed
 subject.onNext("Am I too early for the party?")
 
 observable
     .subscribe(onNext: { text in
         print(text)
     })
     .addDisposableTo(disposeBag)
 
 // This is called when there's 1 observer so it will be printed
 subject.onNext("🎉🎉🎉")
 {% endhighlight %}

Pretty straightforward, huh? If you understood the cold observable in Part 1, hot observable should give you no problems as it's more intuitive/natural.

### Subject Types

There are three commonly used subject types. They all behave almost the same with one difference: each one does something different with values emitted *before* the subscription happened.

##### • Publish Subject

As you could see in the experiment above the publish subject will **ignore** all elements that were emitted before `subscribe` have happened.

{% highlight swift %}
 let subject = PublishSubject<String>()
 let observable : Observable<String> = subject
 subject.onNext("Ignored...")
 
 observable
     .subscribe(onNext: { text in
         print(text)
     })
     .addDisposableTo(disposeBag)
 
 subject.onNext("Printed!")
{% endhighlight %}

You use it when you're just interested in future values.

##### • Replay Subject

Replay subject will repeat last **N** number of values, even the ones before the subscription happened. The **N** is the buffer, so for our example it's `3`:

{% highlight swift %}
let subject = ReplaySubject<String>().create(bufferSize: 3)
let observable : Observable<String> = subject

subject.onNext("Not printed!")
subject.onNext("Printed!")
subject.onNext("Printed!")
subject.onNext("Printed!")

observable
    .subscribe(onNext: { text in
        print(text)
    })
    .addDisposableTo(disposeBag)

subject.onNext("Printed!")
{% endhighlight %}

You use it when you're interested in **all** values of the subjects lifetime.

##### • Behavior Subject

Behavior subject will repeat only the **one** last value. Moreover it's initiated with a starting value, unlike the other subjects.

{% highlight swift %}
let subject = BehaviorSubject<String>(value: "Initial value")
let observable : Observable<String> = subject

subject.onNext("Not printed!")
subject.onNext("Not printed!")
subject.onNext("Printed!")

observable
    .subscribe(onNext: { text in
        print(text)
    })
    .addDisposableTo(disposeBag)

subject.onNext("Printed!")
{% endhighlight %}

You use it when you just need to know the last value, for example the array of elements for your table view.

### Binding

You can bind an `Observable` to a `Subject`. It means that the `Observable` will pass all it's values in the sequence to the `Subject`

{% highlight swift %}
let subject = PublishSubject<String>()
let observable = Observable<String>.just("I'm being passed around 😲")

subject
    .subscribe(onNext: { text in
        print(text)
    })
    .addDisposableTo(disposeBag)

observable
    //Passing all values including errors/completed
    .subscribe { (event) in
        subject.on(event)
}
.addDisposableTo(disposeBag)
{% endhighlight %}

There's sugar syntax to simplify it a little bit called `bindTo`:

{% highlight swift %}
let subject = PublishSubject<String>()
let observable = Observable<String>.just("I'm being passed around 😲")

subject
    .subscribe(onNext: { text in
        print(text)
    })
    .addDisposableTo(disposeBag)

observable
.bindTo(subject)
.addDisposableTo(disposeBag)
{% endhighlight %}

It will of course print `I'm being passed around 😲`. 

**Warning**

Binding **will** pass not only values, but also `completed` and `error` events on which case the `Subject` will get disposed and won't react to any more events - it will get killed.

### Quick Example

Let's modify the example from the first post a little.

{% highlight swift %}
import Foundation
import RxCocoa
import RxSwift

final class GoogleModel {
    
    let googleString = BehaviorSubject<String>(value: "")
    private let disposeBag = DisposeBag()
    
    func fetchNewString() {
        
        let observable = Observable<String>.create({ (observer) -> Disposable in
            
            let session = URLSession.shared
            let task = session.dataTask(with: URL(string:"https://www.google.com")! as URL) { (data, response, error) in
                
                // We want to update the observer on the UI thread
                DispatchQueue.main.async() {
                    if let err = error {
                        // If there's an error, send an Error event and finish the sequence
                        observer.onError(err)
                    } else {
                        let googleString = NSString(data: data!, encoding: 1 ) as String?
                        //Emit the fetched element
                        observer.onNext(googleString!)
                        //Complete the sequence
                        observer.onCompleted()
                    }
                }
            }
            
            task.resume()
            return Disposables.create {
                task.cancel()
            }
        })
        
        // Bind the observable to the subject
        observable
        .bindTo(googleString)
        .addDisposableTo(disposeBag)
    }
}
{% endhighlight %}

As you can see we have a view model that exposes a `googleString` subject that view controllers can subscribe to. We bind the observable to the subject, so when a reply from the server comes it'll emit it's value and it will get passed in the subject.

Seems easy, but there's a lot of traps to watch out for and that's what we'll talk about in the next post. See you around!




