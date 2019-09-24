Pod::Spec.new do |s|

  s.name         = "ViperServices"
  s.version      = "1.4.0"
  s.summary      = "ViperServices is dependency injection container for iOS, macOS applications written in Swift."

  s.homepage         = "https://github.com/ladeiko/ViperServices"
  s.license          = 'MIT'
  s.authors           = { "Siarhei Ladzeika" => "sergey.ladeiko@gmail.com" }
  s.source           = { :git => "https://github.com/ladeiko/ViperServices.git", :tag => s.version.to_s }
  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.requires_arc = true

  s.source_files =  "Sources/*.{swift}"
  s.swift_versions = ['4.2', '5.0']

end
