# Makefile for user application

# Specify this directory relative to the current application.
BASE_DIR = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

PACKAGE_NAME=example_app

# Which files to compile.
C_SRCS := $(wildcard *.c)

# External libraries used
EXTERN_LIBS += $(BASE_DIR)/libtock

# Include userland master makefile. Contains rules and flags for actually
# building the application.
include $(BASE_DIR)/make/AppMakefile.mk
