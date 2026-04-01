#pragma once

#if MOLLOTOV_LINUX_HAS_GTK
#include <gtk/gtk.h>
#else
typedef struct _GtkWidget GtkWidget;
#endif

namespace mollotov::linuxapp {

class LinuxApp;

class BookmarksView {
 public:
  explicit BookmarksView(LinuxApp& app);

  GtkWidget* widget() const;
  void Refresh();

 private:
  LinuxApp& app_;
  GtkWidget* root_ = nullptr;
  GtkWidget* list_ = nullptr;
};

}  // namespace mollotov::linuxapp
