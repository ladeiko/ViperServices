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

func runOnMainThread(_ block: () -> Void) {
    if Thread.isMainThread {
        block()
    }
    else {
        DispatchQueue.main.sync {
            block()
        }
    }
}

public struct DefaultViperServicesContainerOptions {
    public let asyncBoot: Bool
    public init(asyncBoot: Bool = true) {
        self.asyncBoot = asyncBoot
    }
}

/**
 *  Default implementation of ViperServicesContainer.
 */
@available(iOS 10.0, *)
open class DefaultViperServicesContainer: ViperServicesContainer {
    
    private enum State {
        case initial
        case booting
        case bootCompleted
        case shuttingDown
    }

    private typealias InternalOperation = (_ completion: @escaping (() -> Void) ) -> Void
    
    private var operationIsRunning = false
    private var operations = [InternalOperation]()
    private var state: State = .initial
    private var services: [String: ViperService] = [:]
    private var registrationOrder = [String]()
    private var bootedServices = [ViperService]()
    private var names: [String: String] = [:]
    private var booting = [String]()
    private var _lock: NSRecursiveLock!
    private let _options: DefaultViperServicesContainerOptions
    
    // MARK: Life cycle
    
    public init(_ options: DefaultViperServicesContainerOptions = DefaultViperServicesContainerOptions()) {
        self._options = options
        self._lock = NSRecursiveLock()
    }
    
    // MARK: ViperServices
    
    open func register<T>(_ service: T) throws {
        
        assert(Thread.isMainThread)
        
        try withLock { () -> Void in
            
            if state != .initial {
                throw ViperServicesContainerError.alreadyBooted
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
    }
    
    open func resolve<T>() -> T {
        let key = "\(T.self)"
        return try! withLock { () -> T in
            switch state {
            case .booting:
                if booting.contains(key) {
                    throw ViperServicesContainerError.youTriedToResolveServiceThatIsNotReadyYet
                }
            default: break
            }
            return services[key] as! T
        }
    }
    
    open func tryResolve<T>() -> T? {
        let key = "\(T.self)"
        return try! withLock { () -> T? in
            switch state {
            case .booting:
                if booting.contains(key) {
                    throw ViperServicesContainerError.youTriedToResolveServiceThatIsNotReadyYet
                }
            default: break
            }
            return services[key] as? T
        }
    }
    
    open func boot(launchOptions: [UIApplication.LaunchOptionsKey: Any]?, completion: @escaping ViperServicesContainerBootCompletion) {
        
        assert(Thread.isMainThread)
        
        operations.append { (operationCompletion) in
            
            self.withLock {
                switch self.state {
                case .initial:
                    self.state = .booting
                    
                default:
                    fatalError()
                }
                
            }
            
            var completed = [String: ViperServiceBootResult]()
            var dependencies: Dictionary<String, [String]> = [:]
            
            for service in self.services.values {
                let key = self.name(of: service)
                if let deps = service.setupDependencies(self), !deps.isEmpty {
                    dependencies[key] = deps.map({ self.name(of: $0) })
                }
                else {
                    dependencies[key] = []
                }
            }
            
            self.withLock {
                self.booting = ((try! type(of: self).topo_sort(dependency_list: dependencies)) as NSArray).sortedArray(comparator: { (a, b) -> ComparisonResult in
                    let a = a as! String
                    let b = b as! String
                    
                    if !dependencies[a]!.isEmpty || !dependencies[b]!.isEmpty {
                        return .orderedSame
                    }
                    
                    let i1 = self.registrationOrder.index(of: a)!
                    let i2 = self.registrationOrder.index(of: b)!
                    
                    return i1 < i2 ? .orderedAscending : .orderedDescending
                }) as! [String]
            }
            
            func complete(_ result: ViperServicesContainerBootResult) {
                
                #if DEBUG
                print("[DefaultViperServicesContainer]: Boot completed")
                #endif
                
                self.withLock {
                    self.booting.removeAll()
                    self.state = .bootCompleted
                }
                completion(result)
                operationCompletion()
                
                #if DEBUG
                print("[DefaultViperServicesContainer]: Calling 'totalBootCompleted'")
                #endif
                
                for service in self.services.values {
                    service.totalBootCompleted(result)
                }
            }
            
            func bootNext() {
                
                assert(Thread.isMainThread)
                
                let bootCompleted = self.withLock {
                    return self.booting.isEmpty
                }
                
                if bootCompleted {
                    complete(.succeeded)
                    return
                }
                
                let next = self.withLock {
                    return self.booting.removeFirst()
                }
                
                let key = "\(next.self)"
                let service = self.services[key]!
                
                if self.operations.isEmpty == false { // if some operation is pending, then break boot
                    complete(.failed(failedServices: [ViperServiceBootFailureResult(service: service, error: ViperServicesContainerError.bootCanceled)]))
                    return
                }
                
                #if DEBUG
                print("[DefaultViperServicesContainer]: Booting '\(key)'")
                #endif
                
                let go = {
                    service.boot(launchOptions: launchOptions, completion: { (result) in
                        runOnMainThread {
                            switch result {
                            case .succeeded:
                                #if DEBUG
                                print("[DefaultViperServicesContainer]: Boot succeeded for '\(key)'")
                                #endif
                                self.bootedServices.append(service)
                                bootNext()
                                
                            case let .failed(error):
                                #if DEBUG
                                print("[DefaultViperServicesContainer]: Boot failed for '\(key)' with '\(error.localizedDescription)'")
                                #endif
                                complete(.failed(failedServices: [ViperServiceBootFailureResult(service: service, error: error)]))
                            }
                        }
                    })
                }
                
                if self._options.asyncBoot {
                    DispatchQueue.main.async {
                        go()
                    }
                }
                else {
                    go()
                }
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
            
            bootNext()
        }
        
        runNextOperation()
    }
    
    open func shutdown(completion: @escaping ViperServicesContainerShutdownCompletion) {
        
        assert(Thread.isMainThread)
        
        operations.append({ (operationCompletion) in
            
            self.withLock {
                self.state = .shuttingDown
            }
            
            func shutdownNext() {
                
                assert(Thread.isMainThread)
                
                if self.bootedServices.isEmpty {
                    self.withLock {
                        self.state = .initial
                    }
                    completion()
                    operationCompletion()
                    return
                }
                
                let service = self.bootedServices.removeFirst()
                
                service.shutdown(completion: {
                    runOnMainThread {
                        shutdownNext()
                    }
                })
            }

            // Shutdown should be performed in reverse order
            self.bootedServices.reverse()
            
            shutdownNext()
        })
        
        runNextOperation()
    }
    
    // MARK: Helpers
    
    private func runNextOperation() {
        assert(Thread.isMainThread)
        
        guard self.operationIsRunning == false else {
            return
        }
        
        guard self.operations.isEmpty == false else {
            return
        }
        
        let operation = self.operations.removeFirst()
        self.operationIsRunning = true
        
        operation {
            assert(Thread.isMainThread)
            
            self.operationIsRunning = false
            self.runNextOperation()
        }
    }
    
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
            
            #if DEBUG
            func getCycleDeps(_ k: String, _ result: [String]) -> [String]? {
                
                let cycle = result.reduce(into: [String: Int](), { (r, v) in
                    r[v] = r[v] ?? 0
                    r[v] = r[v]! + 1
                }).reduce(into: false, { (r, v) in
                    if !r && v.value == 2 {
                        r = true
                    }
                })
                
                if cycle {
                    return result
                }
                
                for d in graph[k]! {
                    var s = result
                    s.append(d)
                    if let r = getCycleDeps(d, s) {
                        return r
                    }
                }
                
                return nil
            }
            
            graph.forEach { (p) in
                if let deps = getCycleDeps(p.key, [p.key]) {
                    print("Cyclic dependency: \(deps.joined(separator: " -> "))")
                }
            }
            #endif
            
            throw TopologicalSortError.CycleError("This graph contains a cycle.")
        }
        else {
            return sorted
        }
    }

    private func lock() {
        self._lock.lock()
    }
    
    private func unlock() {
        self._lock.unlock()
    }
    
    @discardableResult
    private func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        let r: T = try block()
        unlock()
        return r
    }
}


