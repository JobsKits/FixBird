#!/usr/bin/env ruby
# 只编译临时源码副本；不请求服务、不安装 Pods、不运行 Xcode 构建或 IPA 清理。
require 'tmpdir'
require 'open3'

project_root = File.expand_path('..', __dir__)
source_paths = Dir.glob(File.join(project_root, 'App/Domain/**/*.swift')) + [
  File.join(project_root, 'App/Services/MarketplaceAPIClient/MarketplaceAPIClient.swift'),
  File.join(project_root, 'App/Services/MarketplaceCacheStorage/MarketplaceCacheStorage.swift'),
  File.join(project_root, 'App/Services/MarketplaceOrderCache/MarketplaceOrderCache.swift'),
  File.join(project_root, 'App/Services/MarketplaceStore/MarketplaceStore.swift'),
  File.join(project_root, 'App/Services/MarketplaceCredentialStorage/MarketplaceCredentialStorage.swift'),
  File.join(project_root, 'App/Services/MarketplaceSessionCenter/MarketplaceSessionCenter.swift'),
  File.join(project_root, 'App/Services/MarketplaceAccountStore/MarketplaceAccountStore.swift'),
  File.join(project_root, 'App/Services/MarketplacePrivateAssetClient/MarketplacePrivateAssetClient.swift'),
  File.join(project_root, 'App/Services/MarketplacePrivateCache/MarketplacePrivateCache.swift'),
  File.join(project_root, 'App/Services/MarketplaceWorkerStore/MarketplaceWorkerStore.swift'),
  File.join(project_root, 'App/Services/MarketplaceLedgerStore/MarketplaceLedgerStore.swift'),
  File.join(project_root, 'App/Services/MarketplaceDeviceStore/MarketplaceDeviceStore.swift'),
  File.join(project_root, 'App/Services/MarketplaceQRStore/MarketplaceQRStore.swift'),
  File.join(project_root, 'JobsByPods/JobsSwiftBlock@Pods/JSONCoder+Make.swift'),
  File.join(__dir__, 'MarketplaceTestSupport.swift'),
  File.join(__dir__, 'MarketplaceCoreTests.swift')
]
Dir.mktmpdir('repair-marketplace-core-tests-') do |temporary_root|
  source_copies = source_paths.each_with_index.map do |source_path, index|
    copy = File.join(temporary_root, "#{index}-#{File.basename(source_path)}")
    File.write(copy, File.read(source_path).gsub(/^import (JobsNetworking|JobsSwiftBlock)\s*$/, ''))
    copy
  end
  binary_path = File.join(temporary_root, 'core-tests')
  output, status = Open3.capture2e(ENV.fetch('SWIFTC', 'swiftc'), *source_copies, '-o', binary_path)
  puts output unless output.empty?
  abort 'Core test compilation failed.' unless status.success?
  output, status = Open3.capture2e(binary_path)
  puts output
  abort 'Core tests failed.' unless status.success?
end
