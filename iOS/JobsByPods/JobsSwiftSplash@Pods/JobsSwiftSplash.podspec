Pod::Spec.new do |spec|
  spec.name          = 'JobsSwiftSplash'
  spec.version       = '0.0.1'
  spec.summary       = 'Jobs Swift splash screen component.'
  spec.description   = <<-DESC
                         Displays local or remote images, GIFs and videos with skip, tap and shake actions.
                       DESC
  spec.homepage      = 'https://example.local/JobsSwiftSplash'
  spec.license       = { :type => 'MIT' }
  spec.author        = { 'Jobs' => 'lg295060456@gmail.com' }
  spec.platform      = :ios, '12.0'
  spec.swift_version = '5.0'
  spec.source        = { :path => '.' }
  spec.source_files  = 'Core/**/*.swift'
  spec.resource_bundles = {
    'JobsSwiftSplashResources' => ['Resources/**/*']
  }
  spec.frameworks    = ['UIKit', 'AVFoundation', 'ImageIO']

  spec.dependency 'JobsInheritance'
  spec.dependency 'JobsByUIKit'
  spec.dependency 'JobsSwiftBaseDefines'
  spec.dependency 'JobsCountdownButton'
  spec.dependency 'JobsSwiftDSL'
  spec.dependency 'JobsSwiftOpen'
  spec.dependency 'SnapKit'
end
