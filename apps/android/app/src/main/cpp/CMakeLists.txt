cmake_minimum_required(VERSION 3.22.1)

project(mollotov_android_jni LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(FetchContent)

set(BUILD_TESTING OFF CACHE BOOL "Disable native tests for Android JNI builds" FORCE)

set(MOLLOTOV_NATIVE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../native)

# Disable httplib in core-ai on Android — HTTPS is handled by OkHttp in Kotlin.
set(MOLLOTOV_AI_USE_HTTPLIB OFF CACHE BOOL "" FORCE)

# Skip desktop browser engines (CEF/Chromium) — not applicable on Android.
set(MOLLOTOV_BUILD_DESKTOP_ENGINES OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
  nlohmann_json
  GIT_REPOSITORY https://github.com/nlohmann/json.git
  GIT_TAG v3.11.3
  GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(nlohmann_json)

add_subdirectory(${MOLLOTOV_NATIVE_DIR} ${CMAKE_CURRENT_BINARY_DIR}/mollotov-native)

add_library(mollotov_jni SHARED
  mollotov_jni.cpp
)

target_link_libraries(mollotov_jni
  PRIVATE
    mollotov_core_state
    mollotov_core_protocol
    mollotov_core_ai
)
