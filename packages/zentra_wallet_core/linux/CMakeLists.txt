cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "zentra_wallet_core")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "zentra_wallet_core_plugin")

add_library(${PLUGIN_NAME} SHARED
  "../src/zentra_core.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PUBLIC DART_SHARED_LIB)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/../src")

set(_bundled_libs "$<TARGET_FILE:${PLUGIN_NAME}>")
set(_ffi_lib "${CMAKE_CURRENT_SOURCE_DIR}/libzentra_wallet_ffi.so")
if(EXISTS "${_ffi_lib}")
  list(APPEND _bundled_libs "${_ffi_lib}")
endif()
set(zentra_wallet_core_bundled_libraries ${_bundled_libs} PARENT_SCOPE)
