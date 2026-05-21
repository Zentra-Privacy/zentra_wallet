cmake_minimum_required(VERSION 3.16)
project(zentra_wallet_ffi LANGUAGES CXX)

set(ZENTRA_ROOT "$ENV{ZENTRA_ROOT}")
set(ZENTRA_BUILD "$ENV{ZENTRA_BUILD_DIR}")

if(NOT ZENTRA_ROOT OR NOT EXISTS "${ZENTRA_ROOT}/src/wallet/api/wallet2_api.h")
  message(FATAL_ERROR "Set ZENTRA_ROOT to the zentra source tree")
endif()
if(NOT ZENTRA_BUILD OR NOT EXISTS "${ZENTRA_BUILD}/lib/libwallet_api.a")
  message(
    FATAL_ERROR
    "Set ZENTRA_BUILD_DIR to zentra/build/release and build wallet_api first")
endif()

set(CMAKE_CXX_STANDARD 17)

# --- Zentra static archives (paths match out-of-tree CMake build layout) ---
macro(zentra_lib outvar relpath)
  set(_lib "${ZENTRA_BUILD}/${relpath}")
  if(NOT EXISTS "${_lib}")
    message(FATAL_ERROR "Missing Zentra library: ${_lib}\nRun: cmake --build \"${ZENTRA_BUILD}\" --target wallet_api")
  endif()
  list(APPEND ${outvar} "${_lib}")
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
zentra_lib(ZENTRA_STATIC_LIBS src/crypto/wallet/libwallet-crypto.a)
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

add_library(zentra_wallet_ffi SHARED src/zentra_wallet_ffi.cpp)

target_include_directories(zentra_wallet_ffi PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${ZENTRA_ROOT}/src
  ${ZENTRA_ROOT}/external/easylogging++
  ${ZENTRA_BUILD}/generated_include
)

target_compile_options(zentra_wallet_ffi PRIVATE -fPIC)

# Same dependency closure as zentra-wallet-cli (static libs + system libs).
target_link_libraries(zentra_wallet_ffi PRIVATE
  -Wl,--start-group
  ${ZENTRA_STATIC_LIBS}
  -Wl,--end-group
  Boost::chrono
  Boost::filesystem
  Boost::thread
  Boost::serialization
  Boost::locale
  Boost::regex
  Boost::program_options
  Boost::date_time
  OpenSSL::SSL
  OpenSSL::Crypto
  protobuf::libprotobuf
  ${UNBOUND_LIB}
  ${ZMQ_LIB}
  ${USB_LIB}
  ${HIDAPI_LIB}
  ${SODIUM_LIB}
  ${PGM_LIB}
  ${NORM_LIB}
  ${CMAKE_DL_LIBS}
  pthread
  rt
)

set_target_properties(zentra_wallet_ffi PROPERTIES
  CXX_VISIBILITY_PRESET default
  POSITION_INDEPENDENT_CODE ON
)
