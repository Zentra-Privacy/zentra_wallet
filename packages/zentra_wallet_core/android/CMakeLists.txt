cmake_minimum_required(VERSION 3.10)
project(zentra_wallet_core LANGUAGES CXX)

add_library(zentra_wallet_core SHARED
  ../src/zentra_core.cpp
)

target_compile_features(zentra_wallet_core PUBLIC cxx_std_14)
