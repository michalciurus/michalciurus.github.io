---
title: RxSwift Safety Manual 📚
---

RxSwift gives you a lot of useful tools to make your coding more pleasurable, but it also can bring you a lot of headaches and... bugs 😱 After three months of using it actively I think I can give you some tips to avoid the problems I encountered.

### Side Effects

*Side Effect* in computer science may be hard to understand, because it's a very broad term. I think [this Stackoverflow thread](http://softwareengineering.stackexchange.com/questions/40297/what-is-a-side-effect) does a good job of explaining it.

So basically, a function/closure/... is said to have a side effect if it changes the state of the app somewhere.

In the context of RxSwift:

{% highlight swift %}
var counter = 1

let observable = Observable<Int>.create { (observer) -> Disposable in
   // No side effects
   observer.onNext(1)
   return Disposables.create()
}

let observableWithSideEffect = Observable<Int>.create { (observer) -> Disposable in
   // There's the side effect: it changes something, somewhere (the counter)
   counter = counter + 1
   observer.onNext(counter)
   return Disposables.create()
}
{% endhighlight %}

Why is that important in RxSwift? Because a cold❄️ signal (like the one we just created) **starts new work every time it's observed** !

Let's observe on `observableWithSideEffect` twice:

{% highlight swift %}
 observableWithSideEffect
     .subscribe(onNext: { (counter) in
         print(counter)
     })
 .addDisposableTo(disposeBag)
 
 observableWithSideEffect
     .subscribe(onNext: { (counter) in
         print(counter)
     })
 .addDisposableTo(disposeBag)
{% endhighlight %}

We would expect it to print `2` and `2`, right? Wrong. It prints `2`, `3`, because each subscription creates a separate execution, so the code inside the closure is executed twice and the **side effect(counter incrementation) happens twice**.

It means that if you put a network request inside, it **would execute two times**!

How do we fix this? By turning the cold observable into a hot one 💡! We do this using `publish`, `connect`/`refCount` operators. Here's a whole [tutorial explaining this in detail](http://www.tailec.com/blog/understanding-publish-connect-refcount-share).

{% highlight swift %}
let observableWithSideEffect = Observable<Int>.create { (observer) -> Disposable in
 counter = counter + 1
 observer.onNext(counter)
 return Disposables.create()
}.publish()
// publish returns an observable with a shared subscription(hot).
// It's not active yet

observableWithSideEffect
 .subscribe(onNext: { (counter) in
     print(counter)
 })
.addDisposableTo(disposeBag)

observableWithSideEffect
 .subscribe(onNext: { (counter) in
     print(counter)
 })
.addDisposableTo(disposeBag)

// connect starts the hot observable
observableWithSideEffect.connect()
.addDisposableTo(disposeBag)
{% endhighlight %}

It'll print `2`, `2`.

Most of time time it's enough if you just use the more high level `shareReplay` operator. It uses the `refCount` operator and `replay`. `refCount` is like `connect`, but it's managed automatically - it stars when there's at least one observer. `replay` is useful to emit some elements to observers "late to the party".

{% highlight swift %}
let observableWithSideEffect = Observable<Int>.create { (observer) -> Disposable in
 counter = counter + 1
 observer.onNext(counter)
 return Disposables.create()
}.shareReplay(1)

observableWithSideEffect
 .subscribe(onNext: { (counter) in
     print(counter)
 })
.addDisposableTo(disposeBag)

observableWithSideEffect
 .subscribe(onNext: { (counter) in
     print(counter)
 })
.addDisposableTo(disposeBag)

{% endhighlight %}

### Main Queue

When observing in the view controller and updating the UI you never know on which thread/queue does the  subscription happen. You always have to make sure it's happening on the main queue, if you're updating UI.

{% highlight swift %}
observableWithSideEffect
    .observeOn(MainScheduler.instance)
    .subscribe(onNext: { (counter) in
        print(counter)
    })
.addDisposableTo(disposeBag)
{% endhighlight %}

### Error Events

If you have a stream of observables bound together and there's an error event on the far end all the observables will stop observing! If on the first end there's UI, it will just stop responding. You have to carefully plan your API and think of what's going to happen when `completed` and `error` events are passed in your observables.

{% highlight swift %}
viewModel
.importantText
.bindTo(myImportantLabel.rx_text)
.addDisposableTo(disposeBag)
{% endhighlight %}

If `importantText` sends an `error` event for some reason, the binding/subscription will be disposed.

If you want to prevent that from happening you use `catchErrorJustReturn`

{% highlight swift %}
viewModel
.importantText
.catchErrorJustReturn("default text")
.bindTo(myImportantLabel.rx_text)
.addDisposableTo(disposeBag)
{% endhighlight %}

### Driver

`Driver` is an `Observable` with `observeOn`, `catchErrorJustReturn` and `shareReplay` operators already applied. If you want to expose a secure API in your view model it's a good idea to always use a `Driver`! 

{% highlight swift %}
viewModel
.importantText
.asDriver(onErrorJustReturn: 1)
.drive(myImportantLabel.rx_text)
{% endhighlight %}

### Reference Cycles

Preventing memory leaks caused by reference cycles takes a lot of patience. When using **any** variable in the observe closure it gets captured as a **strong** reference.

{% highlight swift %}
//In a view controller:

viewModel
	.priceString
    .subscribe(onNext: { text in
       self.priceLabel.text = text
    })
    .addDisposableTo(self.disposeBag)
{% endhighlight %}

The view controller has a strong reference to the view model. And now, the view model has a strong reference to the view controller because we're using `self` in the closure. Pretty much [basic Swift stuff](http://krakendev.io/blog/weak-and-unowned-references-in-swift).

Here's a small tip:

{% highlight swift %}
viewModel
	.priceString
    .subscribe(onNext: { [unowned self] text in
       self.priceLabel.text = text
    })
    .addDisposableTo(self.disposeBag)
{% endhighlight %}

Use `[unowned self]` without worrying it might be dangerous when adding disposable to `self.disposeBag`. If self is `nil`, then the dispose bag is `nil`, so the closure will never be called when `self` is nil - app will never crash and you don't have to deal with optionals 🤗

`self` is not the only case you have to watch out for! You have to think of **every** variable that gets captured in the closure. 

{% highlight swift %}
//Outside the view controller

viewModel
	.priceString
    .subscribe(onNext: { [weak viewController] text in
       viewController?.priceLabel.text = text
    })
    .addDisposableTo(self.disposeBag)
{% endhighlight %}

It might get very complex, that's why it's a very good idea to keep closures short! If a closure is longer than 3-4 lines consider moving the logic to a separate method - you'll see all the "dependencies" clearly and you'll be able to decide what you want to capture weakly/strongly.

### Managing your subscriptions

Remember to always clear the subscriptions you don't need anymore. I had an issue where I didn't clear my subscriptions, the cells were reused, new subscriptions were created each time causing some very spectacular bugs.

{% highlight swift %}
let reuseBag = DisposeBag()

// Called each time a cell is reused
func configureCell() {
  viewModel
  .subscribe(onNext: { [unowned self] (element) in
                self.sendOpenNewDetailsScreen()
            })
}


// Creating a new bag for each cell
override func prepareForReuse() {
  reuseBag = DisposeBag()
}
{% endhighlight %}


RxSwift is very complex, but if you set your own rules in the project and adhere to them, you should be fine 😇 It's very important to be consistent in the RxSwift API you're exposing for each layer - it helps with catching bugs.
