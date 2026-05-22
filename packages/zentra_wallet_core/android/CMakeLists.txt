cmake_minimum_required(VERSION 3.10)
project(zentra_wallet_core LANGUAGES CXX)

add_library(zentra_wallet_core SHARED
  ../src/zentra_core.cpp
)

target_compile_features(zentra_wallet_core PUBLIC cxx_std_14)

# Match Dart: DynamicLibrary.open('libzentra_wallet_core_plugin.so')
set_target_properties(zentra_wallet_core PROPERTIES
  OUTPUT_NAME "zentra_wallet_core_plugin"
)
