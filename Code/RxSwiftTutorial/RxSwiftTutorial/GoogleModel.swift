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
            
            let session = URLSession.shared
            let task = session.dataTask(with: URL(string:"https://www.google.com")!) { (data, response, error) in
                
                // We want to update the observer on the UI thread
                DispatchQueue.main.async {
                    if let err = error {
                        // If there's an error, send an Error event and finish the sequence
                        observer.onError(err)
                    } else {
                        if let googleString = String(data: data!, encoding: .ascii) {
                            //Emit the fetched element
                            observer.onNext(googleString)
                        } else {
                            //Show error to the user if we weren't able to parse the response data
                            observer.onNext("Unable to parse the data from google!")
                        }
                        //Complete the sequence
                        observer.onCompleted()
                    }
                }
            }
            
            task.resume()
            
            return Disposables.create(with: {
                //Cancel the connection if disposed
                task.cancel()
            })
        })
    }
}
