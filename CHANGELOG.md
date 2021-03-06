# CHANGELOG

## 1.4.0
### Added
* func safeExec() to protocol and to default implementation

## 1.3.1
### Added
* Support for MacOS

## 1.3.0
### Added
* ```totalBootBegan()```

## 1.2.1
### Added
*  ```func totalBootCompleted(_ result: ViperServicesContainerBootResult)```
*  ```DefaultViperServicesContainerOptions```

## 1.1.5
### Added
* Add printing of cyclic dependencies in DefaultViperServicesContainer if DEBUG is defined

## 1.1.4
### Added
* Add tryResolve() to services container protocol

## 1.1.3
## Changed
* Upgrade syntax to swift 4.2

## 1.1.2
### Fixed
* ```try`` in resolve method of default container

## 1.1.1
### Fixed
* Crash while recursive lock in ```DefaultViperServicesContainer```

## 1.1.0
### Added
* ```shutdown```method to service and container protocol
* More test units

### Changed
* Made methods of ```DefaultViperServicesContainer``` more thread-safe

## 1.0.0
* Initial version

