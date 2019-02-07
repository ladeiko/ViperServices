//
//  ViperServicesDemoTests.swift
//  ViperServicesDemoTests
//
//  Created by Siarhei Ladzeika on 5/5/18.
//  Copyright © 2018 BPMobile. All rights reserved.
//

import XCTest
import ViperServices

enum TestError: Error {
    case SomeError
    
    static func isSomeError(_ error: Error) -> Bool {
        if case TestError.SomeError = error {
            return true
        }
        return false
    }
}

class BootContext {
    var succeeded = false
    var failed: [ViperServiceBootFailureResult]?
}

class ViperServicesExample: DefaultViperServicesContainer {}

class DefaultServiceImpl: ViperService {
    
    private let succeed: Bool
    private let bootBlock: () -> Void
    private let shutdownBlock: () -> Void
    private let asyncBoot: Bool
    
    init(succeed: Bool = true,
         bootBlock: @escaping (() -> Void) = {},
         shutdownBlock: @escaping (() -> Void) = {},
         asyncBoot: Bool = false) {
        self.succeed = succeed
        self.bootBlock = bootBlock
        self.shutdownBlock = shutdownBlock
        self.asyncBoot = asyncBoot
    }
    
    func setupDependencies(_ container: ViperServicesContainer) -> [AnyObject]? {
        return nil
    }
    
    func boot(launchOptions: [UIApplication.LaunchOptionsKey : Any]?, completion: @escaping ViperServiceBootCompletion) {
        if asyncBoot {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.bootBlock()
                if self.succeed {
                    completion(.succeeded)
                }
                else {
                    completion(.failed(error: TestError.SomeError))
                }
            })
        }
        else {
            bootBlock()
            if succeed {
                completion(.succeeded)
            }
            else {
                completion(.failed(error: TestError.SomeError))
            }
        }
    }
    
    func shutdown(completion: @escaping ViperServiceShutdownCompletion) {
        shutdownBlock()
        completion()
    }
    
    func totalBootCompleted(_ result: ViperServicesContainerBootResult) {
        print("totalBootCompleted")
    }
    
}

protocol ViperService1: ViperService {}
protocol ViperService2: ViperService {}

class ViperServiceImpl1: DefaultServiceImpl, ViperService1 {}
class ViperServiceImpl2: DefaultServiceImpl, ViperService2 {}

protocol DepServiceA: ViperService {}
protocol DepServiceBA: ViperService {}
protocol DepServiceCA: ViperService {}
protocol DepServiceDC: ViperService {}

class DepServiceImplA: DefaultServiceImpl, DepServiceA {}
class DepServiceImplBA: DefaultServiceImpl, DepServiceBA {
    override func setupDependencies(_ container: ViperServicesContainer) -> [AnyObject]? {
        return [
            container.resolve() as DepServiceA
        ]
    }
}
class DepServiceImplCA: DefaultServiceImpl, DepServiceCA {
    override func setupDependencies(_ container: ViperServicesContainer) -> [AnyObject]? {
        return [
            container.resolve() as DepServiceA
        ]
    }
}
class DepServiceImplDC: DefaultServiceImpl, DepServiceDC {
    override func setupDependencies(_ container: ViperServicesContainer) -> [AnyObject]? {
        return [
            container.resolve() as DepServiceCA
        ]
    }
}

class ViperServicesDemoTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSuccessfulBootSyncMode() {
        let services = ViperServicesExample(DefaultViperServicesContainerOptions(asyncBoot: false))
        
        try! services.register(ViperServiceImpl1() as ViperService1)
        try! services.register(ViperServiceImpl2() as ViperService2)
        
        let context = BootContext()
        
        services.boot(launchOptions: nil) { (result) in
            switch result {
            case .succeeded: context.succeeded = true
            case .failed(_): break
            }
        }
        
        XCTAssert(context.succeeded)
    }
    
    func testSuccessfulBootAsyncMode() {
        let services = ViperServicesExample()
        
        try! services.register(ViperServiceImpl1() as ViperService1)
        try! services.register(ViperServiceImpl2() as ViperService2)
        
        let context = BootContext()
        
        var bootCompleted = false
        
        let expectation = XCTestExpectation(description: "")
        
        services.boot(launchOptions: nil) { (result) in
            bootCompleted = true
            switch result {
            case .succeeded: context.succeeded = true
            case .failed(_): break
            }
            
            expectation.fulfill()
        }
        
        XCTAssertTrue(!bootCompleted)
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssert(context.succeeded)
    }
    
    func testFailureBootOfFirstServiceSyncMode() {
        let services = ViperServicesExample(DefaultViperServicesContainerOptions(asyncBoot: false))
        
        try! services.register(ViperServiceImpl1(succeed: false) as ViperService1)
        try! services.register(ViperServiceImpl2() as ViperService2)
        
        let context = BootContext()
        var bootCompleted = false
        services.boot(launchOptions: nil) { (result) in
            bootCompleted = true
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
        }
        
        XCTAssertTrue(bootCompleted)
        XCTAssertTrue(!context.succeeded)
        XCTAssertNotNil(context.failed)
        XCTAssertTrue(context.failed!.count == 1)
        XCTAssertTrue(context.failed!.first!.service is ViperServiceImpl1)
        XCTAssertTrue(TestError.isSomeError(context.failed!.first!.error))
    }
    
    func testFailureBootOfFirstServiceAsyncMode() {
        let services = ViperServicesExample()
        
        try! services.register(ViperServiceImpl1(succeed: false) as ViperService1)
        try! services.register(ViperServiceImpl2() as ViperService2)
        
        let context = BootContext()
        var bootCompleted = false
        
        let expectation = XCTestExpectation(description: "")
        
        services.boot(launchOptions: nil) { (result) in
            bootCompleted = true
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
            
            expectation.fulfill()
        }
        
        XCTAssertTrue(!bootCompleted)
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertTrue(!context.succeeded)
        XCTAssertNotNil(context.failed)
        XCTAssertTrue(context.failed!.count == 1)
        XCTAssertTrue(context.failed!.first!.service is ViperServiceImpl1)
        XCTAssertTrue(TestError.isSomeError(context.failed!.first!.error))
    }

    func testFailureBootOfSecondService() {
        let services = ViperServicesExample()
        
        try! services.register(ViperServiceImpl1() as ViperService1)
        try! services.register(ViperServiceImpl2(succeed: false) as ViperService2)
        
        let context = BootContext()
        
        let expectation = XCTestExpectation(description: "")
        
        services.boot(launchOptions: nil) { (result) in
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssert(!context.succeeded)
        XCTAssertNotNil(context.failed)
        XCTAssert(context.failed!.count == 1)
        XCTAssert(context.failed!.first!.service is ViperServiceImpl2)
        XCTAssert(TestError.isSomeError(context.failed!.first!.error))
    }

    func testDependentBoot() {
        let services = ViperServicesExample()
        
        var booted = [String]()
        
        try! services.register(DepServiceImplDC(bootBlock: { booted.append("D") }) as DepServiceDC)
        try! services.register(DepServiceImplCA(bootBlock: { booted.append("C") }) as DepServiceCA)
        try! services.register(DepServiceImplBA(bootBlock: { booted.append("B") }) as DepServiceBA)
        try! services.register(DepServiceImplA(bootBlock: { booted.append("A") }) as DepServiceA)
        
        let context = BootContext()
        
        let expectation = XCTestExpectation(description: "")
        
        services.boot(launchOptions: nil) { (result) in
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssert(context.succeeded == true)
        XCTAssertNil(context.failed)
        XCTAssert((booted == ["A", "B", "C", "D"]) || (booted == ["A", "C", "B", "D"]))
    }
    
    func testAsyncDependentBoot() {
        let services = ViperServicesExample()
        
        let expectation = XCTestExpectation(description: "Boot")
        
        var booted = [String]()
        
        try! services.register(DepServiceImplDC(bootBlock: { booted.append("D") }, asyncBoot: true) as DepServiceDC)
        try! services.register(DepServiceImplCA(bootBlock: { booted.append("C") }, asyncBoot: true) as DepServiceCA)
        try! services.register(DepServiceImplBA(bootBlock: { booted.append("B") }, asyncBoot: true) as DepServiceBA)
        try! services.register(DepServiceImplA(bootBlock: { booted.append("A") }, asyncBoot: true) as DepServiceA)
        
        let context = BootContext()
        
        services.boot(launchOptions: nil) { (result) in
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssert(context.succeeded == true)
        XCTAssertNil(context.failed)
        XCTAssert((booted == ["A", "B", "C", "D"]) || (booted == ["A", "C", "B", "D"]))
    }
    
    func testShutdown() {
        let services = ViperServicesExample()
        
        let expectation = XCTestExpectation(description: "Boot")
        
        var booted = [String]()
        var stopped = [String]()
        
        try! services.register(DepServiceImplDC(bootBlock: { booted.append("D") }, shutdownBlock: { stopped.append("D") }, asyncBoot: true) as DepServiceDC)
        try! services.register(DepServiceImplCA(bootBlock: { booted.append("C") }, shutdownBlock: { stopped.append("C") }, asyncBoot: true) as DepServiceCA)
        try! services.register(DepServiceImplBA(bootBlock: { booted.append("B") }, shutdownBlock: { stopped.append("B") }, asyncBoot: true) as DepServiceBA)
        try! services.register(DepServiceImplA(bootBlock: { booted.append("A") }, shutdownBlock: { stopped.append("A") }, asyncBoot: true) as DepServiceA)
        
        let context = BootContext()
        
        services.boot(launchOptions: nil) { (result) in
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssert(context.succeeded == true)
        XCTAssertNil(context.failed)
        XCTAssert((booted == ["A", "B", "C", "D"]) || (booted == ["A", "C", "B", "D"]))
        
        let shutdownExpectation = XCTestExpectation(description: "Shutdown")
        
        services.shutdown {
            shutdownExpectation.fulfill()
        }
        
        wait(for: [shutdownExpectation], timeout: 10.0)
        
        XCTAssert((stopped == ["D", "C", "B", "A"]) || (stopped == ["D", "B", "C", "A"]))
    }
    
    func testShutdownCalledWhileBoot() {
        let services = ViperServicesExample()
        
        let bootExpectation = XCTestExpectation(description: "Boot")
        let shutdownExpectation = XCTestExpectation(description: "Shutdown")
        
        var booted = [String]()
        var stopped = [String]()
        
        weak var weakServices = services
        
        try! services.register(DepServiceImplDC(bootBlock: { booted.append("D") }, shutdownBlock: { stopped.append("D") }, asyncBoot: true) as DepServiceDC)
        try! services.register(DepServiceImplCA(bootBlock: { booted.append("C") }, shutdownBlock: { stopped.append("C") }, asyncBoot: true) as DepServiceCA)
        
        try! services.register(DepServiceImplBA(bootBlock: {
            booted.append("B")
            if let services = weakServices {
                services.shutdown { // Call shutdown before boot completion
                    shutdownExpectation.fulfill()
                }
            }
        }, shutdownBlock: { stopped.append("B") }, asyncBoot: true) as DepServiceBA)
        
        try! services.register(DepServiceImplA(bootBlock: { booted.append("A") }, shutdownBlock: { stopped.append("A") }, asyncBoot: true) as DepServiceA)
        
        let context = BootContext()
        
        let expectation = XCTestExpectation(description: "")
        
        services.boot(launchOptions: nil) { (result) in
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
            bootExpectation.fulfill()
        }
        
        wait(for: [bootExpectation], timeout: 10.0)
        
        XCTAssert(context.succeeded == false)
        XCTAssertNotNil(context.failed)
        XCTAssert(context.failed!.count == 1)
        XCTAssert(booted == ["A", "B"])
        
        wait(for: [shutdownExpectation], timeout: 10.0)
        
        XCTAssert(stopped == ["B", "A"])
    }
    
}
