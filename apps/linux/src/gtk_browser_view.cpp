#include "gtk_browser_view.h"

#include "linux_app.h"

#if MOLLOTOV_LINUX_HAS_GTK
#include <gtk/gtk.h>
#if defined(GDK_WINDOWING_X11)
#include <gdk/gdkx.h>
#endif
#endif

namespace mollotov::linuxapp {

GtkBrowserView::GtkBrowserView(LinuxApp& app) : app_(app) {
#if MOLLOTOV_LINUX_HAS_GTK
  frame_ = gtk_frame_new(nullptr);
  label_ = gtk_label_new("");
  gtk_container_add(GTK_CONTAINER(frame_), label_);
  gtk_widget_set_hexpand(frame_, TRUE);
  gtk_widget_set_vexpand(frame_, TRUE);
  Sync();

#if defined(GDK_WINDOWING_X11)
  g_signal_connect(frame_, "realize", G_CALLBACK(+[](GtkWidget* widget, gpointer) {
                     GdkWindow* window = gtk_widget_get_window(widget);
                     if (window != nullptr) {
                       const unsigned long xid = GDK_WINDOW_XID(window);
                       gtk_widget_set_tooltip_text(widget, ("X11 host window: " + std::to_string(xid)).c_str());
                     }
                   }),
                   nullptr);
#endif
#endif
}

GtkWidget* GtkBrowserView::widget() const {
  return frame_;
}

void GtkBrowserView::Sync() {
#if MOLLOTOV_LINUX_HAS_GTK
  if (label_ == nullptr) {
    return;
  }
  const std::string text =
      "Browser host\nURL: " + app_.CurrentUrl() + "\nTitle: " + app_.CurrentTitle() +
      "\nScreenshots: " + std::string(app_.ScreenshotSupported() ? "enabled" : "unavailable without CEF");
  gtk_label_set_text(GTK_LABEL(label_), text.c_str());
#endif
}

}  // namespace mollotov::linuxapp
