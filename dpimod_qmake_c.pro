TEMPLATE = app
CONFIG += console
CONFIG -= app_bundle
CONFIG -= qt

SOURCES += \
        src/dpimod.c

DISTFILES += \
    Makefile

INCLUDEPATH += /lib/modules/5.15.0-70-generic/build/include \
               /lib/modules/5.15.0-70-generic/build/arch/x86/include \

