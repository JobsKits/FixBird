Pod::Spec.new do |spec|
  spec.name          = 'JobsSwiftOpen'
  spec.version       = '0.0.1'
  spec.summary       = 'Jobs Swift URL opening component.'
  spec.description   = <<-DESC
                         Opens configurable URLs inside the app or with the system browser.
                       DESC
  spec.homepage      = 'https://example.local/JobsSwiftOpen'
  spec.license       = { :type => 'MIT' }
  spec.author        = { 'Jobs' => 'lg295060456@gmail.com' }
  spec.platform      = :ios, '12.0'
  spec.swift_version = '5.0'
  spec.source        = { :path => '.' }
  spec.source_files  = 'Core/**/*.swift'
  spec.frameworks    = ['UIKit', 'WebKit', 'SafariServices']

  spec.dependency 'SnapKit'
  spec.dependency 'JobsInheritance'
  spec.dependency 'JobsByUIKit'
  spec.dependency 'GKNavigationBarSwift'
end
