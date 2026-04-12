find_package(Qt6 REQUIRED COMPONENTS DBus Widgets Quick QuickWidgets Network)

calamares_add_plugin(wifi
    TYPE viewmodule
    EXPORT_MACRO PLUGINDLLEXPORT_PRO
    SOURCES
        WifiViewStep.cpp
        NetworkManager.cpp
    LINK_LIBRARIES
        Qt6::DBus
        Qt6::Widgets
        Qt6::Quick
        Qt6::QuickWidgets
        Qt6::Network
)

install(
    FILES module.desc
    DESTINATION lib/calamares/modules/wifi
)

# Install all UI files (QML, qmldir, etc.)
install(
    FILES
        ui/wifi.qml
        ui/Style.qml
        ui/Translations.qml
        ui/qmldir
    DESTINATION lib/calamares/modules/wifi/ui
)
