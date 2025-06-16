# This is not a true build system, but a convenience
# tool of install and run steps. It uses recursive
# make rules to make maintenance easy.
.NOTPARALLEL: all pretty
.NOTPARALLEL: check_mdbook check_mdbook_linkcheck check_mdbook_pagetoc check_prettier check_mdbook_webinclude check_mdbook_chapterlist
.NOTPARALLEL: install_mdbook install_mdbook_linkcheck install_mdbook_pagetoc install_prettier install_mdbook_webinclude install_mdbook_chapterlist

.PHONY: all pretty
.PHONY: check_mdbook check_mdbook_linkcheck check_mdbook_pagetoc check_prettier check_mdbook_webinclude check_mdbook_chapterlist
.PHONY: install_mdbook install_mdbook_linkcheck install_mdbook_pagetoc install_prettier check_mdbook_webinclude install_mdbook_chapterlist

SHELL = /usr/bin/env bash

# Configuration
MDBOOK_VERSION := 0.4.51
MDBOOK_WEBINCLUDE_VERSION := 0.1.0
MDBOOK_LINKCHECK_VERSION := 0.7.7
MDBOOK_PAGETOC_VERSION := 0.2.0
MDBOOK_CHAPTERLIST_VERSION := 0.1.0
PRETTIER_VERSION := 3.0.0

# For CI, use local install; for normal users system install
# (already in PATH) is fine
ifndef CI
Q := @
MDBOOK := mdbook
MDBOOK_LINKCHECK := mdbook-linkcheck
MDBOOK_PAGETOC := mdbook-pagetoc
MDBOOK_CHAPTERLIST := mdbook-chapter-list
PRETTIER := prettier
else
$(info *** Running in CI environment ***)
Q :=
MDBOOK := mdbook
MDBOOK_LINKCHECK := mdbook-linkcheck
MDBOOK_PAGETOC := mdbook-pagetoc
MDBOOK_CHAPTERLIST := mdbook-chapter-list
PRETTIER := prettier
export TERM := dumb
# Allow local installs
export PATH := $(PATH):$(CURDIR)
endif

# The only thing we really want to do is build
all:	check_mdbook check_mdbook_linkcheck check_mdbook_webinclude check_mdbook_pagetoc check_prettier check_mdbook_chapterlist
	@echo $$(tput bold)All required tools installed with correct version.$$(tput sgr0)
	$(Q)$(PRETTIER) --check --prose-wrap always '**/*.md' || (echo $$(tput bold)$$(tput setaf 1)Source formatting errors.; echo Run \"make pretty\" to fix automatically.; echo Warning: will overwrite files in-place.$$(tput sgr0); exit 1)
	@echo $$(tput bold)Source file formatting correct.$$(tput sgr0)
	@# Becuase we modified math, need to do this in a subshell
	$(Q)sh -c "$(MDBOOK) build"
	@echo $$(tput bold)Book built. Run \"mdbook serve\" to view locally.$$(tput sgr0)

pretty:	check_prettier
	$(PRETTIER) --write --prose-wrap always '**/*.md'

fmt format: pretty

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
	rm -f mdbook-linkcheck.x86_64-unknown-linux-gnu.zip
	curl -L https://github.com/Michael-F-Bryan/mdbook-linkcheck/releases/download/v$(MDBOOK_LINKCHECK_VERSION)/mdbook-linkcheck.x86_64-unknown-linux-gnu.zip -O
	unzip -n mdbook-linkcheck.x86_64-unknown-linux-gnu.zip
	chmod +x mdbook-linkcheck
	rm mdbook-linkcheck.x86_64-unknown-linux-gnu.zip
	$(Q)$(MDBOOK_LINKCHECK) --version
endif

check_mdbook_linkcheck:
	$(Q)$(MDBOOK_LINKCHECK) --version || $(MAKE) install_mdbook_linkcheck
	$(Q)[[ $$($(MDBOOK_LINKCHECK) --version | cut -d' ' -f2) == '$(MDBOOK_LINKCHECK_VERSION)' ]] || $(MAKE) install_mdbook_linkcheck



install_mdbook_webinclude:
	cargo install mdbook-webinclude --version $(MDBOOK_WEBINCLUDE_VERSION)

check_mdbook_webinclude:
	$(Q)mdbook-webinclude --help > /dev/null || $(MAKE) install_mdbook_webinclude



# mdbook-pagetoc doesn't support the version flag
PAGETOC_FILENAME := mdbook-pagetoc-v$(MDBOOK_PAGETOC_VERSION)-x86_64-unknown-linux-gnu.tar.gz
install_mdbook_pagetoc:
ifndef CI
	cargo install mdbook-pagetoc --version $(MDBOOK_PAGETOC_VERSION)
else
	rm -f $(PAGETOC_FILENAME)
	curl -L https://github.com/slowsage/mdbook-pagetoc/releases/download/v$(MDBOOK_PAGETOC_VERSION)/$(PAGETOC_FILENAME) -O
	tar -xzf $(PAGETOC_FILENAME)
	chmod +x mdbook-pagetoc
	rm $(PAGETOC_FILENAME)
	@#$(Q)$(MDBOOK_PAGETOC) --version
endif

# mdbook-pagetoc doesn't support the version flag
check_mdbook_pagetoc:
	$(Q)$(MDBOOK_PAGETOC) --help > /dev/null || $(MAKE) install_mdbook_pagetoc
	@#$(Q)[[ $$($(MDBOOK_PAGETOC) --version | cut -d' ' -f2) == '$(MDBOOK_PAGETOC_VERSION)' ]] || $(MAKE) install_mdbook_pagetoc
	@#$(Q)$(MDBOOK_PAGETOC) --version || $(MAKE) install_mdbook_pagetoc


# mdbook-chapter-list doesn't support the version flag
CHAPTERLIST_FILENAME := mdbook-chapter-list-v$(MDBOOK_CHAPTERLIST_VERSION)-x86_64-unknown-linux-gnu.tar.gz
install_mdbook_chapterlist:
	cargo install mdbook-chapter-list --version $(MDBOOK_CHAPTERLIST_VERSION)

# mdbook-chapter-list doesn't support the version flag
check_mdbook_chapterlist:
	$(Q)$(MDBOOK_CHAPTERLIST) --help > /dev/null || $(MAKE) install_mdbook_chapterlist



install_prettier:
	npm i -g prettier@$(PRETTIER_VERSION)

check_prettier:
	$(Q)$(PRETTIER) --version || $(MAKE) install_prettier
	$(Q)[[ $$($(PRETTIER) --version) == '$(PRETTIER_VERSION)' ]] || $(MAKE) install_prettier

