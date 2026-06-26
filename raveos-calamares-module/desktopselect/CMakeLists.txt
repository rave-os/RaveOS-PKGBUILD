find_package(Qt6 REQUIRED COMPONENTS Widgets Quick QuickWidgets)

calamares_add_plugin(desktopselect
    TYPE viewmodule
    EXPORT_MACRO PLUGINDLLEXPORT_PRO
    SOURCES
        DesktopSelectViewStep.cpp
        DesktopBackend.cpp
    LINK_LIBRARIES
        Qt6::Widgets
        Qt6::Quick
        Qt6::QuickWidgets
)

install(
    FILES module.desc
    DESTINATION lib/calamares/modules/desktopselect
)

install(
    FILES desktopselect.conf
    DESTINATION share/calamares/modules
)

install(
    FILES
        ui/desktopselect.qml
        ui/qmldir
    DESTINATION lib/calamares/modules/desktopselect/ui
)
