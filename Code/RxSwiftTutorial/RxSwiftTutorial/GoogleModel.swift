//
//  GoogleModel.swift
//  RxSwiftTutorial
//
//  Created by Michal Ciurus on 16/07/16.
//  Copyright © 2016 MC. All rights reserved.
//

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