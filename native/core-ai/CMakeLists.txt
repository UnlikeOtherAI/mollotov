add_library(mollotov_core_ai STATIC
  src/ai_c_api.cpp
  src/model_catalog.cpp
)

target_include_directories(mollotov_core_ai
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(mollotov_core_ai
  PUBLIC
    mollotov_core_protocol
    nlohmann_json::nlohmann_json
)

if(BUILD_TESTING)
  add_subdirectory(tests)
endif()
