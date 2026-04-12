pragma Singleton
import QtQuick 2.15

/**
 * WiFi Modul Stílus Beállítások
 * ==============================
 *
 * Itt tudod testreszabni a modul kinézetét.
 * Minden szín hexadecimális formátumban van megadva: #RRGGBB
 *
 * Példa színek:
 *   Fehér: #ffffff
 *   Fekete: #000000
 *   Piros: #ff0000
 *   Zöld: #00ff00
 *   Kék: #0000ff
 */

QtObject {
    // =========================================
    // HÁTTÉR SZÍNEK
    // =========================================

    // Fő háttérszín (az egész modul háttere)
    readonly property color backgroundColor: "#404040"

    // Lista háttérszín (ahol a WiFi hálózatok vannak)
    readonly property color listBackgroundColor: "#2B2B2B"

    // Lista fejléc háttérszín ("Elérhető hálózatok" sor)
    readonly property color listHeaderColor: "#3d7839"

    // Elem hover háttérszín (amikor az egér fölötte van)
    readonly property color itemHoverColor: "#2d3238"

    // Kiválasztott elem háttérszín
    readonly property color itemSelectedColor: "#3d7839"

    // =========================================
    // SZÖVEG SZÍNEK
    // =========================================

    // Fő szöveg szín (címek, hálózat nevek)
    readonly property color textColor: "#ffffff"

    // Másodlagos szöveg szín (leírások, információk)
    readonly property color textSecondaryColor: "#b2b2b2"

    // Halványított szöveg szín (tippek, kihagyható info)
    readonly property color textMutedColor: "#707070"

    // Letiltott szöveg szín
    readonly property color textDisabledColor: "#606060"

    // =========================================
    // GOMB SZÍNEK
    // =========================================

   // Fő gomb háttérszín (Csatlakozás gomb)
    readonly property color buttonPrimaryColor: "#3d7839"

    // Fő gomb hover szín
    readonly property color buttonPrimaryHoverColor: "#3d7839"

    // Másodlagos gomb háttérszín (Frissítés gomb)
    readonly property color buttonSecondaryColor: "#3d4248"

    // Másodlagos gomb hover szín
    readonly property color buttonSecondaryHoverColor: "#4a5058"

    // Letiltott gomb háttérszín
    readonly property color buttonDisabledColor: "#3d4248"

    // =========================================
    // INPUT MEZŐ SZÍNEK
    // =========================================

    // Input mező háttérszín
    readonly property color inputBackgroundColor: "#2B2B2B"

    // Input mező letiltott háttérszín
    readonly property color inputDisabledColor: "#2B2B2B"

    // Input mező placeholder szöveg szín
    readonly property color inputPlaceholderColor: "#FFFFFF"

    // Input mező keret szín
    readonly property color inputBorderColor: "#3d4248"

    // Input mező fókuszált keret szín
    readonly property color inputFocusBorderColor: "#3d7839"

    // =========================================
    // ÁLLAPOT SZÍNEK
    // =========================================

    // Sikeres állapot szín (csatlakozva)
    readonly property color successColor: "#2e7d32"

    // Sikeres pipa szín
    readonly property color successCheckColor: "#4CAF50"

    // Folyamatban állapot szín (csatlakozás...)
    readonly property color progressColor: "#37474f"

    // Toggle bekapcsolt szín
    readonly property color toggleOnColor: "#4CAF50"

    // Toggle kikapcsolt szín
    readonly property color toggleOffColor: "#555555"

    // =========================================
    // KERET ÉS VONAL SZÍNEK
    // =========================================

    // Lista keret szín
    readonly property color borderColor: "#3d4248"

    // Elválasztó vonal szín (lista elemek között)
    readonly property color separatorColor: "#3d4248"

    // =========================================
    // MÉRETEK
    // =========================================

    // Címsor betűméret
    readonly property int fontSizeTitle: 24

    // Alcím betűméret
    readonly property int fontSizeSubtitle: 12

    // Normál szöveg betűméret
    readonly property int fontSizeNormal: 14

    // Kis szöveg betűméret
    readonly property int fontSizeSmall: 12

    // Apró szöveg betűméret
    readonly property int fontSizeTiny: 11

    // Lista elem magasság
    readonly property int listItemHeight: 48

    // Gomb magasság
    readonly property int buttonHeight: 48

    // Input mező magasság
    readonly property int inputHeight: 44

    // Kerekítés sugara
    readonly property int borderRadius: 6

    // Nagy kerekítés sugara (lista)
    readonly property int borderRadiusLarge: 8

    // Belső margó
    readonly property int spacing: 16

    // Külső margó
    readonly property int margin: 20
}