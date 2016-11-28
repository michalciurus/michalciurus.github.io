---
title: RxSwift MVVM API Manual 📃
---

Ok, we have all these tools, we're aware of all the dangers. Let's think now how to use it best to create a clear and safe API. Let's use MVVM as the context.

There are many approaches to writing an RxSwift API. My approach is: I use RxSwift as a very cool observer pattern, for managing async tasks and make use of it's awesome operators. I [do not strive to go *100% clean, declarative* RxSwfit](https://github.com/ReactiveX/RxSwift/issues/487).

Here are some tips I've learned over the time I'm using RxSwift.

###Be Consistent

It's the most important thing in any API! If you choose one approach: stick with it! 

Having that said, let's start with the basic: **input vs output**.

{% highlight swift %}
class FilterViewModel {
 
 //Input
 let filterButtonsEvents : BehaviorSubject<Int> 
 let filterSelectionEvent : PublishSubject<Int>
 
 //Output
 let currentFilter : Observable<Int>
 let shouldShowFilter : Observable<Bool>
}
{% endhighlight %}

There are a couple of combinations of how you can declare input/output but this is my favorite one.

#### Input

By having input as Subjects you can easily make use of many useful RxSwift operators. I think I use `throttle`, the most often.

{% highlight swift %}
filterButtonsEvents
.throttle(0.5, scheduler: MainScheduler.instance)
.subscribe(onNext: { [weak self] (counter) in
    self?.makeRequest()
})
{% endhighlight %}

You can also accept [input as `Observable` in the constructor](https://github.com/ReactiveX/RxSwift/blob/master/RxExample/RxExample/Examples/GitHubSignup/UsingVanillaObservables/GithubSignupViewModel1.swift).

#### Output

Remember to have ouput declared always as an `Observable`. Even if it's a `Subject`. Otherwise any external class could use it as input and we don't want that - it breaks encapsulation. The way I do it is just force cast when I want to emit a new element. Please let me know if you know a better way, because this is not pretty 😱

{% highlight swift %}
 (observable as! PublishSubject)
 .onNext("Ugly...")
{% endhighlight %}

### Safety

Remember the lecture about [RxSwift Safety](http://swiftpearls.com/RxSwift-Safety-Manual.html])? It's easy to remember all the rules in a simple example. It's much harder in a complex app with hundreds of observers. `Observable` type is a very broad type and doesn't say if the stream is hot, or cold, or if it runs on the main queue.

That's one of the reasons `Driver` was created! You're encouraged to [create your own *units*](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Units.md) and make the API more explicit.

`Driver` is your hot, main scheduler unit. We're missing a *cold* one, right? It's quite easy, to create! I just called it `Template`, because a *cold* observable is a template really, and you can use it and run it using `subscribe`.

{% highlight swift %}
class Template<Element> {
    let observable : Observable<Element>
    
    init(_ subscribe: @escaping (AnyObserver<Element>) -> Disposable) {
        observable = Observable.create(subscribe)
         .subscribeOn(MainScheduler.instance)
    }
}
{% endhighlight %}

So a `Template` is **guaranteed** to be cold and run on main schedule!

{% highlight swift %}
class MyViewModel {
 //Cold ❄️
 let createRequest : Template<Int>
 //Hot 🌶
 let shouldShowelement : Driver<Bool>
}
{% endhighlight %}

Now your API is clear and explicit!


### MVVM State Machine

Just a little bonus. Something that has been on my mind lately. Complex view controllers very often get very messy when it comes to managing state. Consider using a state machine in your view model to tell your view controller what it should do. Here's a [great article](http://curtclifton.net/generic-state-machine-in-swift) that could get you started.

• It could profoundly reduce the number of Observables in your MVVM API, merging it into one enum state, instead of many granular states. 

• It'll also force you to move move of your logic to your view model 

• It'll **make your code more declarative**!


👋



