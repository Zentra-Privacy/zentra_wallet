#
# FFI plugin — zentra_core helpers + vendored libzentra_wallet_ffi (XCFramework after build-ios / CI).
#
Pod::Spec.new do |s|
  s.name             = 'zentra_wallet_core'
  s.version          = '1.0.0'
  s.summary          = 'Zentra wallet FFI core'
  s.description      = 'Native wallet engine and helpers for Zentra Wallet on iOS.'
  s.homepage         = 'https://github.com/Zentra-Privacy/zentra_wallet'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Zentra Privacy' => 'dev@zentraprivacy.org' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  # Static pod: link XCFramework into Runner so Dart DynamicLibrary.process() resolves FFI symbols.
  s.static_framework = true

  xcf = 'lib/zentra_wallet_ffi.xcframework'
  if File.directory?(xcf)
    s.vendored_frameworks = xcf
    # -all_load: keep FFI C symbols in the app binary for Dart DynamicLibrary.process()
    link_flags = '$(inherited) -ObjC -Wl,-all_load'
    s.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
      'OTHER_LDFLAGS' => link_flags,
    }
    s.user_target_xcconfig = {
      'OTHER_LDFLAGS' => link_flags,
    }
  else
    Pod::UI.warn "#{s.name}: #{xcf} missing — run ./wallet.sh build-ios on macOS (wallet engine unavailable)"
    s.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    }
  end

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
end
