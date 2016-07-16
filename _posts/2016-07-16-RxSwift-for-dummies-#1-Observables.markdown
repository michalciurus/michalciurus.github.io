**Functional Reactive Programming** is one of those things you have to try yourself to really start appreciating. It's the one piece of the puzzle that I was missing to glue all the patterns like MVVM, VIPER, [Coordinators/Routing](http://khanlou.com/2015/10/coordinators-redux/).

If you don't know what **FRP** is, don't worry for now - you'll be able to discover it yourself.

Digging through [RxSwift](https://github.com/ReactiveX/RxSwift) made me feel enlightened and saved, but also massively confused.

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

So to emphasize: the `Hello dummy 🐣` value will not be emitted just because you instantiated an `Observable` object.

Let's analyze step by step what's happening:
{% highlight swift %}
dispatch_async(...)
{% endhighlight %}

The `Observable` executes code on the same thread as the `Observer` (unless programmed otherwise) so let's use a simple `dispatch_async` to not block it.

{% highlight swift %}
observer.onNext("Hello")
{% endhighlight %}

{% highlight swift %}
//^ Is actually a convenience method of:
observer.on(.Next("Hello"))
{% endhighlight %}

An `Observable`'s time of work is also called a **sequence**. Throughout it's sequence it can send an infinite number of elements and we use the `onNext` method to emit these.

{% highlight swift %}
observer.onCompleted()
{% endhighlight %}

{% highlight swift %}
//^ Again a convenience method, the Error event has the same
observer.on(.Completed)
{% endhighlight %}

When it's finished it can send a `Completed` or `Error` event, after which it cannot produce more elements and it releases the closure along with it's references.

{% highlight swift %}
return NopDisposable.instance
{% endhighlight %}

Each `Observable` has to return a `Disposable`.

Use `NopDisposable.instance` if you don't need to dispose of anything. 
If you look into the [`NopDisposable`](https://github.com/ReactiveX/RxSwift/blob/master/RxSwift/Disposables/NopDisposable.swift) implementation it does completely nothing - just empty methods. The `Disposable` that needs to be returned is used to  clean up the `Observable` if it doesn't have a chance to complete the work normally. For example you can use the `AnonymousDisposable`:

{% highlight swift %}
return AnonymousDisposable {
	  connection.close()
      database.closeImportantSomething()
      cache.clear()
}
{% endhighlight %}

It'll be called only when disposed of prematurely: when an observer gets deallocated, or dispose is called manually - we'll talk about disposing later.

### Observer 🕵

Our `Observable` ❄️ is cold. It won't start executing until we start observing it.

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

`subscribeNext` will only react to `Next` events. You can also use `subscribeCompleted` and `subscribeError`. These all are also convenience methods of a `subscribe` method. I suggest always using the convenience methods.

The only cryptic thing here is the `addDisposableTo` method.

>Dispose bags are used to return ARC like behavior to RX.
>When a DisposeBag is deallocated, it will call dispose on each of the added disposables.            

You add the `Disposable`s you create when you subscribe to the bag. When the bag's `deinit` is called the `Disposable`s in the bag get disposed off - it's that simple.

It's used to dispose of old references that you pass in the closure and resources that are not needed anymore: for example an open HTTP connection.

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

As you probably noticed, these are not very exciting, but it's good to know that there are other operators. One more important thing to notice is that it's start of the *functional* part of RxSwift.

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
                
                dispatch_async(dispatch_get_main_queue(), {
                    if let err = error {
                        observer.onError(err)
                    } else {
                        let googleString = NSString(data: data!, encoding: NSASCIIStringEncoding) as String?
                        observer.onNext(googleString!)
                        observer.onCompleted()
                    }
                })
                
            }
            
            task.resume()
            
            return AnonymousDisposable {
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

The data task of `NSURLSession` is executed on a background thread, so we need to update Observers on the UI queue.

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
    
    let disposeBag = DisposeBag()
    let model = GoogleModel()
    
    @IBOutlet weak var googleText: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        model.createGoogleDataObservable().subscribeNext { [weak self] (element) in
            self?.googleText.text = element
        }.addDisposableTo(disposeBag)
    }
}
{% endhighlight %}

Amazing, huh? No protocols, no delegates, just a declarative definition of what should happen when there's a new event. 

Don't forget about `[weak self]` or `[unowned self]` in the closure to avoid retain cycles.

{% highlight swift %}
class ViewController: UIViewController {
    
let disposeBag = DisposeBag()
{% endhighlight %}

When the view controller gets deinitialized, it will also release the `disposeBag`. If the `disposeBag` is released, the `Disposable` will be called and the data task will be cancelled if it didn't have a chance to finish! I hope this clearly explains the mechanism of dispose bags.

There's a more reactive way to implement setting the text that's called *binding*, but we'll cover that in one of the next parts of tutorial focused on `Subject`s.

This wraps it up. You've learned how to create observables and observers, how disposing works and hopefully you can see how this is better than the usual observer patterns. 

Hang tight for the next part of the tutorial which will be about functional operators in RxSwift.













