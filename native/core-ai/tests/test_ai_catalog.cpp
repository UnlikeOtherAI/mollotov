#include "mollotov/ai_c_api.h"
#include <cassert>
#include <iostream>

void TestCreateDestroy() {
  auto* mgr = mollotov_ai_create("/tmp/test_models");
  assert(mgr != nullptr);
  mollotov_ai_destroy(mgr);
}

int main() {
  TestCreateDestroy();
  std::cout << "PASS: test_ai_catalog" << std::endl;
  return 0;
}
