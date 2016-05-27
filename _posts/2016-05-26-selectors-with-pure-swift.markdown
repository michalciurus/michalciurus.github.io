When reading [Andy's great post](https://medium.com/swift-programming/swift-selector-syntax-sugar-81c8a8b10df3#.nvjfxan9u) on how to sugar coat the awful syntax of selectors in Swift I figured there must be a way to get rid of selectors altogether and
go with **Pure Swift**.

Objective-C archaisms were a big letdown for me, when I started learning Swift. Well, no more!

###  😖#selector(tapped(_:))😖

{% highlight swift %}
 ...
 button.addTarget(self, action: #selector(tapped(_:)), forControlEvents: .TouchDown)
 }
    
 @objc func tapped( s : AnyObject) {
   print("Did press the button!")
 }
{% endhighlight %}

Yuuck! Everything about it is ugly: `#selector(tapped(_:))`, `@objc`...

{% highlight swift %}
button.addTarget(forControlEvents: .TouchDown) { (button) -> Void in
    print("Did press the button!")
}
{% endhighlight %}

Aaah... This looks much better, doesn't it ? It's almost like we can forget about the dinosaurs of the past.
Can we achieve that easily though? Well, let's try.

{% highlight swift %}
//Parameter is the type of parameter passed in the selector
public class ClosureSelector<Parameter> {
    
    public let selector : Selector
    private let closure : ( Parameter ) -> ()
    
    init(withClosure closure : ( Parameter ) -> ()){
        self.selector = #selector(ClosureSelector.target(_:))
        self.closure = closure
    }
    
 // Unfortunately we need to cast to AnyObject here
    @objc func target( param : AnyObject) {
        closure(param as! Parameter)
    }
}
{% endhighlight %}

Nothing too fancy. Just a wrapper to hide all the ugliness and forget about it forever.
Is that all ? Well, let's try and use it.

{% highlight swift %}

func demo() {

let closureSelector = ClosureSelector<UIButton> { (button) in
    print("Did press the button!")
}

button.addTarget(closureSelector, action: closureSelector.selector, forControlEvents: .TouchDown)
}

...
button.sendActionsForControlEvents(UIControlEvents.TouchDown)
...
{% endhighlight %}

Nope 😢 The text doesn't get printed - the selector doesn't get called.

* **Target objects in UIKit are kept as weak references to avoid reference cycles**

The object that contains our closure gets released when when the function is executed.

Sure, we can keep a reference to each `ClosureSelector` object, but let's just agree to not do that.

There must be some magic way...

### Obj-C runtime to the rescue!

Let's use object association and extensions to keep the reference to the wrapper, while the button is alive.

{% highlight swift %}

var handle: Int = 0

extension UIButton {
    
    func addTarget(forControlEvents controlEvents : UIControlEvents, withClosure closure : (UIButton) -> Void) {
        let closureSelector = ClosureSelector<UIButton>(withClosure: closure)
        objc_setAssociatedObject(self, &handle, closureSelector, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        self.addTarget(closureSelector, action: closureSelector.selector, forControlEvents: controlEvents)
    }

}
{% endhighlight %}

Doesn't look as bad as I thought it would. Besides, you write it once for each class (yes `NSTimer`, you're next!) and forget about it.
It'll keep the `ClosureSelector` object alive as long as the `UIButton` is alive - object association works very similarily to properties in Objective-C, hence the `OBJC_ASSOCIATION_RETAIN_NONATOMIC` flag. 

On a different note, it's strange that `objc_setAssociatedObject` works with pure Swift classes, huh ?

{% highlight swift %}
button.addTarget(forControlEvents: .TouchDown) { (button) -> Void in
    print("Did press the button!")
}
{% endhighlight %}

Done! That sure looks pretty to me 🦄 I like it and I'm sure going to use it in my Swift code.

I hope that UIKit gets translated to pure swift one day, and we won't have to resolve to such drastic measures.





