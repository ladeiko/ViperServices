//
//  Service2.swift
//  ViperServicesDemo
//
//  Created by Siarhei Ladzeika on 5/5/18.
//  Copyright © 2018 BPMobile. All rights reserved.
//

import Foundation
import ViperServices

protocol Service2: class {
    func foo()
}

enum Service2Error: Error {
    case SomeError
}

class Service2Impl: Service2, ViperService {
    
    private weak var container: ViperServicesContainer!
    
    func setupDependencies(_ container: ViperServicesContainer) -> [AnyObject]? {
        self.container = container
        return nil
    }
    
    func boot(launchOptions: ViperServicesLaunchOptions?, completion: @escaping ViperServiceBootCompletion) {
        print("boot 2 called")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            switch arc4random() % 2 {
            case 0:
                completion(.failed(error: Service2Error.SomeError))
            default:
                completion(.succeeded)
            }
            
        }
    }
    
    func shutdown(completion: @escaping ViperServiceShutdownCompletion) {
        print("Service2Impl shutdown completed")
        completion()
    }
    
    func foo() {
        print("foo 2 called")
    }
    
    func totalBootCompleted(_ result: ViperServicesContainerBootResult) {
        print("totalBootCompleted 2")
    }
    
}
