#include "mollotov/desktop_mcp_server.h"

#include <cassert>

#include "mollotov/desktop_router.h"
#include "mollotov/mcp_registry.h"

int main() {
  mollotov::DesktopRouter router;
  router.Register("navigate", [](const nlohmann::json& params) {
    return nlohmann::json{{"success", true}, {"url", params.value("url", std::string())}};
  });

  mollotov::McpRegistry registry;
  mollotov::DesktopMcpServer server;
  server.SetRouter(&router);
  server.SetRegistry(&registry);

  mollotov::DesktopMcpServer::Config config;
  config.platform = mollotov::Platform::kLinux;
  config.engine = "chromium";

  const auto init = server.HandleRequest({{"jsonrpc", "2.0"}, {"id", 1}, {"method", "initialize"}}, config);
  assert(init["result"]["serverInfo"]["name"] == "mollotov-desktop");

  const auto tools = server.HandleRequest({{"jsonrpc", "2.0"}, {"id", 2}, {"method", "tools/list"}}, config);
  const auto& listed = tools["result"]["tools"];
  bool found_navigate = false;
  bool found_safari_auth = false;
  for (const auto& tool : listed) {
    found_navigate = found_navigate || tool["name"] == "mollotov_navigate";
    found_safari_auth = found_safari_auth || tool["name"] == "mollotov_safari_auth";
  }
  assert(found_navigate);
  assert(!found_safari_auth);

  const auto call = server.HandleRequest(
      {{"jsonrpc", "2.0"},
       {"id", 3},
       {"method", "tools/call"},
       {"params", {{"name", "mollotov_navigate"}, {"arguments", {{"url", "https://example.com"}}}}}},
      config);
  assert(call["result"]["isError"] == false);
  assert(call["result"]["structuredContent"]["url"] == "https://example.com");

  return 0;
}
