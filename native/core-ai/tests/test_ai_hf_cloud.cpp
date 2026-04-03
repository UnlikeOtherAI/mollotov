#include "mollotov/ai_c_api.h"

#include <cassert>
#include <iostream>
#include <string>

#include <nlohmann/json.hpp>

using json = nlohmann::json;

void TestHfInferNoToken() {
  auto* mgr = mollotov_ai_create("/tmp/test_hf");
  // No token set — should return auth_required error
  char* result = mollotov_ai_hf_infer(
      mgr, "google/gemma-2-2b-it", "{\"prompt\":\"hello\"}");
  assert(result != nullptr);
  json resp = json::parse(result);
  assert(resp["error"] == "auth_required");
  mollotov_ai_free_string(result);
  mollotov_ai_destroy(mgr);
}

void TestHfInferWithToken() {
  auto* mgr = mollotov_ai_create("/tmp/test_hf");
  mollotov_ai_set_hf_token(mgr, "hf_fake_token");
  // With a fake token, should get a network or auth error (not crash)
  char* result = mollotov_ai_hf_infer(
      mgr, "google/gemma-2-2b-it", "{\"prompt\":\"hello\"}");
  assert(result != nullptr);
  json resp = json::parse(result);
  // Should be some error (network, auth, etc.) since token is fake
  assert(resp.contains("error") || resp.contains("response"));
  mollotov_ai_free_string(result);
  mollotov_ai_destroy(mgr);
}

void TestHfInferChatFormat() {
  auto* mgr = mollotov_ai_create("/tmp/test_hf");
  mollotov_ai_set_hf_token(mgr, "hf_fake_token");
  json req = {
      {"messages", json::array({{{"role", "user"}, {"content", "hi"}}})}};
  char* result = mollotov_ai_hf_infer(
      mgr, "google/gemma-2-2b-it", req.dump().c_str());
  assert(result != nullptr);
  // Just verify it doesn't crash and returns valid JSON
  json resp = json::parse(result);
  mollotov_ai_free_string(result);
  mollotov_ai_destroy(mgr);
}

int main() {
  TestHfInferNoToken();
  TestHfInferWithToken();
  TestHfInferChatFormat();
  std::cout << "PASS: test_ai_hf_cloud" << std::endl;
  return 0;
}
