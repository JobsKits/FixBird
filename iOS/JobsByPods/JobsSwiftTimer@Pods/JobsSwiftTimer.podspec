Pod::Spec.new do |s|
  s.name         = 'JobsSwiftTimer'          # Pod 名
  s.version      = '0.1.0'
  s.summary      = 'TODO'
  s.description  = <<-DESC
                     TODO
                   DESC

  s.homepage     = 'https://github.com/JobsKits/JobsSwiftTimer'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Jobs' => 'lg295060456@gmail.com' }

  s.platform      = :ios, '12.0'
  s.swift_version = '5.0'

  s.source = {
    :git => 'https://github.com/JobsKits/JobsSwiftTimer.git',
    :tag => s.version.to_s
  }
  
  # 全局排除脚本 / 图标
  s.exclude_files = [
    '【MacOS】🫘JobsPublishPods.command',
    'Resource/icon.png',
    'LICENSE',
  ]

  s.source_files = '**/*.{swift,h,m,mm}'
  s.ios.frameworks = 'UIKit'
  
end
