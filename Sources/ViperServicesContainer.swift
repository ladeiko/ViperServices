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

public enum ViperServicesContainerBootError: Error, LocalizedError {
    case common([ViperServiceBootFailureResult])
    public var errorDescription: String? {
        switch self {
            case let .common(result):
                return result
                    .map({ "'\($0.service)' failed with: \($0.error)" })
                    .joined(separator: ".")
        }
    }
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
public protocol ViperServicesContainer: AnyObject {
    
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
    func boot(launchOptions: ViperServicesLaunchOptions?, completion: @escaping ViperServicesContainerBootCompletion)
    
    /**
    * Typically should be called in 'func applicationWillTerminate(_ application: UIApplication)'
    */
    func shutdown(completion: @escaping ViperServicesContainerShutdownCompletion)
    
    /**
     *  Executes specified block of code when after boot comletion.
     *  If boot completed at the moment of call, then block is executed right now.
     *  Code will be executed on the current queue if executed right now or on the main queue.
     */
    func safeExec(_ block: @escaping (() -> Void))
    
    /**
     * Executes specified block when passed service type is ready (complete booting).
     * Since 1.5.0
     */
    func waitFor<T: ViperService>(_ block: @escaping ((_ service: T) -> Void), on queue: DispatchQueue)
    func waitFor<T: ViperService>(_ block: @escaping ((_ service: T) -> Void))
    
}


public extension ViperServicesContainer {

#if swift(>=5.5)
    @available(iOS 13.0, *)
    func boot(launchOptions: ViperServicesLaunchOptions? = nil) async throws {
        try await withCheckedThrowingContinuation({ continuation in
            boot(launchOptions: launchOptions) {
                switch $0 {
                    case .succeeded:
                        continuation.resume(with: .success(()))
                    case let .failed(failedServices: failedServices):
                        continuation.resume(with: .failure(ViperServicesContainerBootError.common(failedServices)))
                }
            }
        })
    }

    @available(iOS 13.0, *)
    func shutdown() async {
        await withCheckedContinuation({ continuation in
            shutdown(completion: {
                continuation.resume(with: .success(()))
            })
        })
    }

    @available(iOS 13.0, *)
    func waitFor<T: ViperService>() async -> T {
        await withCheckedContinuation({ continuation in
            waitFor({
                continuation.resume(with: .success($0))
            })
        })
    }

    @available(iOS 13.0, *)
    func safeExec(_ block: @escaping (() -> Void)) async {
        await withCheckedContinuation({ continuation in
            safeExec {
                block()
                continuation.resume(with: .success(()))
            }
        })
    }

    @available(iOS 13.0, *)
    func safeExec(_ block: @escaping (() throws -> Void)) async throws {
        try await withCheckedThrowingContinuation({ continuation in
            safeExec {
                do {
                    try block()
                    continuation.resume(with: .success(()))
                }
                catch {
                    continuation.resume(with: .failure(error))
                }
            }
        })
    }
#endif

}
