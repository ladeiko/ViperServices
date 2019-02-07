//
//  Service1.swift
//  ViperServicesDemo
//
//  Created by Siarhei Ladzeika on 5/5/18.
//  Copyright © 2018 BPMobile. All rights reserved.
//

import Foundation
import ViperServices

protocol Service1: class {
    func foo()
}

class Service1Impl: Service1, ViperService {
    
    func setupDependencies(_ container: ViperServicesContainer) -> [AnyObject]? {
        return [ // depends on
            container.resolve() as Service2
        ]
    }
    
    func boot(launchOptions: [UIApplication.LaunchOptionsKey : Any]?, completion: @escaping ViperServiceBootCompletion) {
        print("boot 1 called")
        completion(.succeeded)
    }
    
    func shutdown(completion: @escaping ViperServiceShutdownCompletion) {
        print("Service1Impl shutdown completed")
        completion()
    }
    
    func foo() {
        print("foo 1 called")
    }
    
    func totalBootCompleted(_ result: ViperServicesContainerBootResult) {
        print("totalBootCompleted 1")
    }
    
}
