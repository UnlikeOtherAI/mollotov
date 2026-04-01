#include "linux_app.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <utility>

#include "gui_shell.h"
#include "headless_shell.h"
#include "linux_app_internal.h"

#if MOLLOTOV_LINUX_HAS_CEF
#include "include/cef_app.h"
#endif

namespace mollotov::linuxapp {
std::string ReadTextFile(const std::filesystem::path& path) {
  std::ifstream stream(path);
  if (!stream.good()) {
    return std::string();
  }
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

void WriteTextFile(const std::filesystem::path& path, const std::string& contents) {
  std::filesystem::create_directories(path.parent_path());
  std::ofstream stream(path, std::ios::trunc);
  stream << contents;
}

std::string CategoryForFilter(const nlohmann::json& entry) {
  return entry.value("category", "Other");
}

LinuxApp::Impl::Impl(AppConfig app_config, int argc_value, char** argv_value)
    : config(std::move(app_config)),
      argc(argc_value),
      argv(argv_value),
      renderer(std::make_unique<StubRenderer>(config.url)),
      handler_context(renderer.get()),
      device_info(config.profile_dir) {}

void LinuxApp::Impl::LoadStores() {
  const std::filesystem::path root(config.profile_dir);
  bookmarks.LoadJson(ReadTextFile(root / "bookmarks.json"));
  history.LoadJson(ReadTextFile(root / "history.json"));
  console.LoadJson(ReadTextFile(root / "console.json"));
  network.LoadJson(ReadTextFile(root / "network.json"));
}

void LinuxApp::Impl::PersistStores() const {
  const std::filesystem::path root(config.profile_dir);
  WriteTextFile(root / "bookmarks.json", bookmarks.ToJson());
  WriteTextFile(root / "history.json", history.ToJson());
  WriteTextFile(root / "console.json", console.ToJson());
  WriteTextFile(root / "network.json", network.ToJson());
}

void LinuxApp::Impl::RecordNavigation(const std::string& url) {
  history.Record(url, renderer->CurrentTitle());
  network.AppendDocumentNavigation(url, 200, "text/html");
  PersistStores();
}

LinuxApp::LinuxApp(AppConfig config, int argc, char* argv[])
    : impl_(std::make_unique<Impl>(std::move(config), argc, argv)) {
  impl_->LoadStores();
  if (!impl_->config.url.empty()) {
    impl_->RecordNavigation(impl_->config.url);
  }
}

LinuxApp::~LinuxApp() {
#if MOLLOTOV_LINUX_HAS_CEF
  if (impl_->cef_initialized) {
    CefShutdown();
  }
#endif
}

int LinuxApp::Run() {
#if MOLLOTOV_LINUX_HAS_CEF
  CefMainArgs main_args(impl_->argc, impl_->argv);
  CefSettings settings;
  settings.no_sandbox = true;
  settings.windowless_rendering_enabled = impl_->config.headless;
  CefString(&settings.cache_path).FromString(impl_->config.profile_dir + "/cef-cache");
  CefString(&settings.root_cache_path).FromString(impl_->config.profile_dir + "/cef-root-cache");
  impl_->cef_initialized = CefInitialize(main_args, settings, nullptr, nullptr);
#endif

  std::string error;
  if (!impl_->http_server.Start(
          impl_->config.port,
          [this](std::string_view endpoint, const json& params, int* status) {
            return HandleApiRequest(endpoint, params, status);
          },
          &error)) {
    std::cerr << "Failed to start HTTP server: " << error << '\n';
    return 1;
  }
  impl_->bound_port = impl_->http_server.port();

  const DeviceInfoSnapshot snapshot = impl_->device_info.Collect();
  const bool mdns_started = impl_->mdns.Start(MdnsServiceConfig{
      snapshot,
      impl_->bound_port,
      impl_->config.width,
      impl_->config.height,
      impl_->version,
      RuntimeMode(),
  });
  impl_->mdns_status = mdns_started ? "active" : impl_->mdns.LastError();
  impl_->running = true;

  if (impl_->config.headless) {
    HeadlessShell shell(*this);
    const int result = shell.Run();
    impl_->running = false;
    impl_->mdns.Stop();
    impl_->http_server.Stop();
    impl_->PersistStores();
    return result;
  }

  if (!GuiAvailable()) {
    std::cerr << "GTK3 support is not available in this build. Rebuild with GTK or use --headless.\n";
    impl_->running = false;
    impl_->mdns.Stop();
    impl_->http_server.Stop();
    return 1;
  }

  GUIShell shell(*this);
  const int result = shell.Run();
  impl_->running = false;
  impl_->mdns.Stop();
  impl_->http_server.Stop();
  impl_->PersistStores();
  return result;
}

void LinuxApp::RequestShutdown() {
  impl_->shutdown_requested = true;
  impl_->running = false;
}

bool LinuxApp::IsRunning() const {
  return impl_->running && !impl_->shutdown_requested;
}

void LinuxApp::PumpBrowser() {
#if MOLLOTOV_LINUX_HAS_CEF
  if (impl_->cef_initialized) {
    CefDoMessageLoopWork();
  }
#endif
}

const AppConfig& LinuxApp::config() const {
  return impl_->config;
}

int LinuxApp::port() const {
  return impl_->bound_port;
}

bool LinuxApp::GuiAvailable() const {
  return MOLLOTOV_LINUX_HAS_GTK;
}

bool LinuxApp::MdnsActive() const {
  return impl_->mdns.IsRunning();
}

bool LinuxApp::ScreenshotSupported() const {
  return impl_->renderer->SupportsScreenshots();
}

std::string LinuxApp::MdnsStatusText() const {
  return impl_->mdns_status;
}

std::string LinuxApp::RuntimeMode() const {
  return impl_->config.headless ? "headless" : "gui";
}

bool LinuxApp::Navigate(const std::string& url) {
  impl_->renderer->LoadUrl(url);
  impl_->RecordNavigation(url);
  return true;
}

bool LinuxApp::GoBack() {
  if (!impl_->renderer->CanGoBack()) {
    return false;
  }
  impl_->renderer->GoBack();
  impl_->RecordNavigation(impl_->renderer->CurrentUrl());
  return true;
}

bool LinuxApp::GoForward() {
  if (!impl_->renderer->CanGoForward()) {
    return false;
  }
  impl_->renderer->GoForward();
  impl_->RecordNavigation(impl_->renderer->CurrentUrl());
  return true;
}

bool LinuxApp::Reload() {
  impl_->renderer->Reload();
  return true;
}

bool LinuxApp::CanGoBack() const {
  return impl_->renderer->CanGoBack();
}

bool LinuxApp::CanGoForward() const {
  return impl_->renderer->CanGoForward();
}

bool LinuxApp::IsLoading() const {
  return impl_->renderer->IsLoading();
}

std::string LinuxApp::CurrentUrl() const {
  return impl_->renderer->CurrentUrl();
}

std::string LinuxApp::CurrentTitle() const {
  return impl_->renderer->CurrentTitle();
}

void LinuxApp::AddBookmark(const std::string& title, const std::string& url) {
  impl_->bookmarks.Add(title, url);
  impl_->PersistStores();
}

void LinuxApp::RemoveBookmark(const std::string& id) {
  impl_->bookmarks.Remove(id);
  impl_->PersistStores();
}

void LinuxApp::ClearBookmarks() {
  impl_->bookmarks.RemoveAll();
  impl_->PersistStores();
}

void LinuxApp::ClearHistory() {
  impl_->history.Clear();
  impl_->PersistStores();
}

std::string LinuxApp::BookmarksJson() const {
  return impl_->bookmarks.ToJson();
}

std::string LinuxApp::HistoryJson() const {
  return impl_->history.ToJson();
}

void LinuxApp::ShowToast(const std::string& message) {
  std::lock_guard<std::mutex> lock(impl_->toast_mutex);
  impl_->pending_toast = message;
  if (impl_->config.headless && !message.empty()) {
    std::cout << "[toast] " << message << '\n';
  }
}

std::string LinuxApp::ConsumeToast() {
  std::lock_guard<std::mutex> lock(impl_->toast_mutex);
  std::string message = std::move(impl_->pending_toast);
  impl_->pending_toast.clear();
  return message;
}

}  // namespace mollotov::linuxapp
