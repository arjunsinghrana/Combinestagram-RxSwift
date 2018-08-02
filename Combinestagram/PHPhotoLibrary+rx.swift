//
//  PHPhotoLibrary+rx.swift
//  Combinestagram
//
//  Created by Arjun Singh on 02/08/18.
//  Copyright © 2018 Underplot ltd. All rights reserved.
//

import Foundation
import Photos
import RxSwift

extension PHPhotoLibrary {
    static var authorized: Observable<Bool> {
        return Observable.create({ (observer) -> Disposable in
            
            DispatchQueue.main.async {
                if authorizationStatus() == .authorized {
                    observer.onNext(true)
                    observer.onCompleted()
                } else {
                    observer.onNext(false)
                    
                    requestAuthorization({ (status) in
                        observer.onNext(status == .authorized)
                        observer.onCompleted()
                    })
                }
            }
            
            return Disposables.create()
        })
    }
}
