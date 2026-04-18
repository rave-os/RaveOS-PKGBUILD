#!/bin/bash

if [[ -z "${RAVEOS_GREETED:-}" && -z "${VSCODE_PID:-}" && "${TERM}" != "dumb" ]]; then
    export RAVEOS_GREETED=1
    
    if command -v fastfetch >/dev/null 2>&1; then
        if [[ "${TERM}" == "xterm-kitty" ]]; then
            fastfetch --config "${HOME}/.config/fastfetch/config-kitty.jsonc"
        else
            fastfetch --config "${HOME}/.config/fastfetch/config.jsonc"
        fi
    fi
fi
