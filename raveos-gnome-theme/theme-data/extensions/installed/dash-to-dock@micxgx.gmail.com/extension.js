// -*- mode: js; js-indent-level: 4; indent-tabs-mode: nil -*-

import {DockManager} from './docking.js';
import {Extension} from './dependencies/shell/extensions/extension.js';

// We export this so it can be accessed by other extensions
export let dockManager;

export default class DashToDockExtension extends Extension.Extension {
    enable() {
        DockManager._singleton = null;
        dockManager = new DockManager(this);
    }

    disable() {
        dockManager?.destroy();
        dockManager = null;
    }
}
