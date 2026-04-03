#include "mollotov/ai_c_api.h"
#include <cassert>
#include <iostream>

void TestOllamaEndpoint() {
  auto* mgr = mollotov_ai_create("/tmp/test_ollama");
  mollotov_ai_set_ollama_endpoint(mgr, "http://localhost:11434");
  // Reachability depends on live server -- just verify no crash
  mollotov_ai_ollama_reachable(mgr);
  mollotov_ai_destroy(mgr);
}

void TestOllamaListNoServer() {
  auto* mgr = mollotov_ai_create("/tmp/test_ollama");
  mollotov_ai_set_ollama_endpoint(mgr, "http://localhost:19999");
  // Should not crash, just return nullptr or empty
  char* result = mollotov_ai_ollama_list_models(mgr);
  // Result may be null if server unreachable -- that's fine
  if (result) mollotov_ai_free_string(result);
  mollotov_ai_destroy(mgr);
}

void TestOllamaInferNoServer() {
  auto* mgr = mollotov_ai_create("/tmp/test_ollama");
  mollotov_ai_set_ollama_endpoint(mgr, "http://localhost:19999");
  char* result = mollotov_ai_ollama_infer(mgr, "test-model", "{\"prompt\":\"hello\"}");
  // Should return error JSON or nullptr
  if (result) mollotov_ai_free_string(result);
  mollotov_ai_destroy(mgr);
}

int main() {
  TestOllamaEndpoint();
  TestOllamaListNoServer();
  TestOllamaInferNoServer();
  std::cout << "PASS: test_ai_ollama" << std::endl;
  return 0;
}
