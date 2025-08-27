cmake_minimum_required(VERSION 3.16)
project(PackageManagerGUI)

set(CMAKE_CXX_STANDARD 17)

find_package(Qt5 COMPONENTS Widgets REQUIRED)

add_executable(package-manager-gui src/main.cpp)
target_link_libraries(package-manager-gui Qt5::Widgets)
