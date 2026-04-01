#pragma once

#if MOLLOTOV_LINUX_HAS_GTK
#include <gtk/gtk.h>
#else
typedef struct _GtkWidget GtkWidget;
#endif

#include <string>

namespace mollotov::linuxapp {

class ToastView {
 public:
  ToastView();

  GtkWidget* widget() const;
  void Show(const std::string& message);

 private:
  GtkWidget* revealer_ = nullptr;
  GtkWidget* label_ = nullptr;
};

}  // namespace mollotov::linuxapp
