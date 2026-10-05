Pod::Spec.new do |s|
  s.name          = 'JobsSwiftDSL'
  s.version       = '0.1.0'
  s.summary       = 'Swift DSL wrappers for Jobs local Pods.'
  s.description   = <<-DESC
                      JobsSwiftDSL centralizes chainable byXxx/dsl wrappers
                      extracted from Jobs local Swift Pods.
                    DESC

  s.homepage      = 'https://github.com/JobsKits/JobsSwiftDSL'
  s.license       = { :type => 'MIT' }
  s.author        = { 'Jobs' => 'lg295060456@gmail.com' }

  s.platform      = :ios, '12.0'
  s.swift_version = '5.0'
  s.source        = { :path => '.' }

  s.source_files  = '**/*.{swift,h,m,mm}'
  s.ios.frameworks = 'UIKit',
                      'Foundation',
                      'QuartzCore',
                      'CoreGraphics',
                      'WebKit',
                      'PDFKit',
                      'PhotosUI',
                      'MetalKit',
                      'AVFoundation',
                      'CoreMotion',
                      'MediaPlayer'

  s.dependency 'JobsSwiftBlock'
  s.dependency 'JobsSwiftBaseDefines'
  s.dependency 'JobsTextTools'
  s.dependency 'RxSwift'
  s.dependency 'RxCocoa'
  s.dependency 'SnapKit'
  s.dependency 'BMPlayer'
  s.dependency 'GKNavigationBarSwift'
end
