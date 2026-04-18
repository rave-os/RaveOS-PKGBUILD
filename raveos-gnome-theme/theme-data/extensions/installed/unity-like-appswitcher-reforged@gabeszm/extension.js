import Atk from "gi://Atk";
import Clutter from "gi://Clutter";
import Meta from "gi://Meta";
import St from "gi://St";

import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as AltTab from 'resource:///org/gnome/shell/ui/altTab.js';
import * as SwitcherPopup from 'resource:///org/gnome/shell/ui/switcherPopup.js';

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

import * as Utils from './utils.js';


const baseIconSizes = [96, 64, 48, 32, 22];


let injections = {};
let extensionInstance = null;

function getWindows(workspace) {
	let windows = global.display.get_tab_list(Meta.TabList.NORMAL_ALL, workspace);
	return windows.map(w => {
		return w.is_attached_dialog() ? w.get_transient_for() : w;
	}).filter((w, i, a) => w && !w.skip_taskbar && a.indexOf(w) === i);
}

function _finish(timestamp) {
	this._currentWindow = this._currentWindow < 0 ? 0 : this._currentWindow;
	return injections._finish.call(this, timestamp);
}

function _initialSelection(backward, binding) {
	if (backward || binding != 'switch-applications'
		|| this._items.length == 0 || this._items[0].cachedWindows.length < 2) {
		injections._initialSelection.call(this, backward, binding);
		return;
	}

	let ws = global.workspace_manager.get_active_workspace();
	let wt = Shell.WindowTracker.get_default();
	let tab_list = global.display.get_tab_list(Meta.TabList.NORMAL, ws);

	if (!tab_list || tab_list.length < 2) {
		injections._initialSelection.call(this, backward, binding);
		return;
	}

	let currentApp = wt.get_window_app(tab_list[0]);
	let secondApp = wt.get_window_app(tab_list[1]);

	if (currentApp == secondApp) {
		this._select(0, 1);
	} else {
		injections._initialSelection.call(this, backward, binding);
	}
}

function highlight2(index, justOutline) {
	if (this._items[this._highlighted]) {
		this._items[this._highlighted].remove_style_pseudo_class('outlined');
		this._items[this._highlighted].remove_style_pseudo_class('selected');
	}

	if (this._items[index]) {
		if (justOutline)
			this._items[index].add_style_pseudo_class('outlined');
		else
			this._items[index].add_style_pseudo_class('selected');
	}

	this._highlighted = index;

	// GNOME 45+ compatibility: use hadjustment instead of hscroll.adjustment
	let adjustment = this._scrollView.hadjustment || (this._scrollView.hscroll ? this._scrollView.hscroll.adjustment : null);
	if (adjustment) {
		this._scroll(index);
	}
}

function _scroll(index) {
	// GNOME 45+ compatibility: use hadjustment instead of hscroll.adjustment
	let adjustment = this._scrollView.hadjustment || (this._scrollView.hscroll ? this._scrollView.hscroll.adjustment : null);
	if (!adjustment) return;

	let { upper, page_size: pageSize } = adjustment;

	let n = this._items.length;
	let fakeSize = 2;

	this._scrollableRight = index !== n - 1;
	this._scrollableLeft = index !== 0;
	if (upper === pageSize)
		return;

	let item = this._items[index];
	if (!item) return;

	let sizeItem = (item.allocation.x2 - item.allocation.x1);
	let value = (upper - pageSize + sizeItem) * (index / n);
	let maxScrollingAmount = (upper - pageSize);
	let percentaje = (index - fakeSize) / (n - 1 - 2 * fakeSize);
	value = percentaje * maxScrollingAmount;

	if (index < fakeSize || percentaje <= 0) {
		this._scrollableLeft = false;
		value = 0;
	} else if (index >= n - fakeSize || percentaje >= 1) {
		this._scrollableRight = false;
		value = maxScrollingAmount;
	}

	adjustment.ease(value, {
		progress_mode: Clutter.AnimationMode.EASE_OUT_EXPO,
		duration: 250,
		onComplete: () => {
			this.queue_relayout();
		},
	});
}

function addColours(settings) {
	injections.WINDOW_PREVIEW_SIZE = AltTab.WINDOW_PREVIEW_SIZE;

	if (AltTab.AppSwitcherPopup) {
		injections._init = AltTab.AppSwitcherPopup.prototype._init;
		AltTab.AppSwitcherPopup.prototype._init = function (items, mask, action, timeout) {
			// Call original
			injections._init.call(this, items, mask, action, timeout);

			// Custom additions
			this._thumbnails = null;
			this._thumbnailTimeoutId = 0;
			this._currentWindow = -1;
			this.thumbnailsVisible = false;

			let apps = Shell.AppSystem.get_default().get_running();

			// Remove the original switcher list if it exists
			if (this._switcherList && typeof this._switcherList.destroy === 'function') {
				try {
					this._switcherList.destroy();
				} catch (e) {
					// Already destroyed or other error
				}
			}

			this._switcherList = new AppSwitcher(apps, this, settings);
			this._items = this._switcherList.icons;

			this.add_child(this._switcherList);
		};
	}

	injections.highlight2 = SwitcherPopup.SwitcherList.prototype.highlight;
	SwitcherPopup.SwitcherList.prototype.highlight = highlight2;

	injections._scroll = SwitcherPopup.SwitcherList.prototype._scroll;
	SwitcherPopup.SwitcherList.prototype._scroll = _scroll;
}

function removeColours() {
	if (AltTab.AppSwitcherPopup && injections._init) {
		AltTab.AppSwitcherPopup.prototype._init = injections._init;
	}

	if (injections.highlight2) {
		SwitcherPopup.SwitcherList.prototype.highlight = injections.highlight2;
		injections.highlight2 = undefined;
	}

	if (injections._scroll) {
		SwitcherPopup.SwitcherList.prototype._scroll = injections._scroll;
		injections._scroll = undefined;
	}
}

function setInitialSelection() {
	if (!injections._finish && AltTab.AppSwitcherPopup) {
		injections._finish = AltTab.AppSwitcherPopup.prototype._finish;
		AltTab.AppSwitcherPopup.prototype._finish = _finish;
	}

	if (!injections._initialSelection && AltTab.AppSwitcherPopup) {
		injections._initialSelection = AltTab.AppSwitcherPopup.prototype._initialSelection;
		AltTab.AppSwitcherPopup.prototype._initialSelection = _initialSelection;
	}
}

function resetInitialSelection() {
	if (injections._finish && AltTab.AppSwitcherPopup) {
		AltTab.AppSwitcherPopup.prototype._finish = injections._finish;
		injections._finish = undefined;
	}

	if (injections._initialSelection && AltTab.AppSwitcherPopup) {
		AltTab.AppSwitcherPopup.prototype._initialSelection = injections._initialSelection;
		injections._initialSelection = undefined;
	}
}

class MyExtension {
	constructor(settings) {
		this._settings = settings;
		this._connectSettings();
		this._firstChangeWindowChanged();
		this._updateHoverSettings();
	}

	_connectSettings() {
		this._settingsHandlerFirstSwitch = this._settings.connect(
			'changed::first-change-window',
			this._firstChangeWindowChanged.bind(this)
		);
		
		this._settingsHandlers = [];
		[
			'hover-shade-level', 'hover-border-width', 'hover-glow-size', 
			'hover-opacity', 'icon-spacing', 
			'container-padding', 'background-color', 'border-size', 'border-color',
			'background-border-radius', 'icon-border-radius'
		].forEach(key => {
			this._settingsHandlers.push(
				this._settings.connect(`changed::${key}`, this._updateHoverSettings.bind(this))
			);
		});
	}

	_updateHoverSettings() {
		const keys = this._settings.list_keys();
		this.hoverShadeLevel = keys.includes('hover-shade-level') ? this._settings.get_double('hover-shade-level') : 0.2;
		this.hoverBorderWidth = keys.includes('hover-border-width') ? this._settings.get_int('hover-border-width') : 2;
		this.hoverGlowSize = keys.includes('hover-glow-size') ? this._settings.get_int('hover-glow-size') : 15;
		this.hoverOpacity = keys.includes('hover-opacity') ? this._settings.get_double('hover-opacity') : 0.8;
		
		this.iconSpacing = keys.includes('icon-spacing') ? this._settings.get_int('icon-spacing') : 10;
		this.containerPadding = keys.includes('container-padding') ? this._settings.get_int('container-padding') : 24;
		this.backgroundColor = keys.includes('background-color') ? this._settings.get_string('background-color') : 'rgba(0, 0, 0, 0.5)';
		this.borderSize = keys.includes('border-size') ? this._settings.get_int('border-size') : 2;
		this.borderColor = keys.includes('border-color') ? this._settings.get_string('border-color') : 'rgba(255, 255, 255, 0.2)';
		this.backgroundBorderRadius = keys.includes('background-border-radius') ? this._settings.get_int('background-border-radius') : 24;
		this.iconBorderRadius = keys.includes('icon-border-radius') ? this._settings.get_int('icon-border-radius') : 16;
	}

	_firstChangeWindowChanged() {
		this._firstChangeWindow = this._settings.get_boolean('first-change-window');
		if (this._firstChangeWindow) {
			setInitialSelection();
		} else {
			resetInitialSelection();
		}
	}

	destroy() {
		this._disconnectSettings();
		resetInitialSelection();
	}

	_disconnectSettings() {
		if (this._settingsHandlerFirstSwitch) {
			this._settings.disconnect(this._settingsHandlerFirstSwitch);
			this._settingsHandlerFirstSwitch = 0;
		}
		if (this._settingsHandlers) {
			this._settingsHandlers.forEach(h => this._settings.disconnect(h));
			this._settingsHandlers = [];
		}
	}
}

export default class UnityLikeAppSwitcherExtension extends Extension {
	enable() {
		this.initTranslations("unity-window-switcher");
		const settings = this.getSettings();
		extensionInstance = new MyExtension(settings);

		addColours(settings);
	}

	disable() {
		removeColours();

		if (extensionInstance) {
			extensionInstance.destroy();
			extensionInstance = null;
		}
	}
}

const AppSwitcher = GObject.registerClass(
	class AppSwitcher extends SwitcherPopup.SwitcherList {
		_init(apps, altTabPopup, extensionSettings) {
			super._init(true);

			this.icons = [];
			this._arrows = [];
			this._extensionSettings = extensionSettings;

			let windowTracker = Shell.WindowTracker.get_default();
			let settings = new Gio.Settings({ schema_id: 'org.gnome.shell.app-switcher' });

			let workspace = null;
			if (settings.get_boolean('current-workspace-only')) {
				let workspaceManager = global.workspace_manager;
				workspace = workspaceManager.get_active_workspace();
			}

			let allWindows = getWindows(workspace);

			for (let i = 0; i < apps.length; i++) {
				let appIcon = new AltTab.AppIcon(apps[i]);
				appIcon.cachedWindows = allWindows.filter(
					w => windowTracker.get_window_app(w) === appIcon.app);
				if (appIcon.cachedWindows.length > 0)
					this._addIcon(appIcon);
			}

			this._altTabPopup = altTabPopup;
			this._delayedHighlighted = -1;
			this._mouseTimeOutId = 0;

			// Apply container styles
			const keys = this._extensionSettings.list_keys();
			const padding = keys.includes('container-padding') ? this._extensionSettings.get_int('container-padding') : 24;
			const bgColor = keys.includes('background-color') ? this._extensionSettings.get_string('background-color') : 'rgba(0, 0, 0, 0.5)';
			const borderWidth = keys.includes('border-size') ? this._extensionSettings.get_int('border-size') : 2;
			const borderColor = keys.includes('border-color') ? this._extensionSettings.get_string('border-color') : 'rgba(255, 255, 255, 0.2)';
			const spacing = keys.includes('icon-spacing') ? this._extensionSettings.get_int('icon-spacing') : 10;
			const borderRadius = keys.includes('background-border-radius') ? this._extensionSettings.get_int('background-border-radius') : 24;
			this._iconBorderRadius = keys.includes('icon-border-radius') ? this._extensionSettings.get_int('icon-border-radius') : 16;

			this.set_style(`
				padding: ${padding}px;
				background-color: ${bgColor};
				border: ${borderWidth}px solid ${borderColor};
				border-radius: ${borderRadius}px;
			`);
			this._list.set_style(`spacing: ${spacing}px;`);

			this.connect('destroy', this._onDestroy.bind(this));
		}

		_onDestroy() {
			if (this._mouseTimeOutId !== 0)
				GLib.source_remove(this._mouseTimeOutId);

			this.icons.forEach(
				icon => icon.app.disconnectObject(this));
		}

		_setIconSize() {
			let j = 0;
			while (j < this._items.length && this._items[j].style_class !== 'item-box')
				j++;

			if (j >= this._items.length) return;

			let themeNode = this._items[j].get_theme_node();
			this._list.ensure_style();

			let iconPadding = themeNode.get_horizontal_padding();
			let iconBorder = themeNode.get_border_width(St.Side.LEFT) + themeNode.get_border_width(St.Side.RIGHT);
			let labelNaturalHeight = 0;
			if (this.icons[j].label) {
				[, labelNaturalHeight] = this.icons[j].label.get_preferred_height(-1);
			}
			let iconSpacing = labelNaturalHeight + iconPadding + iconBorder;
			
			const keys = this._extensionSettings.list_keys();
			const spacing = keys.includes('icon-spacing') ? this._extensionSettings.get_int('icon-spacing') : 10;
			let totalSpacing = spacing * (this._items.length - 1);

			let primary = Main.layoutManager.primaryMonitor;
			let parent = this.get_parent();
			let parentPadding = parent ? parent.get_theme_node().get_horizontal_padding() : 0;
			let availWidth = primary.width - parentPadding - this.get_theme_node().get_horizontal_padding();

			let scaleFactor = St.ThemeContext.get_for_stage(global.stage).scale_factor;
			let iconSizes = baseIconSizes.map(s => s * scaleFactor);
			let iconSize = baseIconSizes[0];

			if (this._items.length > 1) {
				for (let i = 0; i < baseIconSizes.length; i++) {
					iconSize = baseIconSizes[i];
					let height = iconSizes[i] + iconSpacing;
					let w = height * this._items.length + totalSpacing;
					if (w <= availWidth)
						break;
				}
			}

			this._iconSize = iconSize;

			for (let i = 0; i < this.icons.length; i++) {
				if (this.icons[i] && this.icons[i].icon == null) {
					this.icons[i].set_size(iconSize);
				}
			}
		}

		vfunc_get_preferred_height(forWidth) {
			if (!this._iconSize)
				this._setIconSize();

			return super.vfunc_get_preferred_height(forWidth);
		}

		vfunc_allocate(box) {
			super.vfunc_allocate(box);

			let contentBox = this.get_theme_node().get_content_box(box);
			let arrowHeight = Math.floor(this.get_theme_node().get_padding(St.Side.BOTTOM) / 3);
			let arrowWidth = arrowHeight * 2;

			let childBox = new Clutter.ActorBox();
			for (let i = 0; i < this._items.length; i++) {
				let itemBox = this._items[i].allocation;
				childBox.x1 = contentBox.x1 + Math.floor(itemBox.x1 + (itemBox.x2 - itemBox.x1 - arrowWidth) / 2);
				childBox.x2 = childBox.x1 + arrowWidth;
				childBox.y1 = contentBox.y1 + itemBox.y2 + arrowHeight;
				childBox.y2 = childBox.y1 + arrowHeight;
				if (this._arrows[i])
					this._arrows[i].allocate(childBox);
			}
		}

		_onItemMotion(item) {
			if (item === this._items[this._highlighted] ||
				item === this._items[this._delayedHighlighted])
				return Clutter.EVENT_PROPAGATE;

			const index = this._items.indexOf(item);

			if (this._mouseTimeOutId !== 0) {
				GLib.source_remove(this._mouseTimeOutId);
				this._delayedHighlighted = -1;
				this._mouseTimeOutId = 0;
			}

			if (this._altTabPopup && this._altTabPopup.thumbnailsVisible) {
				this._delayedHighlighted = index;
				this._mouseTimeOutId = GLib.timeout_add(
					GLib.PRIORITY_DEFAULT,
					AltTab.APP_ICON_HOVER_TIMEOUT,
					() => {
						this._enterItem(index);
						this._delayedHighlighted = -1;
						this._mouseTimeOutId = 0;
						return GLib.SOURCE_REMOVE;
					});
			} else {
				this._itemEntered(index);
			}

			return Clutter.EVENT_PROPAGATE;
		}

		_enterItem(index) {
			let [x, y] = global.get_pointer();
			let pickedActor = global.stage.get_actor_at_pos(Clutter.PickMode.ALL, x, y);
			if (this._items[index] && this._items[index].contains(pickedActor))
				this._itemEntered(index);
		}

		highlight(n, justOutline) {
			if (this.icons[this._highlighted]) {
				if (this._arrows[this._highlighted]) {
					if (this.icons[this._highlighted].cachedWindows.length === 1)
						this._arrows[this._highlighted].hide();
					else
						this._arrows[this._highlighted].remove_style_pseudo_class('highlighted');
				}
			}

			let previous = this._items[this._highlighted];
			if (previous && previous.originalStyle) {
				previous.set_style(previous.originalStyle);
			}

			let item = this._items[n];
			if (item && item.colorPalette && item.colorPalette.baseRgb) {
				let style = item.originalStyle || '';
				
				// Read directly from the settings object passed to AppSwitcher
				const keys = this._extensionSettings.list_keys();
				let shadeLevel = keys.includes('hover-shade-level') ? this._extensionSettings.get_double('hover-shade-level') : 0.2;
				let borderWidth = keys.includes('hover-border-width') ? this._extensionSettings.get_int('hover-border-width') : 2;
				let glowSize = keys.includes('hover-glow-size') ? this._extensionSettings.get_int('hover-glow-size') : 15;
				let opacity = keys.includes('hover-opacity') ? this._extensionSettings.get_double('hover-opacity') : 0.8;
				let iconBorderRadius = this._iconBorderRadius;
				
				let r = Math.round(Math.min(Math.max(item.colorPalette.baseRgb.r * (1 + shadeLevel), 0), 255));
				let g = Math.round(Math.min(Math.max(item.colorPalette.baseRgb.g * (1 + shadeLevel), 0), 255));
				let b = Math.round(Math.min(Math.max(item.colorPalette.baseRgb.b * (1 + shadeLevel), 0), 255));
				let hoverColor = `rgba(${r}, ${g}, ${b}, ${opacity})`;

				item.set_style(style + 
					' box-shadow: inset 0 0 ' + glowSize + 'px ' + hoverColor + ', 0 0 0 ' + borderWidth + 'px ' + hoverColor + ' !important; ' +
					' border: 3px solid transparent !important; ' +
					' border-radius: ' + iconBorderRadius + 'px !important;');
			}

			highlight2.call(this, n, justOutline);
			this._curApp = n;

			if (this._highlighted !== -1 && this.icons[this._highlighted] && this._arrows[this._highlighted]) {
				if (justOutline && this.icons[this._highlighted].cachedWindows.length === 1)
					this._arrows[this._highlighted].show();
				else
					this._arrows[this._highlighted].add_style_pseudo_class('highlighted');
			}
		}

		_addIcon(appIcon) {
			this.icons.push(appIcon);
			let item = this.addItem(appIcon, appIcon.label);

			if (appIcon.label) {
				appIcon.label.set_style('text-shadow: 0px 1px 3px rgba(0, 0, 0, 0.7); font-weight: bold;');
			}

			try {
				item.colorPalette = new Utils.DominantColorExtractor(appIcon.app)._getColorPalette();
			} catch (e) {
				item.colorPalette = null;
			}

			const iconBorderRadius = this._iconBorderRadius;

			if (item.colorPalette == null) {
				item.colorPalette = {
					original: '#000000', 
					lighter: '#666666',
					darker: '#000000',
					baseRgb: { r: 0, g: 0, b: 0 }
				}
			}
			let hex = item.colorPalette.original;
			let rgb = Utils.ColorUtils._hexToRgb(hex);
			// Force background-color and remove background-image (gradients) using !important
			item.originalStyle = 'background-color: rgba(' + rgb.r + ',' + rgb.g + ',' + rgb.b + ', 0.6) !important; background-image: none !important; border: 3px solid transparent; border-radius: ' + iconBorderRadius + 'px !important;';
			item.set_style(item.originalStyle);

			appIcon.app.connectObject('notify::state', app => {
				if (app.state !== Shell.AppState.RUNNING)
					this._removeIcon(app);
			}, this);

			let arrow = new St.DrawingArea({ style_class: 'switcher-arrow' });
			arrow.connect('repaint', () => SwitcherPopup.drawArrow(arrow, St.Side.BOTTOM));
			this.add_child(arrow);
			this._arrows.push(arrow);

			if (appIcon.cachedWindows.length === 1)
				arrow.hide();
			else
				item.add_accessible_state(Atk.StateType.EXPANDABLE);
		}

		_removeIcon(app) {
			let index = this.icons.findIndex(icon => {
				return icon.app === app;
			});
			if (index === -1)
				return;

			if (this._arrows[index]) {
				this._arrows[index].destroy();
				this._arrows.splice(index, 1);
			}

			this.icons.splice(index, 1);
			this.removeItem(index);
		}
	});
