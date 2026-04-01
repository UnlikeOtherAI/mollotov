cmake_minimum_required(VERSION 3.16)

project(mollotov_linux LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(MOLLOTOV_LINUX_HEADLESS_ONLY "Build Mollotov Linux without GTK UI support" OFF)

include(FetchContent)
find_package(PkgConfig REQUIRED)
find_package(Threads REQUIRED)
find_package(nlohmann_json CONFIG QUIET)

if(NOT TARGET nlohmann_json::nlohmann_json)
  find_path(MOLLOTOV_LINUX_NLOHMANN_JSON_INCLUDE_DIR
    NAMES nlohmann/json.hpp
  )
  if(MOLLOTOV_LINUX_NLOHMANN_JSON_INCLUDE_DIR)
    add_library(mollotov_linux_nlohmann_json INTERFACE)
    target_include_directories(mollotov_linux_nlohmann_json INTERFACE
      "${MOLLOTOV_LINUX_NLOHMANN_JSON_INCLUDE_DIR}"
    )
    add_library(nlohmann_json::nlohmann_json ALIAS mollotov_linux_nlohmann_json)
  endif()
endif()

if(NOT TARGET nlohmann_json::nlohmann_json)
  FetchContent_Declare(
    nlohmann_json
    URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  )
  FetchContent_MakeAvailable(nlohmann_json)
endif()

set(MOLLOTOV_LINUX_HAS_CEF 0)
set(MOLLOTOV_LINUX_CEF_LIB "")
if(DEFINED CEF_ROOT AND EXISTS "${CEF_ROOT}/include/cef_app.h")
  find_library(MOLLOTOV_LINUX_CEF_LIB
    NAMES cef libcef
    PATHS "${CEF_ROOT}/Release" "${CEF_ROOT}/Debug"
    NO_DEFAULT_PATH
  )
  if(MOLLOTOV_LINUX_CEF_LIB)
    set(MOLLOTOV_LINUX_HAS_CEF 1)
  endif()
endif()

set(BUILD_TESTING OFF CACHE BOOL "Disable native library tests for app builds" FORCE)
set(MOLLOTOV_ENABLE_CHROMIUM_DESKTOP ${MOLLOTOV_LINUX_HAS_CEF} CACHE BOOL
    "Build the shared Chromium desktop engine with CEF for the Linux app" FORCE)
set(MOLLOTOV_NATIVE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../native")
add_subdirectory("${MOLLOTOV_NATIVE_ROOT}" "${CMAKE_BINARY_DIR}/mollotov-native")

set(MOLLOTOV_LINUX_HAS_GTK 0)
if(NOT MOLLOTOV_LINUX_HEADLESS_ONLY)
  pkg_check_modules(GTK3 IMPORTED_TARGET gtk+-3.0)
  if(GTK3_FOUND)
    set(MOLLOTOV_LINUX_HAS_GTK 1)
  endif()
endif()

set(MOLLOTOV_LINUX_HAS_AVAHI 0)
pkg_check_modules(AVAHI_CLIENT IMPORTED_TARGET avahi-client)
if(AVAHI_CLIENT_FOUND)
  set(MOLLOTOV_LINUX_HAS_AVAHI 1)
endif()

add_executable(mollotov-linux
  src/main.cpp
  src/http_server.cpp
  src/linux_app.cpp
  src/linux_app_api.cpp
  src/headless_shell.cpp
  src/gui_shell.cpp
  src/gtk_browser_view.cpp
  src/url_bar.cpp
  src/settings_view.cpp
  src/bookmarks_view.cpp
  src/history_view.cpp
  src/network_inspector.cpp
  src/toast_view.cpp
  src/device_info_linux.cpp
  src/mdns_avahi.cpp
  src/stub_renderer.cpp
)

target_include_directories(mollotov-linux
  PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)

target_compile_definitions(mollotov-linux
  PRIVATE
    MOLLOTOV_LINUX_HAS_GTK=${MOLLOTOV_LINUX_HAS_GTK}
    MOLLOTOV_LINUX_HAS_AVAHI=${MOLLOTOV_LINUX_HAS_AVAHI}
    MOLLOTOV_LINUX_HAS_CEF=${MOLLOTOV_LINUX_HAS_CEF}
    MOLLOTOV_LINUX_VERSION="0.1.0-dev"
)

if(MOLLOTOV_LINUX_HAS_CEF)
  target_include_directories(mollotov-linux PRIVATE "${CEF_ROOT}")
  target_link_libraries(mollotov-linux PRIVATE "${MOLLOTOV_LINUX_CEF_LIB}")
endif()

if(MOLLOTOV_LINUX_HAS_GTK)
  target_link_libraries(mollotov-linux PRIVATE PkgConfig::GTK3)
endif()

if(MOLLOTOV_LINUX_HAS_AVAHI)
  target_link_libraries(mollotov-linux PRIVATE PkgConfig::AVAHI_CLIENT)
endif()

target_link_libraries(mollotov-linux
  PRIVATE
    mollotov_core_protocol
    mollotov_core_state
    mollotov_core_automation
    mollotov_core_mcp
    nlohmann_json::nlohmann_json
    Threads::Threads
)

if(TARGET mollotov_engine_chromium_desktop)
  target_link_libraries(mollotov-linux PRIVATE mollotov_engine_chromium_desktop)
endif()

set_target_properties(mollotov-linux PROPERTIES OUTPUT_NAME "mollotov-linux")
