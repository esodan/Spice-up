/*
* Copyright (c) 2016 Felipe Escoto (https://github.com/Philip-Scott/Spice-up)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Felipe Escoto <felescoto95@hotmail.com>
*/

public class Spice.ColorPicker : ColorButton {
    public static Regex color_regex;
    public signal void color_picked (string color);

    public bool gradient {
        get {
            return gradient_revealer.reveal_child;
        }

        set {
            gradient_revealer.reveal_child = value;
            gradient_revealer.visible = value;
            gradient_revealer.no_show_all = !value;

            color_selector = value ? 3 : 0;
        }
    }

    public new string color {
        get {
            return _color;
        } set {
            ((ColorButton) this).color = value;
            preview.color = value;

            if (gradient) {
                parse_gradient (value);
            }
        }
    }

    // 0 == main, N = Gradient Color
    protected int color_selector = 0;
    private ulong color_chooser_signal;

    private Gtk.Stack colors_grid_stack;

    private Gtk.Popover popover;
    private Gtk.Grid colors_grid;
    private Gtk.Revealer gradient_revealer;
    private Gtk.ToggleButton custom_button;
    private Gtk.ColorChooserWidget color_chooser;

    protected ColorButton preview;
    protected ColorButton color1;
    protected ColorButton color2;

    private Gtk.ComboBoxText gradient_type;

    public ColorPicker (bool use_alpha = true) {
        Object (color: "white");

        color_chooser.use_alpha = use_alpha;
    }

    static construct {
        try {
            color_regex = new Regex ("""(#.{3,6} )|rgba?\([0-9]{1,},[0-9]{1,},[0-9]{1,}(\)|,(0|1).?[0-9]{0,}\))""", 0);
        } catch (Error e) {
            error ("Regex failed: %s", e.message);
        }
    }

    construct {
        colors_grid_stack = new Gtk.Stack ();
        colors_grid_stack.homogeneous = false;

        colors_grid = new Gtk.Grid ();
        colors_grid.margin = 6;
        colors_grid.get_style_context ().add_class ("card");

        var main_grid = new Gtk.Grid ();
        main_grid.margin = 6;

        generate_colors ();

        custom_button = new Gtk.ToggleButton.with_label (_("Custom Color"));
        custom_button.margin = 3;
        custom_button.toggled.connect (() => {
            if (custom_button.active) {
                colors_grid_stack.set_visible_child_name ("custom");
            } else {
                colors_grid_stack.set_visible_child_name ("palete");
            }
        });

        main_grid.attach (custom_button, 0, 8, 4, 1);

        gradient_revealer = new Gtk.Revealer ();

        var color1_label = new Gtk.Label (_("Color 1:"));
        var color2_label = new Gtk.Label (_("Color 2:"));

        color1_label.get_style_context ().add_class ("h4");
        color2_label.get_style_context ().add_class ("h4");

        color1_label.halign = Gtk.Align.END;
        color2_label.halign = Gtk.Align.END;

        color1_label.margin_right = 6;
        color2_label.margin_right = 6;

        color1 = new ColorButton ("red");
        color2 = new ColorButton ("orange");

        color1.margin_right = 6;
        color2.margin_right = 6;

        var gradient_grid = new Gtk.Grid ();
        gradient_grid.row_spacing = 6;
        gradient_grid.margin_left = 6;

        preview = new ColorButton ("");
        preview.get_style_context ().add_class ("flat");
        preview.set_size_request (100,120);

        var preview_box = new Gtk.Grid ();
        preview_box.margin = 6;
        preview_box.get_style_context ().add_class ("card");
        preview_box.add (preview);

        gradient_type = new Gtk.ComboBoxText ();
        gradient_type.margin = 3;
        gradient_type.vexpand = true;
        gradient_type.valign = Gtk.Align.END;

        gradient_type.append ("to bottom", _("Vertical"));
        gradient_type.append ("to right", _("Horizontal"));
        //gradient_type.add_entry ("radial", "Radial"); TODO: Gtk doesn't support radial gradients just yet
        gradient_type.active = 0;

        gradient_type.changed.connect (() => {
            this.color = make_gradient ();
            color_picked (this.color);
        });

        gradient_grid.attach (preview_box,   1, 1, 2, 3);
        gradient_grid.attach (color1_label,  0, 4, 2, 1);
        gradient_grid.attach (color1,        2, 4, 2, 1);
        gradient_grid.attach (color2_label,  0, 5, 2, 1);
        gradient_grid.attach (color2,        2, 5, 1, 1);
        gradient_grid.attach (gradient_type, 0, 6, 3, 1);

        gradient_revealer.add (gradient_grid);

        main_grid.attach (gradient_revealer, 4, 0, 1, 9);

        color_chooser = new Gtk.ColorChooserWidget ();
        color_chooser.show_editor = true;
        color_chooser.margin = 6;

        color_chooser_signal = color_chooser.notify["rgba"].connect (() => {
            set_color_smart (color_chooser.rgba.to_string (), false);
        });

        color1.clicked.connect (() => {
            color_selector = 1;
            set_color_chooser_color (color1.color);
        });

        color2.clicked.connect (() => {
            color_selector = 2;
            set_color_chooser_color (color2.color);
        });

        preview.clicked.connect (() => {
            color_selector = 3;
            set_color_chooser_color (preview.color);
        });

        color1.grab_focus ();

        main_grid.attach (colors_grid_stack, 0, 0, 4, 8);

        popover = new Gtk.Popover (this);
        popover.position = Gtk.PositionType.BOTTOM;
        popover.add (main_grid);

        colors_grid_stack.add_named (colors_grid, "palete");
        colors_grid_stack.add_named (color_chooser, "custom");

        this.clicked.connect (() => {
            colors_grid_stack.set_visible_child_name ("palete");
            custom_button.active = false;
            popover.show_all ();
        });

        gradient = false;
    }

    private void parse_gradient (string color) {
        if (color.contains ("gradient")) {
            MatchInfo mi;
            string colors[2] = {"", ""};

            if (color_regex.match (color, 0 , out mi)) {
                int count = 0, pos_start = 0, pos_end = 0;

                try {
                    do {
                        mi.fetch_pos (0, out pos_start, out pos_end);
                        string found_color = mi.fetch (0);
                        if (pos_start == pos_end) {
                            break;
                        }

                        colors[count++] = found_color;
                    } while (mi.next () || count < 2);
                } catch (Error e) {
                    warning ("Could not find gradient parts: %s", e.message);
                    return;
                }
            }

            color1.color = colors[0].strip ();
            color2.color = colors[1].strip ();

            if (color.contains ("to bottom")) {
                gradient_type.set_active_id ("to bottom");
            } else if (color.contains ("to right")) {
                gradient_type.set_active_id ("to right");
            }
        } else {
            color1.color = color;
            color2.color = color;
        }
    }

    public string make_gradient () {
        return "linear-gradient(%s, %s 0%, %s 100%)".printf (gradient_type.active_id, color1.color, color2.color);
    }

    public void generate_colors () {
        // red
        attach_color ("#ff8c82", 0, 0);
        attach_color ("#ed5353", 0, 1);
        attach_color ("#c6262e", 0, 2);
        attach_color ("#a10705", 0, 3);
        attach_color ("#7a0000", 0, 4);

        // orange
        attach_color ("#ffc27d", 1, 0);
        attach_color ("#ffa154", 1, 1);
        attach_color ("#f37329", 1, 2);
        attach_color ("#cc3b02", 1, 3);
        attach_color ("#a62100", 1, 4);

        // yellow
        attach_color ("#fff394", 2, 0);
        attach_color ("#ffe16b", 2, 1);
        attach_color ("#f9c440", 2, 2);
        attach_color ("#d48e15", 2, 3);
        attach_color ("#ad5f00", 2, 4);

        // green
        attach_color ("#d1ff82", 0, 5);
        attach_color ("#9bdb4d", 0, 6);
        attach_color ("#68b723", 0, 7);
        attach_color ("#3a9104", 0, 8);
        attach_color ("#206b00", 0, 9);

        // blue
        attach_color ("#8cd5ff", 1, 5);
        attach_color ("#64baff", 1, 6);
        attach_color ("#3689e6", 1, 7);
        attach_color ("#0d52bf", 1, 8);
        attach_color ("#002e99", 1, 9);

        // purple
        attach_color ("#e29ffc", 2, 5);
        attach_color ("#ad65d6", 2, 6);
        attach_color ("#7a36b1", 2, 7);
        attach_color ("#4c158a", 2, 8);
        attach_color ("#260063", 2, 9);

        // grayscale
        attach_color ("#dbe0f3", 3, 0);
        attach_color ("#c0c6de", 3, 1);
        attach_color ("#919caf", 3, 2);
        attach_color ("#68758e", 3, 3);
        attach_color ("#485a6c", 3, 4);

        attach_color ("#ffffff", 3, 5);
        attach_color ("#cbcbcb", 3, 6);
        attach_color ("#89898b", 3, 7);
        attach_color ("#505050", 3, 8);
        attach_color ("#000000", 3, 9);
    }

    private void attach_color (string color, int x, int y) {
        var color_button = new ColorButton (color);
        color_button.set_size_request (48,24);
        color_button.get_style_context ().add_class ("flat");
        color_button.can_focus = false;
        color_button.margin_right = 0;

        colors_grid.attach (color_button, x, y, 1, 1);

        color_button.clicked.connect (() => {
            set_color_smart (color, true);
        });
    }

    protected void set_color_smart (string color, bool from_button = false) {
        switch (this.color_selector) {
            case 0: // Single color
                this.color = color;
                break;

            case 1: // Color 1
                color1.color = color;
                this.color = make_gradient ();
                break;

            case 2: // Color 2
                color2.color = color;
                this.color = make_gradient ();
                break;

            case 3: // Both colors
                color1.color = color;
                color2.color = color;
                this.color = color;
                break;
        }

        if (from_button) {
            set_color_chooser_color (color);
        }

        color_picked (this.color);
    }

    private void set_color_chooser_color (string color) {
        SignalHandler.block (color_chooser, color_chooser_signal);

        Gdk.RGBA rgba = Gdk.RGBA ();
        rgba.parse (color);
        color_chooser.rgba = rgba;

        SignalHandler.unblock (color_chooser, color_chooser_signal);
    }

    protected class ColorButton : Gtk.Button {
        private Gtk.EventBox surface;

        public string _color = "none";
        public string color {
            get {
                return _color;
            } set {
                if (value != "") {
                    _color = value;
                    style ();
                }
            }
        }

        public ColorButton (string color) {
            Object (color: color);
        }

        construct {
            surface = new Gtk.EventBox ();
            surface.set_size_request (24, 24);
            surface.get_style_context ().add_class ("colored");
            get_style_context ().add_class ("color-button");
            Utils.set_style (this, STYLE_CSS);

            var background = new Gtk.EventBox ();
            background.get_style_context ().add_class ("checkered");
            Utils.set_style (background, CHECKERED_CSS);

            can_focus = false;
            add (background);
            background.add (surface);
        }

        public new void style () {
            Utils.set_style (surface, SURFACE_STYLE_CSS.printf (_color));
        }

        private const string STYLE_CSS = """
            .color-button.flat {
                border: none;
                padding: 0;
            }
        """;

        private const string CHECKERED_CSS = """
            .checkered {
                background-image: url('resource:///com/github/philip-scott/spice-up/patterns/ps-neutral.png');
            }
        """;

        private const string SURFACE_STYLE_CSS = """
            .colored {
                background: %s;
            }

            .color-button:active .colored {
                opacity: 0.9;
            }
        """;
    }
}
