import Adw from 'gi://Adw';
import GObject from "gi://GObject";
import Gio from "gi://Gio";
import Gtk from "gi://Gtk";
import Gdk from "gi://Gdk";

import { ExtensionPreferences, gettext as _ } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';


class PrefsWidget {	

	constructor(schema) {
		this._updating = false;
		this._buildable = new Gtk.Builder();
		this._buildable.add_from_file(
			Gio.File.new_for_uri(import.meta.url).get_parent().get_path() + '/settings.ui'
		);

		let prefsWidget = this._getWidget('prefs_widget');
		if (!prefsWidget) {
			console.error('UnityLikeAppSwitcher: Main widget not found');
		}

		this._settings = schema;
		this._bindBooleans();
		this._bindNumbers();
		this._bindStrings();

		let resetButton = this._getWidget('reset_button');
		if (resetButton) {
			resetButton.connect('clicked', () => {
				this._resetAll();
			});
		}

		this._settings.connect(
			'changed::first-change-window',
			this._firstChangeWindowChanged.bind(this)
		);
		this._firstChangeWindowChanged();
	}

	_resetAll() {
		this._updating = true;
		try {
			this._getNumbers().forEach(setting => {
				this._settings.reset(setting);
				// Trigger UI update manually for numbers since they use manual binding
				this._updateNumberWidget(setting);
			});
			
			this._getBooleans().forEach(setting => {
				this._settings.reset(setting);
			});

			this._getStrings().forEach(setting => {
				this._settings.reset(setting);
				this._updateStringWidget(setting);
			});

			Gio.Settings.sync();
		} finally {
			this._updating = false;
		}
	}

	_updateNumberWidget(setting) {
		if (this._updating) return;
		let widget = this._getWidget(setting);
		if (!widget || !widget.set_value) {
			return;
		}
		if (!this._settings.list_keys().includes(setting)) {
			// Fallback values if key is missing
			let defaultValues = {
				'hover-shade-level': 0.2,
				'hover-opacity': 0.8,
				'hover-border-width': 2,
				'hover-glow-size': 15,
				'icon-spacing': 10,
				'container-padding': 24,
				'border-size': 2,
				'background-border-radius': 24,
				'icon-border-radius': 16
			};
			widget.set_value(defaultValues[setting] || 0);
			return;
		}
		let isDouble = (setting === 'hover-shade-level' || setting === 'hover-opacity');
		if (isDouble) {
			widget.set_value(this._settings.get_double(setting));
		} else {
			widget.set_value(this._settings.get_int(setting));
		}
	}

	_updateStringWidget(setting) {
		if (this._updating) return;
		let widget = this._getWidget(setting);
		if (!widget) return;
		let colorStr = '';
		if (!this._settings.list_keys().includes(setting)) {
			let defaultValues = {
				'background-color': 'rgba(0, 0, 0, 0.5)',
				'border-color': 'rgba(255, 255, 255, 0.2)'
			};
			colorStr = defaultValues[setting] || '';
		} else {
			colorStr = this._settings.get_string(setting);
		}

		if (widget instanceof Gtk.ColorDialogButton) {
			let rgba = new Gdk.RGBA();
			if (rgba.parse(colorStr)) {
				this._updating = true;
				widget.set_rgba(rgba);
				this._updating = false;
			}
		} else if (widget.set_text) {
			this._updating = true;
			widget.set_text(colorStr);
			this._updating = false;
		}
	}

	_getWidget(name) {
		let wname = name.replace(/-/g, '_');
		return this._buildable.get_object(wname);
	}

	_getBooleans() {
		return [
			'first-change-window'
		];
	}

	_getNumbers() {
		return [
			'hover-shade-level',
			'hover-border-width',
			'hover-glow-size',
			'hover-opacity',
			'icon-spacing',
			'container-padding',
			'border-size',
			'background-border-radius',
			'icon-border-radius'
		];
	}

	_getStrings() {
		return [
			'background-color',
			'border-color'
		];
	}

	_bindBoolean(setting) {
		let widget = this._getWidget(setting);
		if (!widget) return;
		this._settings.bind(setting, widget, 'active', Gio.SettingsBindFlags.DEFAULT);
	}

	_bindBooleans() {
		this._getBooleans().forEach(this._bindBoolean, this);
	}

	_bindString(setting) {
		let widget = this._getWidget(setting);
		if (!widget) return;
		this._updateStringWidget(setting);

		if (widget instanceof Gtk.ColorDialogButton) {
			widget.connect('notify::rgba', (w) => {
				if (this._updating) return;
				if (!this._settings.list_keys().includes(setting)) return;
				let rgba = w.get_rgba();
				let val = rgba.to_string(); // CSS format
				let current = this._settings.get_string(setting);
				if (current !== val) {
					this._settings.set_string(setting, val);
				}
			});
		} else {
			widget.connect('changed', (w) => {
				if (this._updating) return;
				if (!this._settings.list_keys().includes(setting)) return;
				let val = w.get_text();
				let current = this._settings.get_string(setting);
				if (current !== val) {
					this._settings.set_string(setting, val);
				}
			});
		}

		this._settings.connect(`changed::${setting}`, () => {
			if (this._updating) return;
			this._updateStringWidget(setting);
		});
	}

	_bindStrings() {
		this._getStrings().forEach(this._bindString, this);
	}

	_bindNumber(setting) {
		let widget = this._getWidget(setting);
		if (!widget) return;
		let isDouble = (setting === 'hover-shade-level' || setting === 'hover-opacity');
		
		// Érték betöltése indításkor
		this._updateNumberWidget(setting);
		
		// Automatikus mentés változáskor
		widget.connect('notify::value', (w) => {
			if (this._updating) return;
			if (!this._settings.list_keys().includes(setting)) return;
			let val = w.get_value();
			if (isDouble) {
				// Only update if significantly different to avoid feedback loops
				let current = this._settings.get_double(setting);
				if (Math.abs(current - val) > 0.001) {
					this._settings.set_double(setting, val);
				}
			} else {
				let current = this._settings.get_int(setting);
				if (current !== Math.round(val)) {
					this._settings.set_int(setting, Math.round(val));
				}
			}
		});

		// Update widget if setting changes externally (e.g. reset)
		this._settings.connect(`changed::${setting}`, () => {
			if (this._updating) return;
			this._updateNumberWidget(setting);
		});
	}

	_bindNumbers() {
		this._getNumbers().forEach(this._bindNumber, this);
	}

	_firstChangeWindowChanged() {
		this._settings.get_boolean('first-change-window');
	}
}

export default class UnityLikeAppSwitcherPreferences extends ExtensionPreferences {
	fillPreferencesWindow (window) {
		this.initTranslations("unity-window-switcher");
		window._settings = this.getSettings();
		const widget = new PrefsWidget(window._settings);
		window.add(widget._getWidget('prefs_widget'));
	}
}
