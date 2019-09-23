//
//  AppDelegate.swift
//  ViperServicesDemoMacOS
//
//  Created by Cheslau Bachko on 9/18/19.
//  Copyright © 2019. All rights reserved.
//

import Cocoa
import ViperServices

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // use DefaultViperServicesContainer or implement your own container
    let services: ViperServicesContainer = DefaultViperServicesContainer()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        
        // Override point for customization after application launch.
        
        try! services.register(Service1Impl() as Service1)
        
        let srv2 = services.tryResolve() as Service2?
        
        try! services.register(Service2Impl() as Service2)
        
        services.boot(launchOptions: aNotification.userInfo) { (result) in
            
            print("boot completed")
            
            switch result {
            case .succeeded:
                
                let alert = NSAlert()
                alert.messageText = "Boot completed OK"
                alert.addButton(withTitle: "OK")
                alert.runModal()
                
                // All ok, now it is safe to use any service!
                (self.services.resolve() as Service1).foo()
                (self.services.resolve() as Service2).foo()
                
            case let .failed(failedServices):
                
                let alert = NSAlert()
                alert.messageText = "FAILED with error: \(failedServices.first!.error.localizedDescription)"
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
}

