cmake_minimum_required(VERSION 3.14)
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

set(_bundled_libs "$<TARGET_FILE:${PLUGIN_NAME}>")
# Prebuilt MinGW wallet engine + runtime DLLs (after ./wallet.sh build-windows).
file(GLOB _prebuilt_dlls "${CMAKE_CURRENT_SOURCE_DIR}/*.dll")
if(_prebuilt_dlls)
  list(APPEND _bundled_libs ${_prebuilt_dlls})
endif()
set(zentra_wallet_core_bundled_libraries ${_bundled_libs} PARENT_SCOPE)
