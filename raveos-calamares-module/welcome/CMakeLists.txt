find_package(Qt6 REQUIRED COMPONENTS Widgets)

calamares_add_plugin(ravewelcome
    TYPE viewmodule
    EXPORT_MACRO PLUGINDLLEXPORT_PRO
    SOURCES
        RaveWelcomeViewStep.cpp
    LINK_LIBRARIES
        Qt6::Widgets
        Calamares::calamares
)

install(
    FILES module.desc ravewelcome.conf
    DESTINATION lib/calamares/modules/ravewelcome
)
