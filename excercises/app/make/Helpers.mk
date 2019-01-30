# Various helper functions and definitions for use by Tock makefiles. Included
# by AppMakefile.mk and libtock's Makefile

# ensure that this file is only included once
ifndef HELPERS_MAKEFILE
HELPERS_MAKEFILE = 1

#########################################################################################
## Pretty-printing rules

# If environment variable V is non-empty, be verbose
ifneq ($(V),)
Q=
TRACE_DIR =
TRACE_BIN =
TRACE_DEP =
TRACE_CC  =
TRACE_CXX =
TRACE_LD  =
TRACE_AR  =
TRACE_AS  =
TRACE_LST =
ELF2TAB_ARGS += -v
else
Q=@
TRACE_DIR = @echo " DIR       " $@
TRACE_BIN = @echo " BIN       " $@
TRACE_DEP = @echo " DEP       " $<
TRACE_CC  = @echo "  CC       " $<
TRACE_CXX = @echo " CXX       " $<
TRACE_LD  = @echo "  LD       " $@
TRACE_AR  = @echo "  AR       " $@
TRACE_AS  = @echo "  AS       " $<
TRACE_LST = @echo " LST       " $<
endif

endif

