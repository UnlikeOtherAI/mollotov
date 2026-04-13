#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include <nlohmann/json.hpp>

namespace kelpie {
class HandlerContext;
}

namespace kelpie::linuxapp {

enum class ScreenshotResolution {
  kNative,
  kViewport,
};

struct ScreenshotViewportMetrics {
  int viewport_width = 1;
  int viewport_height = 1;
  double device_pixel_ratio = 1.0;
};

std::optional<ScreenshotResolution> ParseScreenshotResolution(const nlohmann::json& params);
ScreenshotViewportMetrics LoadScreenshotViewportMetrics(kelpie::HandlerContext& context);
nlohmann::json ScreenshotMetadata(int image_width, int image_height, std::string_view format,
                                  ScreenshotResolution resolution,
                                  const ScreenshotViewportMetrics& viewport);
std::optional<std::pair<int, int>> ParsePngDimensions(const std::vector<std::uint8_t>& bytes);
std::vector<std::uint8_t> ScaleScreenshotBytes(const std::vector<std::uint8_t>& bytes,
                                               ScreenshotResolution resolution,
                                               const ScreenshotViewportMetrics& viewport);

std::string AnnotationElementsScript();
std::string SelectorActivationScript(std::string_view selector);
std::string AnnotationActivationScript(int index);
std::string FillAnnotationScript(int index, std::string_view value);

}  // namespace kelpie::linuxapp
