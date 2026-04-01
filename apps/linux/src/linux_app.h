#pragma once

#include <memory>
#include <optional>
#include <string>
#include <string_view>

#include <nlohmann/json.hpp>

namespace mollotov::linuxapp {

struct AppConfig {
  bool headless = false;
  int port = 8420;
  std::string profile_dir;
  std::string url;
  int width = 1920;
  int height = 1080;
};

class LinuxApp {
 public:
  using json = nlohmann::json;

  LinuxApp(AppConfig config, int argc, char* argv[]);
  ~LinuxApp();

  int Run();
  void RequestShutdown();
  bool IsRunning() const;
  void PumpBrowser();

  const AppConfig& config() const;
  int port() const;
  bool GuiAvailable() const;
  bool MdnsActive() const;
  bool ScreenshotSupported() const;
  std::string MdnsStatusText() const;
  std::string RuntimeMode() const;

  bool Navigate(const std::string& url);
  bool GoBack();
  bool GoForward();
  bool Reload();
  bool CanGoBack() const;
  bool CanGoForward() const;
  bool IsLoading() const;
  std::string CurrentUrl() const;
  std::string CurrentTitle() const;

  void AddBookmark(const std::string& title, const std::string& url);
  void RemoveBookmark(const std::string& id);
  void ClearBookmarks();
  void ClearHistory();

  std::string BookmarksJson() const;
  std::string HistoryJson() const;
  json ConsoleMessages(const std::optional<std::string>& level = std::nullopt) const;
  json NetworkEntries(const std::optional<std::string>& method = std::nullopt,
                      const std::optional<std::string>& type = std::nullopt,
                      const std::optional<std::string>& source = std::nullopt) const;
  json DeviceInfo() const;
  json Capabilities() const;
  json HandleApiRequest(std::string_view endpoint, const json& params, int* status_code);

  void ShowToast(const std::string& message);
  std::string ConsumeToast();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace mollotov::linuxapp
