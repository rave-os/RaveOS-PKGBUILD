cmake_minimum_required(VERSION 3.16)
project(raveos-calamares-module-wifi LANGUAGES CXX)

find_package(KF6CoreAddons REQUIRED)
find_package(Calamares REQUIRED)

add_subdirectory(wifi)
add_subdirectory(welcome)
