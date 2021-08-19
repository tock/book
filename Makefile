# This is not a true build system, but a convenience
# tool of install and run steps. It uses recursive
# make rules to make maintenance easy.
.NOTPARALLEL: all pretty
.NOTPARALLEL: check_mdbook check_mdbook_linkcheck check_prettier
.NOTPARALLEL: install_mdbook install_mdbook_linkcheck install_prettier

.PHONY: all pretty
.PHONY: check_mdbook check_mdbook_linkcheck check_prettier
.PHONY: install_mdbook install_mdbook_linkcheck install_prettier

SHELL = /bin/bash

# Configuration
MDBOOK_VERSION := 0.4.7
MDBOOK_LINKCHECK_VERSION := 0.7.4
PRETTIER_VERSION := 2.3.2

# For CI, use local install; for normal users system install
# (already in PATH) is fine
ifndef CI
Q := @
MDBOOK := mdbook
MDBOOK_LINKCHECK := mdbook-linkcheck
PRETTIER := prettier
else
$(info *** Running in CI environment ***)
Q :=
MDBOOK := mdbook
MDBOOK_LINKCHECK := mdbook-linkcheck
PRETTIER := prettier
export TERM := dumb
# Allow local installs
export PATH := $(PATH):$(CURDIR)
endif

# The only thing we really want to do is build
all:	check_mdbook check_mdbook_linkcheck check_prettier
	@echo $$(tput bold)All required tools installed with correct version.$$(tput sgr0)
	$(Q)$(PRETTIER) --check --prose-wrap always '**/*.md' || (echo $$(tput bold)$$(tput setaf 1)Source formatting errors.; echo Run \"make pretty\" to fix automatically.; echo Warning: will overwrite files in-place.$$(tput sgr0); exit 1)
	@echo $$(tput bold)Source file formatting correct.$$(tput sgr0)
	@# Becuase we modified math, need to do this in a subshell
	$(Q)sh -c "$(MDBOOK) build"
	@echo $$(tput bold)Book built. Run \"mdbook serve\" to view locally.$$(tput sgr0)

pretty:	check_prettier
	$(PRETTIER) --write --prose-wrap always '**/*.md'

install_mdbook:
ifndef CI
	cargo install mdbook --version $(MDBOOK_VERSION)
else
	curl -L https://github.com/rust-lang/mdBook/releases/download/v$(MDBOOK_VERSION)/mdbook-v$(MDBOOK_VERSION)-x86_64-unknown-linux-gnu.tar.gz | tar xvz
	$(Q)$(MDBOOK) --version
endif

check_mdbook:
	$(Q)$(MDBOOK) --version || $(MAKE) install_mdbook
	$(Q)[[ $$($(MDBOOK) --version | cut -d'v' -f2) == '$(MDBOOK_VERSION)' ]] || $(MAKE) install_mdbook


install_mdbook_linkcheck:
ifndef CI
	cargo install mdbook-linkcheck --version $(MDBOOK_LINKCHECK_VERSION)
else
	curl -L https://github.com/Michael-F-Bryan/mdbook-linkcheck/releases/download/v$(MDBOOK_LINKCHECK_VERSION)/mdbook-linkcheck.v$(MDBOOK_LINKCHECK_VERSION).x86_64-unknown-linux-gnu.zip -O
	unzip -n mdbook-linkcheck.v$(MDBOOK_LINKCHECK_VERSION).x86_64-unknown-linux-gnu.zip
	chmod +x mdbook-linkcheck
	rm mdbook-linkcheck.v$(MDBOOK_LINKCHECK_VERSION).x86_64-unknown-linux-gnu.zip
	$(Q)$(MDBOOK_LINKCHECK) --version
endif

check_mdbook_linkcheck:
	$(Q)$(MDBOOK_LINKCHECK) --version || $(MAKE) install_mdbook_linkcheck
	$(Q)[[ $$($(MDBOOK_LINKCHECK) --version | cut -d' ' -f2) == '$(MDBOOK_LINKCHECK_VERSION)' ]] || $(MAKE) install_mdbook_linkcheck


install_prettier:
	npm i -g prettier@$(PRETTIER_VERSION)

check_prettier:
	$(Q)$(PRETTIER) --version || $(MAKE) install_prettier
	$(Q)[[ $$($(PRETTIER) --version) == '$(PRETTIER_VERSION)' ]] || $(MAKE) install_prettier

