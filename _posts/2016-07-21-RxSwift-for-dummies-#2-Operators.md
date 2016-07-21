---
title: RxSwift For Dummies 🐥 Part 2
---

Ok, we know the basics. Let's now try and inspect some interesting operators and discover the **F**unctional in **FRP**.

### Schedulers

Let's start with something I already mentioned, but didn't really explain: **schedulers**. 

Schedulers are used to easily tell the observables and observers on which threads/queues should they execute, or send notifications.

The most common operators connected to schedulers you'll use are `observeOn` and `subscribeOn`.

Normally the `Observable` will execute and send notifications on the same thread on which the observer subscribes on.

#### ObserveOn

`observeOn` specifies a scheduler on which the `Observable` will send the events to the observer. **It doesn't change the scheduler (thread/queue) on which it executes**. 

Let's take this example, very similar to the one from Part 1:

{% highlight swift %}
let observable = Observable<String>.create { (observer) -> Disposable in
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
        // Simulate some work
        NSThread.sleepForTimeInterval(10)
        dispatch_async(dispatch_get_main_queue(), {
            observer.onNext("Hello dummy 🐥")
            observer.onCompleted()
        })
        
    })
    return NopDisposable.instance
}
{% endhighlight %}

Let's assume that the observer is some kind of UI - `UIViewController` or `UIView`.

{% highlight swift %}
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
{% endhighlight %}

We're dispatching the work to a background queue, to not block the UI.

{% highlight swift %}
dispatch_async(dispatch_get_main_queue()...
{% endhighlight %}

Then we need to change back to the main queue to update the UI. I'm sure you're familiar with this dance already.

Let's refactor it using `observeOn`

{% highlight swift %}
let observable = Observable<String>.create { (observer) -> Disposable in
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
        // Simulate some work
        NSThread.sleepForTimeInterval(10)
        observer.onNext("Hello dummy 🐥")
        observer.onCompleted()
    })
    return NopDisposable.instance
}.observeOn(MainScheduler.instance)
{% endhighlight %}

We remove the `dispatch_async(dispatch_get_main_queue()` and add `.observeOn(MainScheduler.instance)`. This causes all events to be sent to observers through the main queue - it's that simple. The `Hello dummy 🐥` element can be safely used to set an UI element, because we're certain that it'll be passed on the main queue:

{% highlight swift %}
observable.subscribeNext { [weak self] (element) in
 self?.myUIText.text = element
}.addDisposableTo(disposeBag)
{% endhighlight %}

`observeOn` is probably the most common scheduler operator you'll use. You want the `Observable` to contain all the logic, threading etc. and you want your observer to be stupid and simple. Let's quickly investigate `subscribeOn` though, at it might prove useful.

#### SubscribeOn (Optional)

This is a more advanced operator. You can skip it for now and come back later 🐤

`subscribeOn` is very similar to `observeOn` but **it also changes the scheduler on which the `Observable` will execute work**.

{% highlight swift %}

let observable = Observable<String>.create { (observer) -> Disposable in
   // Simulate some work
   NSThread.sleepForTimeInterval(10)
   observer.onNext("Hello dummy 🐥")
   observer.onCompleted()
   return NopDisposable.instance
}
        observable.subscribeOn(ConcurrentDispatchQueueScheduler(globalConcurrentQueueQOS: .Default)).subscribeNext { [weak self] (element) in
 self?.myUIText.text = element
}.addDisposableTo(disposeBag)

{% endhighlight %}

As you can see I deleted the `dispatch_async(dispatch_get_global_queue...` in the `Observable` and it's the observer that tells the `Observable` to execute on a global queue to not block UI. This of course leads to an exception being thrown because as I mentioned: it causes the `Observable` to work on a global queue, but also **send events on a global queue, not on the UI queue**. We could just add a `dispatch_async` on the main queue, but we can also experiment, do something more interesting and add a `observeOn` operator.

{% highlight swift %}

let observable = Observable<String>.create { (observer) -> Disposable in
   // Simulate some work
   NSThread.sleepForTimeInterval(10)
   observer.onNext("Hello dummy 🐥")
   observer.onCompleted()
   return NopDisposable.instance
}.observeOn(MainScheduler.instance)
        observable.subscribeOn(ConcurrentDispatchQueueScheduler(globalConcurrentQueueQOS: .Default)).subscribeNext { [weak self] (element) in
 self?.myUIText.text = element
}.addDisposableTo(disposeBag)

{% endhighlight %}

After adding `.observeOn(MainScheduler.instance)` to the `Observable` we notice that it solved our problem. Why is it interesting? Because it shows that `observeOn` overrides `subscribeOn` in terms of which scheduler is used to send events!

When do we use `observeOn`? The most common scenario would be an `Observable` that doesn't execute long tasks (fetching data, calculating etc.) on a different queue/thread and blocks your thread. I don't imagine that will happen too often, but hey! it's always worth to know what tools you have in your box 🛠

#### Scheduler Types

As a RxSwift beginner it's fine to stick with `observeOn` and `MainScheduler.instance` so I'm going to cut here to not distract you too much. You can build your own custom `Scheduler` or use one of the already built in ones. [Here's more](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Schedulers.md) if you're that curious. It's quite simple and natural as it's just wrapped Grand Central Dispatch and `NSOperation`.

### Transforming Operators

Ok, so you already know two types of operators: creating operators (`create`, `interval`, `just`) and utility operators (`observeOn`, `subscribeOn`). Let's inspect some of the transforming operators.

#### Map

Very simple, yet powerful. Probably the one you'll use the most.

{% highlight swift %}

let observable = Observable<Int>.create { (observer) -> Disposable in
    observer.onNext(1)
    return NopDisposable.instance
}

let boolObservable : Observable<Bool> = observable.map { (element) -> Bool in
    if (element == 0) {
        return false
    } else {
        return true
    }
}

boolObservable.subscribeNext { (boolElement) in
    print(boolElement)
    }.addDisposableTo(disposeBag)

{% endhighlight %}

the `map` operator changes your sequence type. It maps an `Observable` so it emits a different type in a way you tell it to. In this example we map an `Int` of `1` to `true` and an `Int` of `0` to `false`.

This example will print:

{% highlight text %}
true
{% endhighlight %}

#### Scan

`scan` is more complicated. 

{% highlight swift %}

let observable = Observable<String>.create { (observer) -> Disposable in
    observer.onNext("D")
    observer.onNext("U")
    observer.onNext("M")
    observer.onNext("M")
    observer.onNext("Y")
    return NopDisposable.instance
}

observable.scan("") { (lastValue, currentValue) -> String in
	// The new value emmited is the LAST value emmited + current value:
    return lastValue + currentValue
    }.subscribeNext { (element) in
        print(element)
    }.addDisposableTo(disposeBag)
    }
}

{% endhighlight %}

Will print:

{% highlight text %}
D
DU
DUM
DUMM
DUMMY
{% endhighlight %}

`scan` allows you to change the current element **based on the last one emitted**. It's also said to **accumulate** elements. The `""` passed in the `scan` parameter is the seed: the starting value.

Still don't get it? Why would anyone use it, right? 

{% highlight swift %}

let observable = Observable<Int>.create { (observer) -> Disposable in
    observer.onNext(1)
    observer.onNext(2)
    observer.onNext(3)
    observer.onNext(4)
    observer.onNext(5)
    return NopDisposable.instance
}


observable.scan(1) { (lastValue, currentValue) -> Int in
    return lastValue * currentValue
    }.subscribeNext { (element) in
        print(element)
    }.addDisposableTo(disposeBag)
    }
}

{% endhighlight %}

Here's the `scan` operator to calculate a factorial of `5`, which will print `120`.

[Marin gives us a more useful example](http://rx-marin.com/post/rxswift-state-with-scan/) of a select/deselect state of a button:

{% highlight swift %}

myButton.rx_tap.scan(false) { lastState, newValue in
    return !lastState
}

{% endhighlight %}

Now that's something you can use, huh?

Of course, there are more transforming operators, but I think you get the idea now. You can go here to [read more](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/API.md).


### Filtering Operators

It's important to emit values, but it's also important to skip emitting them when needed - that's what fitering operators are for.

#### Filter

Decide yourself which ones you want to emit and which ones to skip!

{% highlight swift %}

let observable = Observable<String>.create { (observer) -> Disposable in
    observer.onNext("🎁")
    observer.onNext("💩")
    observer.onNext("🎁")
    observer.onNext("💩")
    observer.onNext("💩")
    return NopDisposable.instance
}

observable.filter { (element) -> Bool in
    return element == "🎁"
    }.subscribeNext { (element) in
        print(element)
    }.addDisposableTo(disposeBag)
}

{% endhighlight %}

Will print:

{% highlight text %}
🎁
🎁
{% endhighlight %}

#### Debounce

It's a pretty easy, but useful one.

{% highlight swift %}

observable.debounce(2, scheduler: MainScheduler.instance).subscribeNext { (element) in
    print(element)
}

{% endhighlight %}

`debounce` in this example just skips elements that aren't at least 2 seconds apart. So if an element will be emitted after `1` second after the last one, it'll be skipped, if it's emitted `2.5` seconds after the last one, it'll be emitted.

### Combining Operators

Combining operators let you take multiple observators and convert them into one.

#### Merge

`merge` just passes elements from multiple observables into one (merged) observable.

{% highlight swift %}

let observable = Observable<String>.create { (observer) -> Disposable in
    observer.onNext("🎁")
    observer.onNext("🎁")
    return NopDisposable.instance
}
        
let observable2 = Observable<String>.create { (observer) -> Disposable in
    observer.onNext("💩")
    observer.onNext("💩")
    return NopDisposable.instance
}
        
Observable.of(observable, observable2).merge().subscribeNext { (element) in
    print(element)
}.addDisposableTo(disposeBag)

{% endhighlight %}

{% highlight text %}

🎁
🎁
💩
💩

{% endhighlight %}

#### Zip

`zip` connects an element from each observable into one element.

{% highlight swift %}

let observable = Observable<String>.create { (observer) -> Disposable in
    observer.onNext("🎁")
    observer.onNext("🎁")
    return NopDisposable.instance
}
        
let observable2 = Observable<String>.create { (observer) -> Disposable in
    observer.onNext("💩")
    observer.onNext("💩")
    return NopDisposable.instance
}

[observable, observable2].zip { (elements) -> String in
    var result = ""
    for element in elements {
        result += element
    }
    return result
}.subscribeNext { (element) in
    print(element)
}.addDisposableTo(disposeBag)

{% endhighlight %}

{% highlight text %}

🎁💩
🎁💩

{% endhighlight %}

Now this is a very interesting operator. Let's say that you have two HTTP requests and you want to wait for them both to finish:

{% highlight swift %}

let observable = Observable<String>.create { (observer) -> Disposable in
    
    dispatch_async(dispatch_get_main_queue(), {
        NSThread.sleepForTimeInterval(3)
        observer.onNext("Fetched from server 2 " )
    })
    
    return NopDisposable.instance
}
        
let observable2 = Observable<String>.create { (observer) -> Disposable in
    
    dispatch_async(dispatch_get_main_queue(), { 
        NSThread.sleepForTimeInterval(2)
        observer.onNext("Fetched from server 1 ")
    })
    
    return NopDisposable.instance
}
        
[observable, observable2].zip { (elements) -> String in
    var result = ""
    for element in elements {
        result += element
    }
    return result
}.subscribeNext { (element) in
    print(element)
}.addDisposableTo(disposeBag)

{% endhighlight %}

`zip` will wait for each element in each `Observable` to finish and will emit a value that's a sum of both "requests.

### Other Operators

There's a lot of other interesting operators like `reduce`, or `takeUntil`, but I think you get the idea by now and you'll be easily capable to [discover them by yourself](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/API.md). The idea was to see how powerful they are and how easily and fast you're able to mold the sequences in terms of time, conditions or transformations.

### Mixing Operators

This tutorial doesn't need a concrete example project, but it can be useful to show you how easily you can mix operators.

Let's do this with a crazy idea: to change background color based on the current time.

{% highlight swift %}

Observable<NSDate>.create { (observer) -> Disposable in
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { 
        while true {
            NSThread.sleepForTimeInterval(0.01)
            observer.onNext(NSDate())
        }
    })
    return NopDisposable.instance

}
// We want to update on the main thread
.observeOn(MainScheduler.instance)
// We only want time intervals divisble by two, because why not
.filter { (date) -> Bool in
    return Int(date.timeIntervalSince1970) % 2 == 0
}
// We're mapping a date to some UIColor
.map { (date) -> UIColor in
    let interval : Int = Int(date.timeIntervalSince1970)
    let color1 = CGFloat( Double(((interval * 1) % 255)) / 255.0)
    let color2 = CGFloat( Double(((interval * 2) % 255)) / 255.0)
    let color3 = CGFloat( Double(((interval * 3) % 255)) / 255.0)
    
    return UIColor(red: color1, green:color2, blue: color3, alpha: 1)
}.subscribeNext { (color) in
    self.googleText.backgroundColor = color
}.addDisposableTo(disposeBag)

{% endhighlight %}

You can find more examples in the [RxSwfit playgrounds](https://github.com/ReactiveX/RxSwift/blob/master/Rx.playground/Pages/Combining_Operators.xcplaygroundpage/Contents.swift).

### That's it!

Wow, you really know a lot now! The only big thing left to teach you are **Subjects**. I know you must be hungry for some practical examples, but don't worry, they're coming!



