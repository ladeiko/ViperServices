//
//  AppDelegate.swift
//  ViperServicesDemo
//
//  Created by Siarhei Ladzeika on 5/3/18.
//  Copyright © 2018 BPMobile. All rights reserved.
//

import UIKit
import ViperServices

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    // use DefaultViperServicesContainer or implement your own container
    let services: ViperServicesContainer = DefaultViperServicesContainer()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        try! services.register(Service1Impl() as Service1)
        
        _ = services.tryResolve() as Service2?
        
        try! services.register(Service2Impl() as Service2)
        
        services.boot(launchOptions: launchOptions) { (result) in
            
            print("boot completed")
            
            switch result {
            case .succeeded:
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "OK")
                self.window!.rootViewController?.present(vc, animated: true, completion: nil)
                
                // All ok, now it is safe to use any service!
                (self.services.resolve() as Service1).foo()
                (self.services.resolve() as Service2).foo()
                
            case let .failed(failedServices):
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "FAILED")
                self.window!.rootViewController?.present(vc, animated: false, completion: {
                    let alert = UIAlertController(title: "Error",
                                                  message: failedServices.first!.error.localizedDescription,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    vc.present(alert, animated: true, completion: nil)
                })
                
            }
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        
        /**
         * NOTE: applicationWillTerminate
         * https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623111-applicationwillterminate
         *
         * Your implementation of this method has approximately five seconds to perform any tasks and return.
         * If the method does not return before time expires, the system may kill the process altogether.
         */
        
        services.shutdown(completion: {
            print("shutdown completed")
        })
    }


}

