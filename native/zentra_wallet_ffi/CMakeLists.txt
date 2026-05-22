cmake_minimum_required(VERSION 3.16)
project(zentra_wallet_ffi LANGUAGES CXX)

if(DEFINED ZENTRA_ROOT)
  set(ZENTRA_ROOT "${ZENTRA_ROOT}")
else()
  set(ZENTRA_ROOT "$ENV{ZENTRA_ROOT}")
endif()
if(DEFINED ZENTRA_BUILD_DIR)
  set(ZENTRA_BUILD "${ZENTRA_BUILD_DIR}")
else()
  set(ZENTRA_BUILD "$ENV{ZENTRA_BUILD_DIR}")
endif()

if(NOT ZENTRA_ROOT OR NOT EXISTS "${ZENTRA_ROOT}/src/wallet/api/wallet2_api.h")
  message(FATAL_ERROR "Set ZENTRA_ROOT to the zentra source tree")
endif()
if(NOT ZENTRA_BUILD OR NOT EXISTS "${ZENTRA_BUILD}/lib/libwallet_api.a")
  message(
    FATAL_ERROR
    "Set ZENTRA_BUILD_DIR to zentra build dir and build wallet_api first")
endif()

set(CMAKE_CXX_STANDARD 17)

macro(zentra_lib outvar relpath)
  set(_lib "${ZENTRA_BUILD}/${relpath}")
  if(EXISTS "${_lib}")
    list(APPEND ${outvar} "${_lib}")
  elseif(FFI_IOS)
    message(WARNING "Optional Zentra library missing (skipped on iOS): ${_lib}")
  else()
    message(FATAL_ERROR "Missing Zentra library: ${_lib}")
  endif()
endmacro()

# wallet-crypto is only built when Monero finds platform crypto libs; Android and
# some cross targets use internal crypto (libcncrypto.a) instead.
macro(zentra_lib_optional outvar relpath)
  set(_lib "${ZENTRA_BUILD}/${relpath}")
  if(EXISTS "${_lib}")
    list(APPEND ${outvar} "${_lib}")
  else()
    message(STATUS "Optional Zentra library not built (skipped): ${_lib}")
  endif()
endmacro()

set(ZENTRA_STATIC_LIBS "")
zentra_lib(ZENTRA_STATIC_LIBS lib/libwallet_api.a)
zentra_lib(ZENTRA_STATIC_LIBS lib/libwallet.a)
zentra_lib(ZENTRA_STATIC_LIBS src/rpc/librpc_base.a)
zentra_lib(ZENTRA_STATIC_LIBS src/multisig/libmultisig.a)
zentra_lib(ZENTRA_STATIC_LIBS src/device_trezor/libdevice_trezor.a)
zentra_lib(ZENTRA_STATIC_LIBS src/cryptonote_core/libcryptonote_core.a)
zentra_lib(ZENTRA_STATIC_LIBS src/blockchain_db/libblockchain_db.a)
zentra_lib(ZENTRA_STATIC_LIBS src/ringct/libringct.a)
zentra_lib(ZENTRA_STATIC_LIBS src/cryptonote_basic/libcryptonote_basic.a)
zentra_lib(ZENTRA_STATIC_LIBS src/checkpoints/libcheckpoints.a)
zentra_lib(ZENTRA_STATIC_LIBS src/hardforks/libhardforks.a)
zentra_lib(ZENTRA_STATIC_LIBS src/device/libdevice.a)
zentra_lib(ZENTRA_STATIC_LIBS src/cryptonote_basic/libcryptonote_format_utils_basic.a)
zentra_lib_optional(ZENTRA_STATIC_LIBS src/crypto/wallet/libwallet-crypto.a)
zentra_lib(ZENTRA_STATIC_LIBS src/blocks/libblocks.a)
zentra_lib(ZENTRA_STATIC_LIBS src/ringct/libringct_basic.a)
zentra_lib(ZENTRA_STATIC_LIBS src/net/libnet.a)
zentra_lib(ZENTRA_STATIC_LIBS src/common/libcommon.a)
zentra_lib(ZENTRA_STATIC_LIBS src/crypto/libcncrypto.a)
zentra_lib(ZENTRA_STATIC_LIBS external/randomx/librandomx.a)
zentra_lib(ZENTRA_STATIC_LIBS contrib/epee/src/libepee.a)
zentra_lib(ZENTRA_STATIC_LIBS external/db_drivers/liblmdb/liblmdb.a)
zentra_lib(ZENTRA_STATIC_LIBS external/easylogging++/libeasylogging.a)
zentra_lib(ZENTRA_STATIC_LIBS src/mnemonics/libmnemonics.a)
zentra_lib(ZENTRA_STATIC_LIBS src/libversion.a)

option(FFI_IOS "Build static libzentra_wallet_ffi for iOS (linked into app)" OFF)

# Cross builds use Zentra contrib/depends toolchain (sets DEPENDS=ON).
if(FFI_IOS)
  if(DEFINED IOS_DEPS_PREFIX)
    list(PREPEND CMAKE_PREFIX_PATH "${IOS_DEPS_PREFIX}")
  endif()
  set(Boost_NO_BOOST_CMAKE ON)
  set(Boost_USE_STATIC_LIBS ON)
  find_package(Boost REQUIRED COMPONENTS
    chrono filesystem thread serialization locale regex program_options date_time)
  find_package(OpenSSL REQUIRED)
  find_package(Protobuf REQUIRED)
  find_package(Threads REQUIRED)
elseif(DEPENDS OR ANDROID)
  find_package(Threads REQUIRED)
  if(ANDROID)
    find_library(LOG_LIB log)
  endif()
else()
  find_package(Boost REQUIRED COMPONENTS
    chrono filesystem thread serialization locale regex program_options date_time)
  find_package(OpenSSL REQUIRED)
  find_package(Protobuf REQUIRED)
  find_library(UNBOUND_LIB unbound)
  find_library(ZMQ_LIB zmq)
  find_library(USB_LIB usb-1.0)
  find_library(HIDAPI_LIB hidapi-libusb)
  find_library(SODIUM_LIB sodium)
  find_library(PGM_LIB pgm)
  find_library(NORM_LIB norm)
endif()

if(FFI_IOS)
  add_library(zentra_wallet_ffi STATIC src/zentra_wallet_ffi.cpp)
else()
  add_library(zentra_wallet_ffi SHARED src/zentra_wallet_ffi.cpp)
endif()

target_include_directories(zentra_wallet_ffi PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${ZENTRA_ROOT}/src
  ${ZENTRA_ROOT}/external/easylogging++
  ${ZENTRA_BUILD}/generated_include
)

if(NOT FFI_IOS)
  target_compile_options(zentra_wallet_ffi PRIVATE -fPIC)
endif()

if(FFI_IOS)
  find_library(SODIUM_LIB sodium PATHS ${IOS_DEPS_PREFIX}/lib NO_DEFAULT_PATH)
  target_link_libraries(zentra_wallet_ffi PRIVATE
    "-Wl,-all_load"
    ${ZENTRA_STATIC_LIBS}
    Boost::chrono Boost::filesystem Boost::thread Boost::serialization
    Boost::locale Boost::regex Boost::program_options Boost::date_time
    OpenSSL::SSL OpenSSL::Crypto
    protobuf::libprotobuf
    ${SODIUM_LIB}
    ${CMAKE_DL_LIBS}
    Threads::Threads
    "-framework Foundation" "-framework UIKit" "-framework Security"
    "-framework SystemConfiguration" "-framework CFNetwork"
  )
elseif(DEPENDS OR ANDROID)
  target_link_libraries(zentra_wallet_ffi PRIVATE
    -Wl,--start-group
    ${ZENTRA_STATIC_LIBS}
    -Wl,--end-group
    boost_chrono boost_filesystem boost_thread boost_serialization
    boost_locale boost_regex boost_program_options boost_date_time
    ssl crypto protobuf z sodium
    ${CMAKE_DL_LIBS}
    Threads::Threads
  )
  if(ANDROID)
    target_link_libraries(zentra_wallet_ffi PRIVATE ${LOG_LIB})
  endif()
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    target_link_libraries(zentra_wallet_ffi PRIVATE ws2_32 bcrypt iphlpapi)
  endif()
  if(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_link_libraries(zentra_wallet_ffi PRIVATE
      "-framework Foundation" "-framework IOKit" "-framework AppKit")
  endif()
  if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_link_libraries(zentra_wallet_ffi PRIVATE
      "-framework Foundation" "-framework UIKit" "-framework Security"
      "-framework SystemConfiguration" "-framework CFNetwork")
  endif()
else()
  target_link_libraries(zentra_wallet_ffi PRIVATE
    -Wl,--start-group
    ${ZENTRA_STATIC_LIBS}
    -Wl,--end-group
    Boost::chrono Boost::filesystem Boost::thread Boost::serialization
    Boost::locale Boost::regex Boost::program_options Boost::date_time
    OpenSSL::SSL OpenSSL::Crypto protobuf::libprotobuf
    ${UNBOUND_LIB} ${ZMQ_LIB} ${USB_LIB} ${HIDAPI_LIB}
    ${SODIUM_LIB} ${PGM_LIB} ${NORM_LIB}
    ${CMAKE_DL_LIBS} pthread rt
  )
endif()

set_target_properties(zentra_wallet_ffi PROPERTIES
  CXX_VISIBILITY_PRESET default
  POSITION_INDEPENDENT_CODE ON
)
