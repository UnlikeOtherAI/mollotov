#pragma once

namespace mollotov::linuxapp {

class LinuxApp;

class GUIShell {
 public:
  explicit GUIShell(LinuxApp& app);

  int Run();

 private:
  LinuxApp& app_;
};

}  // namespace mollotov::linuxapp
