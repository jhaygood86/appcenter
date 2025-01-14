/*-
 * Copyright 2016 elementary, Inc. (https://elementary.io)
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
 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
 */

/** Interface implemented by PackageRow and used to
  * determine sort order **/
public interface AppCenter.AppRowInterface : Gtk.ListBoxRow {
    public abstract bool get_update_available ();
    public abstract bool get_is_os_updates ();
    public abstract bool get_is_driver ();
    public abstract bool get_is_updating ();
    public abstract string get_name_label ();
    public abstract AppCenterCore.Package? get_package ();
}
