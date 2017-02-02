//
//  ViewController.swift
//  RxSwiftTutorial
//
//  Created by Michal Ciurus on 09/07/16.
//  Copyright © 2016 MC. All rights reserved.
//

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
        model.createGoogleDataObservable()
            .subscribe(onNext: {  [weak self] (element) in
                self?.googleText.text = element
            })
        .addDisposableTo(disposeBag)
    }
}



