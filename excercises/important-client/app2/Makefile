# Makefile for user application

# Specify this directory relative to the current application.
#BASE_DIR = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))/..
TOCK_USERLAND_BASE_DIR = ..

# Which files to compile.
C_SRCS := $(wildcard *.c)

# External libraries used
EXTERN_LIBS += $(TOCK_USERLAND_BASE_DIR)/libtock

# Include userland master makefile. Contains rules and flags for actually
# building the application.
include $(TOCK_USERLAND_BASE_DIR)/AppMakefile.mk
