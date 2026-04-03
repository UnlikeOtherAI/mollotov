include(FetchContent)

option(MOLLOTOV_AI_USE_HTTPLIB "Enable cpp-httplib for HTTP clients (Ollama, HF download/cloud)" ON)

set(CORE_AI_SOURCES
  src/ai_c_api.cpp
  src/model_catalog.cpp
)

if(MOLLOTOV_AI_USE_HTTPLIB)
  FetchContent_Declare(
    cpp_httplib
    GIT_REPOSITORY https://github.com/yhirose/cpp-httplib.git
    GIT_TAG v0.18.3
    GIT_SHALLOW TRUE
  )
  FetchContent_MakeAvailable(cpp_httplib)

  list(APPEND CORE_AI_SOURCES
    src/hf_cloud_client.cpp
    src/model_store.cpp
    src/ollama_client.cpp
  )
endif()

add_library(mollotov_core_ai STATIC ${CORE_AI_SOURCES})

target_include_directories(mollotov_core_ai
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(mollotov_core_ai
  PUBLIC
    mollotov_core_protocol
    nlohmann_json::nlohmann_json
)

if(MOLLOTOV_AI_USE_HTTPLIB)
  target_link_libraries(mollotov_core_ai PRIVATE httplib::httplib)
  target_compile_definitions(mollotov_core_ai PUBLIC MOLLOTOV_AI_HAS_HTTPLIB=1)
endif()

if(BUILD_TESTING)
  add_subdirectory(tests)
endif()
