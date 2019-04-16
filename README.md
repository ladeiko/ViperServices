# ViperServices

https://img.shields.io/cocoapods/v/ViperServices.svg?style=flat&label=CocoaPods&colorA=28a745&&colorB=4E4E4E

## Introduction
ViperServices is dependency injection container for iOS applications written in Swift.
It is more lightweight and simple in use than:

* [Kraken](https://github.com/sabirvirtuoso/Kraken)
* [Guise](https://github.com/prosumma/Guise)
* etc.

Also it introduces 'bootable' concept of service. Also services can define units they depends on.

## Changelog

See [CHANGELOG](CHANGELOG.md)

## Installation

### Cocoapods
> This is the recommended way of installing this package.

* Add the following line to your Podfile

``` ruby
pod 'ViperServices'
```
* Run the following command to fetch and build your dependencies

``` bash
pod install
```

### Manually
If you prefer to install this package manually, just follow these steps:

* Make sure your project is a git repository. If it isn't, just run this command from your project root folder:

``` bash
git init
```

* Add ViperServices as a git submodule by running the following command.

``` bash
git submodules add https://github.com/ladeiko/ViperServices.git
```
* Add files from *'submodules/ViperServices/Sources'* folder to your project.

## Usage

* Define your viper services:

``` swift
import ViperServices

protocol Service1: class {
    func foo()
}

class Service1Impl: Service1, ViperService {
    
    func setupDependencies(_ container: ViperServicesContainer) -> [AnyObject]? {
        return [ // depends on
            container.resolve() as Service2
        ]
    }
    
    func boot(launchOptions: [UIApplication.LaunchOptionsKey : Any]?, completion: @escaping ViperServiceBootCompletion) {
        print("boot 1 called")
        completion(.succeeded) // sync completion
    }
    
    func foo() {
        print("foo 1 called")
    }
    
}

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
    
    func boot(launchOptions: [UIApplication.LaunchOptionsKey : Any]?, completion: @escaping ViperServiceBootCompletion) {
        print("boot 2 called")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // async completion
            switch arc4random() % 2 { // emulate random result
            case 0:
                completion(.failed(error: Service2Error.SomeError))
            default:
                completion(.succeeded)
            }
            
        }
    }
    
    func foo() {
        print("foo 2 called")
    }
    
}
```

* Add following code to application delegate:

``` swift
var window: UIWindow?

// use DefaultViperServicesContainer or implement your own container
let services = DefaultViperServicesContainer() 

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    
    try! services.register(Service1Impl() as Service1)
    try! services.register(Service2Impl() as Service2)
    
    services.boot(launchOptions: launchOptions) { (result) in
        switch result {
        case .succeeded:
            // All ok, now it is safe to use any service!
            (self.services.resolve() as Service1).foo()
            (self.services.resolve() as Service2).foo()
            
        case let .failed(failedServices):
            // Boot failed, show error to user
            let alert = UIAlertController(title: "Error",
                                      message: failedServices.first!.error.localizedDescription,
                                      preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.window!.rootViewController?.present(alert, animated: false, completion: nil)
        }
    }
    
    return true
}
```


## LICENSE
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
