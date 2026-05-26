#
# FFI plugin — zentra_core helpers + vendored libzentra_wallet_ffi.dylib (after build-macos / CI).
#
Pod::Spec.new do |s|
  s.name             = 'zentra_wallet_core'
  s.version          = '1.0.0'
  s.summary          = 'Zentra wallet FFI core helpers'
  s.description      = 'Native helpers for Zentra Wallet (amounts, address validation).'
  s.homepage         = 'https://github.com/Zentra-Privacy/zentra_wallet'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Zentra Privacy' => 'dev@zentraprivacy.org' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  dylib = 'lib/libzentra_wallet_ffi.dylib'
  if File.file?(dylib)
    s.vendored_libraries = dylib
    s.preserve_paths   = dylib
  else
    Pod::UI.warn "#{s.name}: #{dylib} missing — run ./wallet.sh build-macos (wallet engine unavailable)"
  end

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'MACOSX_DEPLOYMENT_TARGET' => '12.0',
  }
  s.swift_version = '5.0'
end
