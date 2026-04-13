#pragma once

#include <optional>
#include <string>
#include <string_view>

#include <nlohmann/json.hpp>

namespace kelpie::linuxapp {

struct TapCalibration {
  double offset_x = 0;
  double offset_y = 0;
};

TapCalibration LoadTapCalibration(const std::string& profile_dir);
TapCalibration SaveTapCalibration(const std::string& profile_dir, double offset_x, double offset_y);
std::optional<double> JsonNumber(const nlohmann::json& params, std::string_view key);
double ClampCoordinate(double value, double lower, double upper);
std::string OverlayRgbFromHex(const std::string& hex);
std::string TapScript(double requested_x, double requested_y, double applied_x, double applied_y,
                      double offset_x, double offset_y, std::string_view color_rgb);

}  // namespace kelpie::linuxapp
