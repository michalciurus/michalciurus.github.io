---
title: App Navigation Routing Algorithm 📃
---

Recently I've been experimenting with [ReSwift](https://github.com/ReSwift/ReSwift) and [Katana](https://github.com/BendingSpoons/katana-swift) and I created my first OSS library in Swift: [KatanaRouter](https://github.com/michalciurus/KatanaRouter).

Katana and ReSwift are based on Redux, and the idea is simple: keep all of your state in one structure. The thing is, it also should contain the navigation state, that's why [ReSwift-Router](https://github.com/ReSwift/ReSwift-Router) was born.

I was inspired by *ReSwift-Router* to create a similar library for *Katana*, but I've taken another approach.

It has lead me to creating an algorithm that can be used in any routing really, not just Redux-style architecture.

### Problem

An app navigation state is a tree:

```

            UITabBarController(active)
               +     +   +
   +-----------+     |   +------------+
   |                 |                |
   |                 +                |
   +                                  +
Tab One(active)    Tab Two         Tab Three

   +                  +                +
   |                  |                |
   |                  |                |
   |                  +                |
   +                                   +
ChildVc(active)     ChildVc          ChildVc
```

It's simple enough to change that tree if you want to push a destination, or pop one. It gets much more complicated if you want to do more complex operations.

That's why, for the needs of *KatanaRouter* I created a diffing algorithm for trees that represent a navigation state.

### Solution

Let's say that we have navigation state tree A and tree B. The task is to return all the important differences in these trees. I've distinguished 4 different actions:

• **Push** - Singular push action happened somewhere in the tree.

• **Pop** - Singular pop action happened somewher in the tree.

• **Change** - A more complex action. At least two singular pop/push actions.

• **ChangeActiveDestination** - Called when there's a new destination set to active e.g. child in a tab controller.

So, I had to create an algorithm that accepts two trees and returns an array of  these actions. What's important is the order:

1. First we have to traverse through inactive nodes and finish with active last.
2. You have to return all the pop actions in post order
3. You have to return all pushes in pre order
4. Any "Change" actions, which contain pops + pushes, you have to return in the order of the push actions.

So I wrote a `NavigationTreeDiff` class that does exactly this.

{% highlight swift %}

enum NavigationTreeDiffAction {
    case push(nodeToPush: NavigationTreeNode)
    case pop(nodeToPop: NavigationTreeNode)
    case changed(poppedNodes: [NavigationTreeNode], pushedNodes: [NavigationTreeNode])
    case changedActiveChild(currentActiveChild: NavigationTreeNode)
}

class NavigationTreeDiff {
    
    /// Returns an array of actions, which are the differences between lastState and currentState
    /// This method **does not change the state of the trees in any way**
    /// - Parameters:
    ///   - lastState: last state tree
    ///   - currentState: current state tree
    /// - Returns: array of actions in order. Pops are always first.
    static func getNavigationDiffActions(lastState: NavigationTreeNode?, currentState: NavigationTreeNode?) -> [NavigationTreeDiffAction] {
        
        var nodesToPop: [NavigationTreeNode] = []
        var nodesToPush: [NavigationTreeNode] = []
        
        //1. Find all the pops: nods that were in the last tree, but aren't in the current.
        //   The order of the nodes is in post-order.
        
        lastState?.traverse(postOrder: true) { node in
            if !containsNode(node, in: currentState) {
                nodesToPop.append(node)
            }
        }
        
        //2. Find all pushes: nodes that are in the current state, but weren't in the last one.
        //   The order of the nodes is in pre-order.
        currentState?.traverse(postOrder: false) { node in
            if !containsNode(node, in: lastState) {
                nodesToPush.append(node)
            }
        }
        
        // We need unique parents to go through them and find group all the pushes and pops
        // that happen on the same parent
        let uniquePushParents: [NavigationTreeNode?] = getUniqueParents(nodesToPush)
        var filteredSinglePopNodes = nodesToPop
        var insertActions: [NavigationTreeDiffAction] = []
        
        //3. Now we're merging all the complex pushes and pushes that have the corresponding pops
        //   We're doing it to create `change` actions.
        for uniquePushParent in uniquePushParents {
            let sameParentFilter: (NavigationTreeNode) -> Bool = {
                $0.parentNode == uniquePushParent
            }
            let differentParentFilter: (NavigationTreeNode) -> Bool = {
                $0.parentNode != uniquePushParent
            }
            
            let pushesWithSameParent = nodesToPush.filter(sameParentFilter)
            let popsWithSameParent = nodesToPop.filter(sameParentFilter)
            
            // If it's just a singular push, without a corresponding pop, it's a simple `push` action
            guard pushesWithSameParent.count > 1 || popsWithSameParent.count > 0 else {
                insertActions.append(.push(nodeToPush: pushesWithSameParent[0]))
                continue
            }
            
            // We're taking the children from the parent, to keep the original *order* of children
            let nodesToPush = uniquePushParent?.children ?? []
            // Otherwise, we're creating a `change` action with all the pushes and pops for the same parent
            insertActions.append(.changed(poppedNodes: popsWithSameParent, pushedNodes: nodesToPush))
            // We're removing the pops with the parent, because the difference has already been served in a `change` event
            filteredSinglePopNodes = filteredSinglePopNodes.filter(differentParentFilter)
        }
        
        
        return getPopActions(from: filteredSinglePopNodes) +
            insertActions +
            getChangedActiveChildActions(lastState: lastState, currentState: currentState)
    }

{% endhighlight %}

[Here's the whole class](https://github.com/michalciurus/KatanaRouter/blob/master/KatanaRouter/NavigationTreeDiff.swift) if you want to take a look.

### Usability

As I already mentioned, this algorithm can be used in any app routing, not only Redux-style Katana, or ReSwift.

It's really simple, you just have to create a navigation tree, manipulate it any way you want, get the differences actions, go through these actions and apply them in your UI layer.

This is not limited to `UIViewController`s. You can as easily model a `UIViewController` destination which has children `UIView` destinations in a `UIScrollView` and freely change them around.

That's it! Please let me know if you have any feedback or ideas, I'd love to hear it! 🖖🏻






