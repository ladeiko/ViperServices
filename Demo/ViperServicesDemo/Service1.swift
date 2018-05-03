//
//  Service1.swift
//  ViperServicesDemo
//
//  Created by Siarhei Ladzeika on 5/5/18.
//  Copyright © 2018 BPMobile. All rights reserved.
//

import Foundation
import ViperServices

protocol Service1: ViperService {
    func foo()
}

class Service1Impl: Service1 {
    
    func setupDependencies(_ container: ViperServicesContainer) -> [ViperService]? {
        return [ // depends on
            container.resolve() as Service2
        ]
    }
    
    func boot(launchOptions: [UIApplicationLaunchOptionsKey : Any]?, completion: @escaping ViperServiceBootCompletion) {
        print("boot 1 called")
        completion(.succeeded)
    }
    
    func foo() {
        print("foo 1 called")
    }
    
}
