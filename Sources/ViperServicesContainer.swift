/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2018-present Siarhei Ladzeika - sergey.ladeiko@gmail.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation

public struct ViperServiceBootFailureResult {
    public let service: ViperService
    public let error: Error
}

public enum ViperServicesContainerBootResult {
    case succeeded
    case failed(failedServices:[ViperServiceBootFailureResult])
}

public typealias ViperServicesContainerBootCompletion = (_ result: ViperServicesContainerBootResult) -> Void
public typealias ViperServicesContainerShutdownCompletion = () -> Void

enum ViperServicesContainerError: Error {
    case serviceAlreadyRegistered
    case multiFunctionServiceNotAllowed
    case alreadyBooted
    case bootCanceled
    case youTriedToResolveServiceThatIsNotReadyYet
}

/**
 *  Protocol for viper services container.
 */
public protocol ViperServicesContainer: class {
    
    /**
     *  Registers service implementation for service in container.
     *  Typical use:
     *
     *      protocol MyService: ViperService { ... }
     *      class MyServiceImpl: MyService {}
     *      ...
     *      container.register(MyServiceImpl() as MyService)
     *
     *  - parameter service: service to be registered.
     *
     *  - note: should be called before boot.
     */
    func register<T>(_ service: T) throws
    
    /**
     *  Locates service implementation for specified service protocol.
     *
     *  - returns: service implementation.
     */
    func resolve<T>() -> T
    
    /**
     *  Locates service implementation for specified service protocol.
     *
     *  - returns: service implementation or nil.
     */
 
    func tryResolve<T>() -> T?
    
    /**
     *  Boots service container and all services registred before.
     *  It is recommended to call it in app delegate right after launching.
     *
     *  - parameter launchOptions: launch options passed to application delegate
     *
     *  - parameter completion: completion block called after all services boot completed or some of them failed;
     *                          in case of failure any 'resolve' calls should not be used.
     */
    func boot(launchOptions: [UIApplication.LaunchOptionsKey: Any]?, completion: @escaping ViperServicesContainerBootCompletion)
    
    /**
    * Typically should be called in 'func applicationWillTerminate(_ application: UIApplication)'
    */
    func shutdown(completion: @escaping ViperServicesContainerShutdownCompletion)
}
