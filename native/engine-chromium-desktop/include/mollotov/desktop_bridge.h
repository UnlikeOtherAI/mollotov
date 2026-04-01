#pragma once

#include <string>

namespace mollotov {

inline constexpr const char* kBridgeConsoleMessageName = "mollotov.bridge.console";
inline constexpr const char* kBridgeNetworkMessageName = "mollotov.bridge.network";

std::string ConsoleBridgeScript();
std::string NetworkBridgeScript();
std::string CombinedBridgeScript();

}  // namespace mollotov
