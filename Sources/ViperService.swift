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

public enum ViperServiceBootResult {
    case succeeded
    case failed(error: Error)
}

public typealias ViperServiceBootCompletion = (_ result: ViperServiceBootResult) -> Void
public typealias ViperServiceShutdownCompletion = () -> Void

/**
 *  Common protocol for viper service
 */
public protocol ViperService: AnyObject {
    
    /**
     *  Method is called before service boot.
     *  Service must return a list of all services required by service in future.
     *  This information will be used to define the order of boot for all services.
     *  If service does not depend on any other services, then it can return nil or empty array.
     *
     * - parameter container:   parent container, service can save weak reference for further use.
     *
     * - returns: list of all services current service depends (services should conform to ViperService protocol) on or nil (empty).
     */
    func setupDependencies(_ container: ViperServicesContainer) -> [AnyObject]?
    
    /**
     *  It is called by container to initialize service. At this moment all services returned
     *  from 'setupDependencies' are ready for use.
     *
     * - parameter launchOptions:   options passed to application while boot.
     * - parameter completion:   completion block, should be called when service is ready
     */
    func boot(launchOptions: ViperServicesLaunchOptions?, completion: @escaping ViperServiceBootCompletion)
    
    /**
     * It is called when service must stop its work, just before deallocation.
     *
     * - parameter completion:   completion block, should be called when service shutdown is completed
     */
    func shutdown(completion: @escaping ViperServiceShutdownCompletion)
    
    /**
     * It is called when container began to boot all registered services.
     * Since version 1.3.0
     */
    func totalBootBegan()
    
    /**
     * It is called after all services completed boot process.
     * Since version 1.2.1
     */
    func totalBootCompleted(_ result: ViperServicesContainerBootResult)
}

/**
 *  Default implementations
 */
public extension ViperService {
    
    // Default implementation: no dependencies
    func setupDependencies(_ container: ViperServicesContainer) -> [AnyObject]? {
        return nil
    }
    
    // Default implementation: does nothing
    func boot(launchOptions: ViperServicesLaunchOptions?, completion: @escaping ViperServiceBootCompletion) {
        completion(.succeeded)
    }
    
    // Default implementation: does nothing
    func shutdown(completion: @escaping ViperServiceShutdownCompletion) {
        completion()
    }
    
    // Default implementation: does nothing
    func totalBootBegan() {}
    
    // Default implementation: does nothing
    func totalBootCompleted(_ result: ViperServicesContainerBootResult) {}
    
}
