#include "url_bar.h"

#include "linux_app.h"

#if MOLLOTOV_LINUX_HAS_GTK
#include <gtk/gtk.h>
#endif

namespace mollotov::linuxapp {

UrlBar::UrlBar(LinuxApp& app) : app_(app) {
#if MOLLOTOV_LINUX_HAS_GTK
  root_ = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
  back_button_ = gtk_button_new_with_label("Back");
  forward_button_ = gtk_button_new_with_label("Forward");
  reload_button_ = gtk_button_new_with_label("Reload");
  entry_ = gtk_entry_new();
  gtk_entry_set_placeholder_text(GTK_ENTRY(entry_), "Enter URL");

  gtk_box_pack_start(GTK_BOX(root_), back_button_, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(root_), forward_button_, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(root_), reload_button_, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(root_), entry_, TRUE, TRUE, 0);

  g_signal_connect_swapped(back_button_, "clicked", G_CALLBACK(+[](LinuxApp* app_ptr) { app_ptr->GoBack(); }),
                           &app_);
  g_signal_connect_swapped(forward_button_, "clicked",
                           G_CALLBACK(+[](LinuxApp* app_ptr) { app_ptr->GoForward(); }), &app_);
  g_signal_connect_swapped(reload_button_, "clicked", G_CALLBACK(+[](LinuxApp* app_ptr) { app_ptr->Reload(); }),
                           &app_);
  g_signal_connect(entry_, "activate", G_CALLBACK(+[](GtkEntry* entry, gpointer user_data) {
                     auto* app_ptr = static_cast<LinuxApp*>(user_data);
                     app_ptr->Navigate(gtk_entry_get_text(entry));
                   }),
                   &app_);
  Sync();
#endif
}

GtkWidget* UrlBar::widget() const {
  return root_;
}

void UrlBar::Sync() {
#if MOLLOTOV_LINUX_HAS_GTK
  if (entry_ == nullptr) {
    return;
  }
  gtk_entry_set_text(GTK_ENTRY(entry_), app_.CurrentUrl().c_str());
  gtk_widget_set_sensitive(back_button_, app_.CanGoBack());
  gtk_widget_set_sensitive(forward_button_, app_.CanGoForward());
#endif
}

}  // namespace mollotov::linuxapp
