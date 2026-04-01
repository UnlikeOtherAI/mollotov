#include "gui_shell.h"

#include "bookmarks_view.h"
#include "gtk_browser_view.h"
#include "history_view.h"
#include "linux_app.h"
#include "network_inspector.h"
#include "settings_view.h"
#include "toast_view.h"
#include "url_bar.h"

#if MOLLOTOV_LINUX_HAS_GTK
#include <gtk/gtk.h>
#endif

namespace mollotov::linuxapp {

GUIShell::GUIShell(LinuxApp& app) : app_(app) {}

int GUIShell::Run() {
#if MOLLOTOV_LINUX_HAS_GTK
  gtk_init(nullptr, nullptr);

  auto* window = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
  gtk_window_set_title(window, "Mollotov Linux");
  gtk_window_set_default_size(window, app_.config().width, app_.config().height);

  UrlBar url_bar(app_);
  GtkBrowserView browser(app_);
  BookmarksView bookmarks(app_);
  HistoryView history(app_);
  NetworkInspector network(app_);
  SettingsView settings(app_);
  ToastView toast;

  GtkWidget* content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  gtk_container_add(GTK_CONTAINER(window), content);
  gtk_box_pack_start(GTK_BOX(content), url_bar.widget(), FALSE, FALSE, 0);

  GtkWidget* overlay = gtk_overlay_new();
  gtk_box_pack_start(GTK_BOX(content), overlay, TRUE, TRUE, 0);
  gtk_container_add(GTK_CONTAINER(overlay), browser.widget());
  gtk_overlay_add_overlay(GTK_OVERLAY(overlay), toast.widget());

  GtkWidget* menu_button = gtk_menu_button_new();
  gtk_button_set_label(GTK_BUTTON(menu_button), "Menu");
  gtk_widget_set_halign(menu_button, GTK_ALIGN_END);
  gtk_widget_set_valign(menu_button, GTK_ALIGN_START);
  gtk_widget_set_margin_top(menu_button, 12);
  gtk_widget_set_margin_end(menu_button, 12);
  gtk_overlay_add_overlay(GTK_OVERLAY(overlay), menu_button);

  GtkWidget* menu = gtk_menu_new();
  GtkWidget* bookmarks_item = gtk_menu_item_new_with_label("Bookmarks");
  GtkWidget* history_item = gtk_menu_item_new_with_label("History");
  GtkWidget* network_item = gtk_menu_item_new_with_label("Network");
  GtkWidget* settings_item = gtk_menu_item_new_with_label("Settings");
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), bookmarks_item);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), history_item);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), network_item);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), settings_item);
  gtk_widget_show_all(menu);
  gtk_menu_button_set_popup(GTK_MENU_BUTTON(menu_button), menu);

  GtkWidget* bookmarks_dialog = gtk_dialog_new_with_buttons(
      "Bookmarks", window, static_cast<GtkDialogFlags>(GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT), "_Close", GTK_RESPONSE_CLOSE, nullptr);
  gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(bookmarks_dialog))),
                    bookmarks.widget());
  g_signal_connect_swapped(bookmarks_dialog, "response", G_CALLBACK(gtk_widget_hide), bookmarks_dialog);

  GtkWidget* history_dialog = gtk_dialog_new_with_buttons(
      "History", window, static_cast<GtkDialogFlags>(GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT), "_Close", GTK_RESPONSE_CLOSE, nullptr);
  gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(history_dialog))), history.widget());
  g_signal_connect_swapped(history_dialog, "response", G_CALLBACK(gtk_widget_hide), history_dialog);

  GtkWidget* network_dialog = gtk_dialog_new_with_buttons(
      "Network", window, static_cast<GtkDialogFlags>(GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT), "_Close", GTK_RESPONSE_CLOSE, nullptr);
  gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(network_dialog))), network.widget());
  g_signal_connect_swapped(network_dialog, "response", G_CALLBACK(gtk_widget_hide), network_dialog);

  g_signal_connect_swapped(bookmarks_item, "activate", G_CALLBACK(+[](BookmarksView* view) { view->Refresh(); }),
                           &bookmarks);
  g_signal_connect_swapped(bookmarks_item, "activate", G_CALLBACK(gtk_widget_show_all), bookmarks_dialog);

  g_signal_connect_swapped(history_item, "activate", G_CALLBACK(+[](HistoryView* view) { view->Refresh(); }),
                           &history);
  g_signal_connect_swapped(history_item, "activate", G_CALLBACK(gtk_widget_show_all), history_dialog);

  g_signal_connect_swapped(network_item, "activate", G_CALLBACK(+[](NetworkInspector* view) { view->Refresh(); }),
                           &network);
  g_signal_connect_swapped(network_item, "activate", G_CALLBACK(gtk_widget_show_all), network_dialog);

  g_signal_connect_swapped(settings_item, "activate",
                           G_CALLBACK(+[](SettingsView* view) { view->Refresh(); }), &settings);
  g_signal_connect(settings_item, "activate", G_CALLBACK(+[](GtkMenuItem*, gpointer user_data) {
                     auto** values = static_cast<void**>(user_data);
                     static_cast<SettingsView*>(values[0])->Show(GTK_WINDOW(values[1]));
                   }),
                   static_cast<gpointer>(new void*[2]{&settings, window}));

  g_signal_connect_swapped(window, "destroy", G_CALLBACK(+[](LinuxApp* app) {
                             app->RequestShutdown();
                             gtk_main_quit();
                           }),
                           &app_);

  g_timeout_add(
      10,
      +[](gpointer user_data) -> gboolean {
        auto* app = static_cast<LinuxApp*>(user_data);
        if (!app->IsRunning()) {
          return G_SOURCE_REMOVE;
        }
        app->PumpBrowser();
        return G_SOURCE_CONTINUE;
      },
      &app_);

  g_timeout_add(
      250,
      +[](gpointer user_data) -> gboolean {
        auto** values = static_cast<void**>(user_data);
        auto* app = static_cast<LinuxApp*>(values[0]);
        auto* url = static_cast<UrlBar*>(values[1]);
        auto* browser_view = static_cast<GtkBrowserView*>(values[2]);
        auto* bookmarks_view = static_cast<BookmarksView*>(values[3]);
        auto* history_view = static_cast<HistoryView*>(values[4]);
        auto* network_view = static_cast<NetworkInspector*>(values[5]);
        auto* toast_view = static_cast<ToastView*>(values[6]);
        if (!app->IsRunning()) {
          return G_SOURCE_REMOVE;
        }
        url->Sync();
        browser_view->Sync();
        bookmarks_view->Refresh();
        history_view->Refresh();
        network_view->Refresh();
        const std::string message = app->ConsumeToast();
        if (!message.empty()) {
          toast_view->Show(message);
        }
        return G_SOURCE_CONTINUE;
      },
      new void*[7]{&app_, &url_bar, &browser, &bookmarks, &history, &network, &toast});

  gtk_widget_show_all(GTK_WIDGET(window));
  gtk_main();
  return 0;
#else
  (void)app_;
  return 1;
#endif
}

}  // namespace mollotov::linuxapp
