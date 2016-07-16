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



