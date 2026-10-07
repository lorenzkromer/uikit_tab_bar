#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint uikit_tab_bar.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'uikit_tab_bar'
  s.version          = '0.1.0'
  s.summary          = 'The native iOS 26+ tab bar (UITabBarController, Liquid Glass) for Flutter.'
  s.description      = <<-DESC
Hosts a UITabBarController in a Flutter platform view: minimize on scroll,
bottom accessory, search tab, prominent tab, styling and geometry reporting.
                       DESC
  s.homepage         = 'https://github.com/lorenzkromer/uikit_tab_bar'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Lorenz Kromer' => 'lorenz.kromer@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'uikit_tab_bar/Sources/uikit_tab_bar/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.6'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'uikit_tab_bar_privacy' => ['uikit_tab_bar/Sources/uikit_tab_bar/PrivacyInfo.xcprivacy']}
end
