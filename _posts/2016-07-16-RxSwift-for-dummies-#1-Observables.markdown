---
title: RxSwift For Dummies 🐣 Part 1
---

**Functional Reactive Programming** is one of those things you have to try yourself to really start appreciating. It's the one piece of the puzzle that I was missing to glue all the patterns like MVVM, VIPER, [Coordinators/Routing](http://khanlou.com/2015/10/coordinators-redux/).

If you don't know what **FRP** is, don't worry for now - you'll be able to discover it yourself in this tutorial.

Digging through [RxSwift](https://github.com/ReactiveX/RxSwift) made me feel enlightened and saved, but also massively confused. Trust me, you'll feel the same.

It takes a couple of hours to get used to the idea, but when you do, you don't want to go back.

In this tutorial, I'll try to save you these precious hours by explaining everything step by step... You know, like to a dummy 😙

### The Why?

UI programming is mostly about reacting to some asynchronous tasks. We're taught to implement that with observer patterns: I'm pretty sure you're familiar with delegates by now. Delegating is a cool pattern, but it gets really tiring...  
  
{: .center}
![Crying](images/cry.jpg)

* Delegating is a lot of boilerplate code: creating a protocol, creating a delegate variable, implementing protocol, setting the delegate
* The boilerplate reptition often makes you forget things, like setting the delegate (`object.delegate = self`)
* The cognitive load is quite high: it takes quite a lot of jumping through files to find out what's what

RxSwift takes care of that and more! It enables you to create observer patterns in a declarative way (reduces cognitive load) and without any boilerplate code.

I've just started a project and I didn't create one delegate and I'm a happy, happy man 🐸

### Observable 📡

Ok, enough talking, let's get to it, but let's start simple.

Let's start from the basic building block in RxSwift: the `Observable`. It's actually pretty simple: the `Observable` does some work and observers can react to it.

{% highlight swift %}
let observable = Observable<String>.create { (observer) -> Disposable in
    
    dispatch_async(dispatch_get_main_queue(), {
    	// Simulate some work
        NSThread.sleepForTimeInterval(10)
        observer.onNext("Hello dummy 🐣")
        observer.onCompleted()
    })
    
    return NopDisposable.instance
} 
{% endhighlight %}

Ok, we have an `Observable`. This is a **cold** ❄️ observable: it will start executing only when an observer subscribes. A **hot** 🔥 observable executes even if it doesn't have any observers. 

We'll cover the difference and examples in the next parts, so don't worry, but for now you have to understand that: the `Hello dummy 🐣` value will not be emitted just because you instantiated an ❄️`Observable` object. The ❄️`Observable` is frozen and **will start executing only when you add an observer**.

Let's analyze step by step what's happening:
{% highlight swift %}
dispatch_async(...)
{% endhighlight %}

The `Observable` executes code on the main thread (unless programmed otherwise) so let's use a simple `dispatch_async` to not block it. RxSwift has a mechanism called *Schedulers* that we could use instead, but let's leave that for later when you're less of a dummy 🐔.

{% highlight swift %}
observer.onNext("Hello")
{% endhighlight %}

An `Observable`'s time of work is also called a **sequence**. Throughout it's sequence it can send an infinite number of elements and we use the `onNext` method to emit these.

{% highlight swift %}
observer.onCompleted()
{% endhighlight %}

When it's finished it can send a `Completed` or `Error` event, after which it cannot produce more elements and it releases the closure along with it's references.

{% highlight swift %}
return NopDisposable.instance
{% endhighlight %}

Each `Observable` has to return a `Disposable`.

Use `NopDisposable.instance` if you don't need to dispose of anything. 
If you look into the [`NopDisposable`](https://github.com/ReactiveX/RxSwift/blob/master/RxSwift/Disposables/NopDisposable.swift) implementation it does completely nothing - just empty methods. 

#### Disposable

The `Disposable` that needs to be returned in the `Observable` is used to  clean up the `Observable` if it doesn't have a chance to complete the work normally. For example you can use the `AnonymousDisposable`:

{% highlight swift %}
return AnonymousDisposable {
    connection.close()
    database.closeImportantSomething()
    cache.clear()
}
{% endhighlight %}

The `Disposable` is called only when an `Observer` is disposed of prematurely: when it gets deallocated, or `dispose()` is called manually. Most of the times the `dispose()` is called automatically thanks to **Dispose Bags**.

### Observer 🕵

Our `Observable` is cold ❄️. It won't start executing until we start observing it.

{% highlight swift %}
let disposeBag = DisposeBag()

...

observable.subscribeNext { (element) in
  print(element)
}.addDisposableTo(disposeBag)
{% endhighlight %}

That's the way you subscribe. Subscription is created and a `Disposable` (a record of that subscription) is returned by the `subscribeNext` method.

The `Observable` has started work and after 10 seconds you'll see this printed out:

{% highlight text %}
Hello dummy 🐣
{% endhighlight %}

`subscribeNext` will only react to `Next` events. You can also use `subscribeCompleted` and `subscribeError`.

#### Dispose Bag 🗑

The only cryptic thing here is the `addDisposableTo` method.

>Dispose bags are used to return ARC like behavior to RX.
>When a DisposeBag is deallocated, it will call dispose on each of the added disposables.            

You add the `Disposable`s you create when you subscribe to the bag. When the bag's `deinit` is called the `Disposable`s (subscriptions) that didn't finish will be disposed of.

It's used to dispose of old references that you pass in the closure and resources that are not needed anymore: for example an open HTTP connection, a database connection or a cache.

If you don't understand now, don't worry, a concrete example is coming.

### Observable operators

`create` is just one of many ways to create an `Observable`. Take a look into ReactiveX [official documentation ](http://reactivex.io/documentation/operators.html)for a list of operators. Let's take a look at some of them.

#### Just

{% highlight swift %}
let observable = Observable<String>.just("Hello again dummy 🐥");
observable.subscribeNext { (element) in
    print(element)
}.addDisposableTo(disposeBag)
        
observable.subscribeCompleted { 
    print("I'm done")
}.addDisposableTo(disposeBag)
{% endhighlight %}

{% highlight text %}
Hello again dummy 🐥
I'm done
{% endhighlight %}

`just` *just* creates an observable that emits one value once and that's it. So the sequence in that example would be: `.Next("Hello")` -> `.Completed`

#### Interval

{% highlight swift %}
let observable = Observable<Int>.interval(0.3, scheduler: MainScheduler.instance)
observable.subscribeNext { (element) in
   print(element)
}.addDisposableTo(disposeBag)
{% endhighlight %}

{% highlight text %}
0
1
2
3
...
{% endhighlight %}

`interval` is a very specific operator that increments an `Int` from 0 every `0.3` (in this example) seconds. The scheduler is used to define the threading/async behavior.

#### Repeat

{% highlight swift %}
let observable = Observable<String>.repeatElement("This is fun 🙄")
observable.subscribeNext { (element) in
   print(element)
}.addDisposableTo(disposeBag)
{% endhighlight %}

{% highlight text %}
This is fun 🙄
This is fun 🙄
This is fun 🙄
This is fun 🙄
...
{% endhighlight %}

`repeat` repeats a given value infinitely. Again, you can control the threading behavior with a `SchedulerType`.

As you probably noticed, these are not very exciting, but it's good to know that there are other operators. One more important thing to notice is that it's a start of the *functional* part of RxSwift.

### Real life example

Ok, let's wrap this up and let's do a quick example. Our knowledge of RxSwift is quite limited, so let's use a simple `MVC` case. Let's create a model that will create an `Observable` that fetches data from *google.com*. Fun! 🎉

{% highlight swift %}
import Foundation
import RxCocoa
import RxSwift

final class GoogleModel {
    
    func createGoogleDataObservable() -> Observable<String> {
        
        return Observable<String>.create({ (observer) -> Disposable in
            
            let session = NSURLSession.sharedSession()
            let task = session.dataTaskWithURL(NSURL(string:"https://www.google.com")!) { (data, response, error) in
                
                // We want to update the observer on the UI thread
                dispatch_async(dispatch_get_main_queue(), {
                    if let err = error {
                        // If there's an error, send an Error event and finish the sequence
                        observer.onError(err)
                    } else {
                        let googleString = NSString(data: data!, encoding: NSASCIIStringEncoding) as String?
                        //Emit the fetched element
                        observer.onNext(googleString!)
                        //Complete the sequence
                        observer.onCompleted()
                    }
                })
                
            }
            
            task.resume()
            
            return AnonymousDisposable {
                //Cancel the connection if disposed
                task.cancel()
            }
        })
    }
}
{% endhighlight %}

That's pretty simple: the `createGoogleDataObservable` creates an `Observable` we can subscribe to. The `Observable` creates a data task and fetches the *google.com* website.

{% highlight swift %}
dispatch_async(dispatch_get_main_queue()...
{% endhighlight %}

The data task of `NSURLSession` is executed on a background thread, so we need to update Observers on the UI queue. Remember that we could use *schedulers*, but I'll cover that in a more advanced stage.

{% highlight swift %}
return AnonymousDisposable {
 task.cancel()
}
{% endhighlight %}

The `Disposable` is a great mechanism: if the observer stops observing the data task will be cancelled.

Now the observer part:

{% highlight swift %}
import UIKit
import RxCocoa
import RxSwift

class ViewController: UIViewController {
    
    //The usual way to create dispose bags
    //When the view controller is deallocated the dispose bag
    //Will be released and will call dispose() on it's Disposables/Subscriptions
    let disposeBag = DisposeBag()
    let model = GoogleModel()
    
    @IBOutlet weak var googleText: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Remember about [weak self]/[unowned self] to prevent retain cycles!
        model.createGoogleDataObservable().subscribeNext { [weak self] (element) in
            self?.googleText.text = element
        }.addDisposableTo(disposeBag)
        
    }
}
{% endhighlight %}

Amazing, huh? No protocols, no delegates, just a declarative definition of what should happen when there's a new event. 

Don't forget about `[weak self]` or `[unowned self]` in the closure to avoid retain cycles.

There's a more **reactive** way to implement setting the text that's called *binding*, but we're too 🐣 to get into that now.

#### Dispose Bag Example

As you might've noticed, the `disposeBag` is an instance variable of our `ViewController`:

{% highlight swift %}
class ViewController: UIViewController {
    
let disposeBag = DisposeBag()
{% endhighlight %}

When the view controller gets deinitialized, it will also release the `disposeBag`.

If the `disposeBag` is released, it's `deinit` will be called and our `AnonymousDisposable` will be called on our `Observable` and the data task will be cancelled and the connection will be closed if it didn't have a chance to finish! 

I hope this clearly explains the mechanism of dispose bags.

### That's it!

[Here's the code for the example project](https://github.com/michalciurus/michalciurus.github.io/tree/master/Code/RxSwiftTutorial).

This wraps it up. You've learned how to create observables and observers, how disposing works and hopefully you can see how this is better than the usual observer patterns.

Hang tight for the next part of the tutorial which will be about functional operators, the whole *functional* part in RxSwift.













