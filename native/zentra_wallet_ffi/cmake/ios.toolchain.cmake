# iOS toolchain for libzentra_wallet_ffi and iOS dependency builds.
# Set IOS_SDK=iphonesimulator for Simulator, default iphoneos for device.
cmake_minimum_required(VERSION 3.16)

set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR arm64)

if(NOT IOS_SDK)
  set(IOS_SDK iphoneos)
endif()

execute_process(
  COMMAND xcrun --sdk "${IOS_SDK}" --show-sdk-path
  OUTPUT_VARIABLE _ZENTRA_IOS_SDK_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_QUIET
)
if(NOT _ZENTRA_IOS_SDK_PATH OR NOT EXISTS "${_ZENTRA_IOS_SDK_PATH}")
  message(FATAL_ERROR "Could not resolve iOS SDK path for IOS_SDK=${IOS_SDK}")
endif()

set(CMAKE_OSX_SYSROOT "${_ZENTRA_IOS_SDK_PATH}" CACHE PATH "iOS SDK root" FORCE)
set(CMAKE_OSX_ARCHITECTURES arm64 CACHE STRING "iOS architectures" FORCE)
if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
  set(CMAKE_OSX_DEPLOYMENT_TARGET 13.0 CACHE STRING "iOS deployment target" FORCE)
endif()

# Host tools (protoc) stay on Mac; libraries/headers come from the iOS SDK + install prefix.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
