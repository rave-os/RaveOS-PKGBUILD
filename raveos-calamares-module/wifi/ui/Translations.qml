pragma Singleton
import QtQuick 2.15

/**
 * WiFi Modul Fordítások
 * ======================
 *
 * Támogatott nyelvek:
 *   - hu_HU: Magyar
 *   - en_US, en_GB, stb.: Angol (alapértelmezett)
 *
 * Új nyelv hozzáadása:
 *   1. Adj hozzá egy új "else if" blokkot a setLanguage függvényben
 *   2. Másold be az összes szöveget és fordítsd le
 *
 * Használat QML-ben:
 *   Text { text: Translations.title }
 */

QtObject {
    id: root

    // Aktuális nyelv kód (pl. "hu_HU", "en_US")
    property string currentLanguage: "en_US"

    // =========================================
    // CÍMEK ÉS FEJLÉCEK
    // =========================================

    // Sidebar név (bal oldali menüben)
    property string sidebarName: "Hálozat"

    // Modul fő címe
    property string title: "Wi-Fi Network"

    // Alcím / leírás
    property string subtitle: "Select a network from the list, or enter a hidden network name manually."

    // Lista fejléc
    property string availableNetworks: "Available networks"

    // =========================================
    // GOMBOK
    // =========================================

    // Frissítés gomb
    property string refresh: "Refresh"

    // Csatlakozás gomb
    property string connect: "Connect"

    // =========================================
    // INPUT MEZŐK
    // =========================================

    // SSID mező placeholder
    property string ssidPlaceholder: "Network name (SSID)"

    // Jelszó mező placeholder
    property string passwordPlaceholder: "Password"

    // =========================================
    // ÁLLAPOT ÜZENETEK
    // =========================================

    // Sikeres csatlakozás
    property string connected: "Successfully connected!"

    // Csatlakozás folyamatban
    property string connecting: "Connecting..."

    // Nincs hálózat
    property string noNetworks: "No networks found.\nClick Refresh to scan."

    // =========================================
    // TOGGLE ÉS OPCIÓK
    // =========================================

    // Rejtett hálózat toggle
    property string hiddenNetwork: "Hidden network"

    // =========================================
    // INFORMÁCIÓS SZÖVEGEK
    // =========================================

    // Sikeres csatlakozás után
    property string clickNextToContinue: "Click Next to continue."

    // Ha van vezetékes kapcsolat
    property string canSkipWithEthernet: "If you have a wired connection, you can skip this step."

    // =========================================
    // NYELV BEÁLLÍTÁS FÜGGVÉNY
    // =========================================

    /**
     * Nyelv beállítása a locale kód alapján
     * @param locale - Nyelv kód (pl. "hu_HU", "en_US")
     */
    function setLanguage(locale) {
        currentLanguage = locale

        // ==================
        // MAGYAR
        // ==================
        if (locale.startsWith("hu")) {
            sidebarName = "Hálozat"
            title = "Wi-Fi hálózat"
            subtitle = "Válassz egy hálózatot a listából, vagy add meg kézzel a rejtett hálózat nevét."
            availableNetworks = "Elérhető hálózatok"
            refresh = "Frissítés"
            connect = "Csatlakozás"
            ssidPlaceholder = "Hálózat neve (SSID)"
            passwordPlaceholder = "Jelszó"
            connected = "Sikeresen csatlakozva!"
            connecting = "Csatlakozás..."
            noNetworks = "Nem található hálózat.\nKattints a Frissítés gombra."
            hiddenNetwork = "Rejtett hálózat"
            clickNextToContinue = "Kattints a Tovább gombra a folytatáshoz."
            canSkipWithEthernet = "Ha van vezetékes kapcsolatod, kihagyhatod ezt a lépést."
        }
        // ==================
        // ANGOL (alapértelmezett)
        // ==================
        else {
            sidebarName = "Network"
            title = "Wi-Fi Network"
            subtitle = "Select a network from the list, or enter a hidden network name manually."
            availableNetworks = "Available networks"
            refresh = "Refresh"
            connect = "Connect"
            ssidPlaceholder = "Network name (SSID)"
            passwordPlaceholder = "Password"
            connected = "Successfully connected!"
            connecting = "Connecting..."
            noNetworks = "No networks found.\nClick Refresh to scan."
            hiddenNetwork = "Hidden network"
            clickNextToContinue = "Click Next to continue."
            canSkipWithEthernet = "If you have a wired connection, you can skip this step."
        }

        // ==================
        // TOVÁBBI NYELVEK IDE
        // ==================
        // Példa német nyelv hozzáadása:
        //
        // else if (locale.startsWith("de")) {
        //     title = "WLAN-Netzwerk"
        //     subtitle = "Wählen Sie ein Netzwerk aus der Liste..."
        //     // ... stb.
        // }
    }
}
