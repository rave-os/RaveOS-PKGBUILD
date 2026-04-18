import Gdk from "gi://Gdk";
import GdkPixbuf from "gi://GdkPixbuf";
import Gio from "gi://Gio";
import Gtk from "gi://Gtk";
import St from "gi://St";
import GLib from "gi://GLib";

let iconCacheMap = new Map();
const MAX_CACHED_ITEMS = 1000;
const BATCH_SIZE_TO_DELETE = 50;
const DOMINANT_COLOR_ICON_SIZE = 64;

function debugLog(msg) {
	try {
		let f = Gio.File.new_for_path('/tmp/color_log.txt');
		let out = f.append_to(Gio.FileCreateFlags.NONE, null);
		out.write_all(new Date().toISOString() + " - " + msg + "\n", null);
		out.close(null);
	} catch (e) { }
}

function findFallbackIconPath(iconName) {
	if (!iconName) return null;
	if (GLib.file_test(iconName, GLib.FileTest.EXISTS)) return iconName;

	const sizes = ['128x128', '256x256', '512x512', '64x64', 'scalable', '48x48'];

	let currentTheme = 'Adwaita';
	try {
		const settings = new Gio.Settings({ schema_id: 'org.gnome.desktop.interface' });
		if (settings.get_string('icon-theme')) {
			currentTheme = settings.get_string('icon-theme');
		}
	} catch (e) {
		debugLog("Failed to get active icon theme setting: " + e);
	}

	// Tegyük a hicolort az első helyre, a jelenleg aktív témát a másodikra, aztán a többi népszerű.
	// A Set-tel kiszűrjük az esetleges ismétlődéseket.
	const themes = [...new Set(['hicolor', currentTheme, 'locolor', 'Yaru', 'Pop', 'Adwaita', 'MoreWaita', 'Papirus', 'Tela'])];
	const bases = [
		GLib.get_home_dir() + '/.local/share/icons',
		GLib.get_home_dir() + '/.local/share/flatpak/exports/share/icons',
		'/var/lib/flatpak/exports/share/icons',
		'/var/lib/snapd/desktop/icons',
		'/usr/share/icons',
		'/usr/local/share/icons'
	];
	const formats = ['.svg', '.png', '.xpm'];

	for (const base of bases) {
		for (const theme of themes) {
			for (const size of sizes) {
				for (const format of formats) {
					let path = `${base}/${theme}/${size}/apps/${iconName}${format}`;
					if (GLib.file_test(path, GLib.FileTest.EXISTS)) return path;
				}
			}
		}
	}

	// Check pixmaps
	for (const format of formats) {
		let path = `/usr/share/pixmaps/${iconName}${format}`;
		if (GLib.file_test(path, GLib.FileTest.EXISTS)) return path;
	}

	return null;
}

export class DominantColorExtractor {
	constructor(app) {
		this._app = app;
	}

	_getIconPixBuf() {
		debugLog("--- START Extracting for app: " + (this._app ? this._app.get_id() : "undefined") + " ---");
		if (!this._app) {
			debugLog("Error: _app is null or undefined");
			return null;
		}

		const gicon = this._app.get_icon();
		if (!gicon) {
			debugLog("Fail: get_icon() returned null");
			return null;
		}

		debugLog("Got gicon of type: " + gicon.constructor.name);

		// Try to load via Gio.FileIcon directly
		if (gicon instanceof Gio.FileIcon) {
			try {
				debugLog("gicon is Gio.FileIcon. Getting file path...");
				const path = gicon.get_file().get_path();
				debugLog("File path: " + path);
				if (path) {
					return GdkPixbuf.Pixbuf.new_from_file(path);
				}
			} catch (e) {
				debugLog("Exception in Gio.FileIcon lookup: " + e);
			}
		}

		// Try fallback manual lookup
		if (gicon instanceof Gio.ThemedIcon) {
			try {
				debugLog("Attempting manual fallback search for ThemedIcon...");
				const names = gicon.get_names();
				for (const name of names) {
					let path = findFallbackIconPath(name);
					if (path) {
						debugLog("Manual fallback found file: " + path);
						return GdkPixbuf.Pixbuf.new_from_file(path);
					}
				}
			} catch (e) {
				debugLog("Exception in manual fallback: " + e);
			}
		}

		// Try St.TextureCache as a last resort
		try {
			debugLog("Attempting St.TextureCache lookup...");
			let textureCache = St.TextureCache.get_default();
			let themeContext = St.ThemeContext.get_for_stage(global.stage);
			let iconSize = 64 * themeContext.scale_factor;
			
			let iconTexture = textureCache.load_gicon(null, gicon, iconSize);
			if (iconTexture) {
				debugLog("Found texture in cache, but cannot easily convert to Pixbuf in this context. Fallback to default.");
			}
		} catch (e) {
			debugLog("St.TextureCache lookup failed: " + e);
		}

		debugLog("--- FAIL: Exhausted all methods to get icon pixbuf ---");
		return null;
	}

	_getColorPalette() {
		debugLog("--- START _getColorPalette ---");
		const appId = this._app ? this._app.get_id() : null;
		debugLog("App ID: " + appId);

		if (appId && iconCacheMap.has(appId)) {
			debugLog("Returning cached color for: " + appId);
			return iconCacheMap.get(appId);
		}

		debugLog("Cache miss, calling _getIconPixBuf()");
		const pixBuf = this._getIconPixBuf();
		if (!pixBuf) {
			debugLog("FAIL: pixBuf is null, cannot extract color.");
			return null;
		}

		try {
			const width = pixBuf.get_width();
			const height = pixBuf.get_height();
			const rowstride = pixBuf.get_rowstride();
			const nChannels = pixBuf.get_n_channels();
			const hasAlpha = pixBuf.get_has_alpha();

			debugLog(`PixBuf info: ${width}x${height}, rowstride: ${rowstride}, channels: ${nChannels}, alpha: ${hasAlpha}`);

			const pixels = pixBuf.get_pixels();
			if (!pixels) {
				debugLog("FAIL: pixBuf.get_pixels() returned null or undefined");
				return null;
			}

			let total = 0, rTotal = 0, gTotal = 0, bTotal = 0;
			const step = Math.max(1, Math.floor(width / 32));
			debugLog("Calculated step for sampling: " + step);

			let sampledCount = 0;
			for (let y = 0; y < height; y += step) {
				for (let x = 0; x < width; x += step) {
					const offset = y * rowstride + x * nChannels;
					const r = pixels[offset];
					const g = pixels[offset + 1];
					const b = pixels[offset + 2];
					const a = hasAlpha ? pixels[offset + 3] : 255;

					if (a < 128) continue;

					const max = Math.max(r, g, b);
					const min = Math.min(r, g, b);
					const saturation = (max - min) / (max || 1);
					const relevance = a * (saturation * saturation + 0.1);

					rTotal += r * relevance;
					gTotal += g * relevance;
					bTotal += b * relevance;
					total += relevance;
					sampledCount++;
				}
			}

			debugLog(`Sampling complete. Sampled pixels: ${sampledCount}. Total accumulator: ${total}`);

			if (total === 0) {
				debugLog("FAIL: Valid pixel total is 0. Returning null.");
				return null;
			}

			let r = rTotal / total;
			let g = gTotal / total;
			let b = bTotal / total;
			debugLog(`Averaged RGB: Math.round(${r}), Math.round(${g}), Math.round(${b})`);

			let hsv = ColorUtils.RGBtoHSV(r, g, b);
			debugLog(`HSV before normalize: h:${hsv.h.toFixed(2)}, s:${hsv.s.toFixed(2)}, v:${hsv.v.toFixed(2)}`);

			if (hsv.s < 0.2) hsv.s = 0.35;
			hsv.v = Math.max(0.6, Math.min(hsv.v, 0.9));

			debugLog(`HSV after normalize: h:${hsv.h.toFixed(2)}, s:${hsv.s.toFixed(2)}, v:${hsv.v.toFixed(2)}`);

			const rgb = ColorUtils.HSVtoRGB(hsv.h, hsv.s, hsv.v);

			const backgroundColor = {
				lighter: ColorUtils.ColorLuminance(rgb.r, rgb.g, rgb.b, 0.5),
				original: ColorUtils.ColorLuminance(rgb.r, rgb.g, rgb.b, 0),
				darker: ColorUtils.ColorLuminance(rgb.r, rgb.g, rgb.b, -0.5),
				baseRgb: rgb
			};

			debugLog(`Generated Palette: original=${backgroundColor.original}, lighter=${backgroundColor.lighter}, darker=${backgroundColor.darker}`);

			if (iconCacheMap.size >= MAX_CACHED_ITEMS) {
				debugLog("Cache full, clearing batch.");
				const keys = Array.from(iconCacheMap.keys());
				for (let i = 0; i < BATCH_SIZE_TO_DELETE; i++) {
					iconCacheMap.delete(keys[i]);
				}
			}

			if (appId) {
				iconCacheMap.set(appId, backgroundColor);
				debugLog("Added to cache for appId: " + appId);
			}

			debugLog("--- SUCCESS: Color extraction finished ---");
			return backgroundColor;

		} catch (e) {
			debugLog("Exception during pixel processing: " + e);
			return null;
		}
	}
}

export class ColorUtils {
	static ColorLuminance(r, g, b, dlum) {
		let rgbString = '#';
		rgbString += ColorUtils._decimalToHex(Math.round(Math.min(Math.max(r * (1 + dlum), 0), 255)), 2);
		rgbString += ColorUtils._decimalToHex(Math.round(Math.min(Math.max(g * (1 + dlum), 0), 255)), 2);
		rgbString += ColorUtils._decimalToHex(Math.round(Math.min(Math.max(b * (1 + dlum), 0), 255)), 2);
		return rgbString;
	}

	static _decimalToHex(d, padding) {
		let hex = d.toString(16);
		while (hex.length < padding)
			hex = '0' + hex;
		return hex;
	}

	static _hexToRgb(h) {
		return {
			r: parseInt(h.substr(1, 2), 16),
			g: parseInt(h.substr(3, 2), 16),
			b: parseInt(h.substr(5, 2), 16)
		}
	}

	static HSVtoRGB(h, s, v) {
		if (arguments.length === 1) {
			s = h.s;
			v = h.v;
			h = h.h;
		}

		let r, g, b;
		let c = v * s;
		let h1 = h * 6;
		let x = c * (1 - Math.abs(h1 % 2 - 1));
		let m = v - c;

		if (h1 <= 1)
			r = c + m, g = x + m, b = m;
		else if (h1 <= 2)
			r = x + m, g = c + m, b = m;
		else if (h1 <= 3)
			r = m, g = c + m, b = x + m;
		else if (h1 <= 4)
			r = m, g = x + m, b = c + m;
		else if (h1 <= 5)
			r = x + m, g = m, b = c + m;
		else
			r = c + m, g = m, b = x + m;

		return {
			r: Math.round(r * 255),
			g: Math.round(g * 255),
			b: Math.round(b * 255)
		};
	}

	static RGBtoHSV(r, g, b) {
		if (arguments.length === 1) {
			r = r.r;
			g = r.g;
			b = r.b;
		}

		let h, s, v;
		let M = Math.max(r, g, b);
		let m = Math.min(r, g, b);
		let c = M - m;

		if (c == 0)
			h = 0;
		else if (M == r)
			h = ((g - b) / c) % 6;
		else if (M == g)
			h = (b - r) / c + 2;
		else
			h = (r - g) / c + 4;

		h = h / 6;
		v = M / 255;
		if (M !== 0)
			s = c / M;
		else
			s = 0;

		return {
			h: h,
			s: s,
			v: v
		};
	}
}
