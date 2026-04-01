#pragma once

namespace mollotov::linuxapp {

class LinuxApp;

class HeadlessShell {
 public:
  explicit HeadlessShell(LinuxApp& app);

  int Run();

 private:
  LinuxApp& app_;
};

}  // namespace mollotov::linuxapp
