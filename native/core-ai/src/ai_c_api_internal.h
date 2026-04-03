#pragma once

#include <cstring>
#include <new>
#include <string>

#include <nlohmann/json.hpp>

#if MOLLOTOV_AI_HAS_HTTPLIB
#include "model_store.h"
#include "ollama_client.h"
#endif

namespace mollotov::ai_internal {

using json = nlohmann::json;

inline const char* SafeCString(const char* value) {
  return value == nullptr ? "" : value;
}

inline char* CopyString(const std::string& value) {
  char* buffer = new (std::nothrow) char[value.size() + 1];
  if (buffer == nullptr) return nullptr;
  std::memcpy(buffer, value.c_str(), value.size() + 1);
  return buffer;
}

}  // namespace mollotov::ai_internal

struct MollotovAiManager {
  std::string models_dir;
  std::string hf_token;
  std::string ollama_endpoint = "http://localhost:11434";
#if MOLLOTOV_AI_HAS_HTTPLIB
  mollotov::ModelStore store;
  mollotov::OllamaClient ollama;
#endif

  explicit MollotovAiManager(std::string dir)
      : models_dir(dir)
#if MOLLOTOV_AI_HAS_HTTPLIB
        , store(dir), ollama("http://localhost:11434")
#endif
  {}
};
