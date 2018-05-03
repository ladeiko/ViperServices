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
    private let asyncBoot: Bool
    
    init(succeed: Bool = true,
         bootBlock: @escaping (() -> Void) = {},
         asyncBoot: Bool = false) {
        self.succeed = succeed
        self.bootBlock = bootBlock
        self.asyncBoot = asyncBoot
    }
    
    func setupDependencies(_ container: ViperServicesContainer) -> [ViperService]? {
        return nil
    }
    
    func boot(launchOptions: [UIApplicationLaunchOptionsKey : Any]?, completion: @escaping ViperServiceBootCompletion) {
        if asyncBoot {
            DispatchQueue.main.async {
                self.bootBlock()
                if self.succeed {
                    completion(.succeeded)
                }
                else {
                    completion(.failed(error: TestError.SomeError))
                }
            }
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
    override func setupDependencies(_ container: ViperServicesContainer) -> [ViperService]? {
        return [
            container.resolve() as DepServiceA
        ]
    }
}
class DepServiceImplCA: DefaultServiceImpl, DepServiceCA {
    override func setupDependencies(_ container: ViperServicesContainer) -> [ViperService]? {
        return [
            container.resolve() as DepServiceA
        ]
    }
}
class DepServiceImplDC: DefaultServiceImpl, DepServiceDC {
    override func setupDependencies(_ container: ViperServicesContainer) -> [ViperService]? {
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
    
    func testSuccessfulBoot() {
        let services = ViperServicesExample()
        
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
    
    func testFailureBootOfFirstService() {
        let services = ViperServicesExample()
        
        try! services.register(ViperServiceImpl1(succeed: false) as ViperService1)
        try! services.register(ViperServiceImpl2() as ViperService2)
        
        let context = BootContext()
        
        services.boot(launchOptions: nil) { (result) in
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
        }
        
        XCTAssert(!context.succeeded)
        XCTAssertNotNil(context.failed)
        XCTAssert(context.failed!.count == 1)
        XCTAssert(context.failed!.first!.service is ViperServiceImpl1)
        XCTAssert(TestError.isSomeError(context.failed!.first!.error))
    }

    func testFailureBootOfSecondService() {
        let services = ViperServicesExample()
        
        try! services.register(ViperServiceImpl1() as ViperService1)
        try! services.register(ViperServiceImpl2(succeed: false) as ViperService2)
        
        let context = BootContext()
        
        services.boot(launchOptions: nil) { (result) in
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
        }
        
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
        
        services.boot(launchOptions: nil) { (result) in
            switch result {
            case .succeeded:
                context.succeeded = true
                
            case let .failed(failedServices):
                context.failed = failedServices
                break
            }
        }
        
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
    
}
