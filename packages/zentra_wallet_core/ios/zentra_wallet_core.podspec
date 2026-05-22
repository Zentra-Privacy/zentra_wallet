#
# FFI plugin — builds zentra_core (light helpers) for iOS.
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

  s.dependency 'Flutter'

  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
  }
  s.swift_version = '5.0'
end
