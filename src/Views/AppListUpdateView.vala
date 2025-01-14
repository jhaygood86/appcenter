/*-
 * Copyright (c) 2014-2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Jeremy Wootten <jeremy@elementaryos.org>
 */

namespace AppCenter.Views {
/** AppList for the Updates View. Sorts update_available first and shows headers.
      * Does not show Uninstall Button **/
    public class AppListUpdateView : AbstractAppList {
        private Gtk.SizeGroup action_button_group;
        private bool updating_all_apps = false;

        construct {
            action_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);

            var loading_view = new Granite.Widgets.AlertView (
                _("Checking for Updates"),
                _("Downloading a list of available updates to the OS and installed apps"),
                "sync-synchronizing"
            );
            loading_view.show_all ();

            list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) row_update_header);
            list_box.set_placeholder (loading_view);

            var info_label = new Gtk.Label (_("A restart is required to finish installing updates"));
            info_label.show ();

            var infobar = new Gtk.InfoBar ();
            infobar.message_type = Gtk.MessageType.WARNING;
            infobar.no_show_all = true;
            infobar.get_content_area ().add (info_label);

            var restart_button = infobar.add_button (_("Restart Now"), 0);
            action_button_group.add_widget (restart_button);

            infobar.response.connect ((response) => {
                if (response == 0) {
                    try {
                        SuspendControl.get_default ().reboot ();
                    } catch (GLib.Error e) {
                        if (!(e is IOError.CANCELLED)) {
                            info_label.label = _("Requesting a restart failed. Restart manually to finish installing updates");
                            infobar.message_type = Gtk.MessageType.ERROR;
                            restart_button.visible = false;
                        }
                    }
                }
            });

            AppCenterCore.UpdateManager.get_default ().bind_property ("restart-required", infobar, "visible", BindingFlags.SYNC_CREATE);

            add (infobar);
            add (scrolled);
        }

        public override void add_packages (Gee.Collection<AppCenterCore.Package> packages) {
            foreach (var package in packages) {
                add_row_for_package (package);
            }

            on_list_changed ();
        }

        public override void add_package (AppCenterCore.Package package) {
            add_row_for_package (package);
            on_list_changed ();
        }

        private void add_row_for_package (AppCenterCore.Package package) {
            var needs_update = package.state == AppCenterCore.Package.State.UPDATE_AVAILABLE;

            // Only add row if this package needs an update or it's not a font or plugin
            if (needs_update || (!package.is_plugin && !package.is_font)) {
                var row = construct_row_for_package (package);
                add_row (row);
            }
        }

        protected override void on_list_changed () {
            list_box.invalidate_sort ();
        }

        protected override AppRowInterface construct_row_for_package (AppCenterCore.Package package) {
            return new Widgets.PackageRow.installed (package, info_grid_group, action_button_group);
        }

        [CCode (instance_pos = -1)]
        protected override int package_row_compare (AppRowInterface row1, AppRowInterface row2) {
            bool a_is_updating = row1.get_is_updating ();
            bool b_is_updating = row2.get_is_updating ();

            // The currently updating package is always top of the list
            if (a_is_updating || b_is_updating) {
                return a_is_updating ? -1 : 1;
            }

            bool a_has_updates = row1.get_update_available ();
            bool b_has_updates = row2.get_update_available ();

            bool a_is_os = row1.get_is_os_updates ();
            bool b_is_os = row2.get_is_os_updates ();

            // Sort updatable OS updates first, then other updatable packages
            if (a_has_updates != b_has_updates) {
                if (a_is_os && a_has_updates) {
                    return -1;
                }

                if (b_is_os && b_has_updates) {
                    return 1;
                }

                if (a_has_updates) {
                    return -1;
                }

                if (b_has_updates) {
                    return 1;
                }
            }

            bool a_is_driver = row1.get_is_driver ();
            bool b_is_driver = row2.get_is_driver ();

            if (a_is_driver != b_is_driver) {
                return a_is_driver ? - 1 : 1;
            }

            // Ensures OS updates are sorted to the top amongst up-to-date packages
            if (a_is_os || b_is_os) {
                return a_is_os ? -1 : 1;
            }

            return row1.get_name_label ().collate (row2.get_name_label ()); /* Else sort in name order */
        }

        [CCode (instance_pos = -1)]
        private void row_update_header (AppRowInterface row, AppRowInterface? before) {
            bool update_available = row.get_update_available ();
            bool is_driver = row.get_is_driver ();

            if (update_available) {
                if (before != null && update_available == before.get_update_available ()) {
                    row.set_header (null);
                    return;
                }

                uint update_numbers = 0U;
                uint nag_numbers = 0U;
                uint64 update_real_size = 0ULL;
                bool using_flatpak = false;
                foreach (var package in get_packages ()) {
                    if (package.update_available || package.is_updating) {
                        if (package.should_nag_update) {
                            nag_numbers++;
                        }

                        if (!using_flatpak && package.is_flatpak) {
                            using_flatpak = true;
                        }

                        update_numbers++;
                        update_real_size += package.change_information.size;
                    }
                }

                var header = new Widgets.UpdateHeaderRow.updatable (update_numbers, update_real_size, using_flatpak);

                // Unfortunately the update all button needs to be recreated everytime the header needs to be updated
                var update_all_button = new Gtk.Button.with_label (_("Update All"));
                if (update_numbers == nag_numbers || updating_all_apps) {
                    update_all_button.sensitive = false;
                }

                update_all_button.valign = Gtk.Align.CENTER;
                update_all_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                update_all_button.clicked.connect (on_update_all);
                action_button_group.add_widget (update_all_button);

                header.add (update_all_button);

                header.show_all ();
                row.set_header (header);
            } else if (is_driver) {
                if (before != null && is_driver == before.get_is_driver ()) {
                    row.set_header (null);
                    return;
                }

                var header = new Widgets.UpdateHeaderRow.drivers ();
                header.show_all ();
                row.set_header (header);
            } else {
                if (before != null && is_driver == before.get_is_driver () && update_available == before.get_update_available ()) {
                    row.set_header (null);
                    return;
                }

                var header = new Widgets.UpdateHeaderRow.up_to_date ();
                header.show_all ();
                row.set_header (header);
            }
        }

        private void on_update_all () {
            perform_all_updates.begin ();
        }

        private async void perform_all_updates () {
            if (updating_all_apps) {
                return;
            }

            updating_all_apps = true;

            foreach (var row in list_box.get_children ()) {
                if (row is Widgets.PackageRow) {
                    ((Widgets.PackageRow) row).set_action_sensitive (false);
                }
            };

            foreach (var package in get_packages ()) {
                if (package.update_available && !package.should_nag_update) {
                    try {
                        yield package.update (false);
                    } catch (Error e) {
                        // If one package update was cancelled, drop out of the loop of updating the rest
                        if (e is GLib.IOError.CANCELLED) {
                            break;
                        } else {
                            new UpgradeFailDialog (package, e).present ();
                            break;
                        }
                    }
                }
            }

            unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();
            yield client.refresh_updates ();

            updating_all_apps = false;
        }
    }
}
