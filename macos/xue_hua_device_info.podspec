#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint xue_hua_device_info.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_device_info'
  s.version          = '2.0.0'
  s.summary          = 'Flutter plugin for device info across platforms.'
  s.description      = <<-DESC
Flutter plugin for device info: battery, network, storage, display, and system details.
                       DESC
  s.homepage         = 'https://github.com/Matkurban/xue_hua_device_info'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'XueHua' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'xue_hua_device_info/Sources/xue_hua_device_info/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.frameworks = 'IOKit', 'SystemConfiguration', 'CoreGraphics'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
