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

/**
 *  Default implementation of ViperServicesContainer.
 */
@available(iOS 10.0, *)
open class DefaultViperServicesContainer: ViperServicesContainer {
    
    private var services: [String: ViperService] = [:]
    private var registrationOrder = [String]()
    private var names: [String: String] = [:]
    private var booted = false
    private var booting = [String]()
    private var _lock: os_unfair_lock_t

    // MARK: Life cycle
    
    public init() {
        self._lock = os_unfair_lock_t.allocate(capacity: 1)
        self._lock.initialize( to: os_unfair_lock_s() )
    }
    
    deinit {
        self._lock.deinitialize(count: 1)
        self._lock.deallocate()
    }
    
    // MARK: ViperServices
    
    open func register<T>(_ service: T) throws {
        
        assert(Thread.isMainThread)
        
        try! withLock { () -> Void in
            if booted {
                throw ViperServicesContainerError.alreadyBooted
            }
        }
        
        let key = "\(T.self)"
        
        if services[key] != nil {
            throw ViperServicesContainerError.serviceAlreadyRegistered
        }
        
        registrationOrder.append(key)
        services[key] = (service as! ViperService)
        
        let opaque: UnsafeMutableRawPointer = Unmanaged.passUnretained(service as AnyObject).toOpaque()
        let ptrStr = String(describing: opaque)
        
        if names[ptrStr] != nil {
            throw ViperServicesContainerError.multiFunctionServiceNotAllowed
        }
        
        names[ptrStr] = key
    }
    
    open func resolve<T>() -> T {
        let key = "\(T.self)"
        try! withLock { () -> Void in
            if booted && booting.contains(key) {
                throw ViperServicesContainerError.youTriedToResolveServiceThatIsNotReadyYet
            }
        }
        return services[key] as! T
    }
    
    open func boot(launchOptions: [UIApplicationLaunchOptionsKey: Any]?, completion: @escaping ViperServicesContainerBootCompletion) {
        
        assert(Thread.isMainThread)
        assert(!booted)
        
        withLock {
            booted = true
        }
        
        var completed = [String: ViperServiceBootResult]()
        var dependencies: Dictionary<String, [String]> = [:]
        
        for service in services.values {
            let key = name(of: service)
            if let deps = service.setupDependencies(self), !deps.isEmpty {
                dependencies[key] = deps.map({ name(of: $0) })
            }
            else {
                dependencies[key] = []
            }
        }
        
        withLock {
            booting = ((try! type(of: self).topo_sort(dependency_list: dependencies)) as NSArray).sortedArray(comparator: { (a, b) -> ComparisonResult in
                let a = a as! String
                let b = b as! String
                
                if !dependencies[a]!.isEmpty || !dependencies[b]!.isEmpty {
                    return .orderedSame
                }
                
                let i1 = registrationOrder.index(of: a)!
                let i2 = registrationOrder.index(of: b)!
                
                return i1 < i2 ? .orderedAscending : .orderedDescending
            }) as! [String]
        }
        
        func run() {
            
            let bootCompleted = withLock {
                return self.booting.isEmpty
            }
            
            if bootCompleted {
                completion(.succeeded)
                return
            }
            
            let next = withLock {
                return self.booting.removeFirst()
            }
            
            let key = "\(next.self)"
            let service = services[key]!
            
            service.boot(launchOptions: launchOptions, completion: { (result) in
                
                func done() {
                    switch result {
                    case .succeeded: run()
                    case let .failed(error):
                        self.withLock { () -> Void in
                            self.booting.removeAll()
                        }
                        completion(.failed(failedServices: [ViperServiceBootFailureResult(service: service, error: error)]))
                    }
                }
                
                if Thread.isMainThread {
                    done()
                }
                else {
                    DispatchQueue.main.async {
                        done()
                    }
                }
            })
        }

        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
            
            let stillBooting = self.withLock {
                return Array<String>(self.booting)
            }
            
            if stillBooting.isEmpty {
                timer.invalidate()
                return
            }
            
            print("[DefaultViperServicesContainer]: Still booting \(stillBooting)")
        })
        #endif
        
        run()
    }
    
    // MARK: Helpers
    
    private func name(of service: AnyObject) -> String {
        let opaque: UnsafeMutableRawPointer = Unmanaged.passUnretained(service).toOpaque()
        let ptrStr = String(describing: opaque)
        return names[ptrStr]!
    }
    
    // First Topological Sort in Apple's new language Swift
    // Updated on 10/30/2016 to account for the newest version of Swift (3.0)
    // Michael Recachinas
    private enum TopologicalSortError : Error {
        case CycleError(String)
    }
    
    /// Simple helper method to check if a graph is empty
    /// - parameters:
    ///     - dependency_list: a `Dictionary<String, [String]>` containing the graph structure
    /// - returns: a `Bool` that determines whether or not the values in a dictionary are empty
    private class func isEmpty(graph: Dictionary<String, [String]>) -> Bool {
        for (_, value) in graph {
            if value.count > 0 {
                return false
            }
        }
        return true
    }
    
    /// Performs the topological sort
    /// - parameters:
    ///     - dependency_list
    /// - returns: a sorted `[String]` containing a possible topologically sorted path
    /// - throws: a `TopologicalSortError.CycleError` if the graph is not empty (meaning there exists a cycle)
    private class func topo_sort(dependency_list: Dictionary<String, [String]>) throws -> [String] {
        var sorted: [String] = []
        var next_depth: [String] = []
        var graph = dependency_list
        
        for key in graph.keys {
            if graph[key]! == [] {
                next_depth.append(key)
            }
        }
        
        for key in next_depth {
            graph.removeValue(forKey: key)
        }
        
        while next_depth.count != 0 {
            next_depth.sort(by: >)
            let node = next_depth.removeLast()
            sorted.append(node)
            
            for key in graph.keys {
                let arr = graph[key]
                let dl = arr!.filter({ $0 == node})
                if dl.count > 0 {
                    graph[key] = graph[key]?.filter({$0 != node})
                    if graph[key]?.count == 0 {
                        next_depth.append(key)
                    }
                }
            }
        }
        if !isEmpty(graph: graph) {
            throw TopologicalSortError.CycleError("This graph contains a cycle.")
        }
        else {
            return sorted
        }
    }

    private func lock() {
        os_unfair_lock_lock( self._lock )
    }
    
    private func unlock() {
        os_unfair_lock_unlock( self._lock )
    }
    
    @discardableResult
    private func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        let r: T = try block()
        unlock()
        return r
    }
}


