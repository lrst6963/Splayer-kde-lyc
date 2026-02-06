cmake_minimum_required(VERSION 3.16)

project(splayer-kde-lyric VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.2 REQUIRED COMPONENTS Quick WebSockets Network Widgets)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

qt_add_executable(appsplayer-kde-lyric
    src/main.cpp
    src/SPlayerClient.cpp
    src/SPlayerClient.h
    resources/splayer-kde-lyric.qrc
)

target_link_libraries(appsplayer-kde-lyric
    PRIVATE Qt6::Quick Qt6::WebSockets Qt6::Network Qt6::Widgets
)

# 安装（可选）
install(TARGETS appsplayer-kde-lyric
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
