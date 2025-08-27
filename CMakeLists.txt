cmake_minimum_required(VERSION 3.16)
project(PackageManagerGUI)

set(CMAKE_CXX_STANDARD 17)

find_package(FLTK REQUIRED)

add_executable(package-manager-gui src/main.cpp)
target_include_directories(package-manager-gui PRIVATE ${FLTK_INCLUDE_DIR})
target_link_libraries(package-manager-gui PRIVATE ${FLTK_LIBRARIES})
