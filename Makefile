
INSTALL		:= install
PREFIX := /usr/
BIN_INSTALL_DIR := $(PREFIX)bin

SHARED_INSTALL_DIR := $(PREFIX)share/git-hierarchy/
ZSH_COMPLETION_DIR := $(PREFIX)share/zsh/vendor-completions/

BINFILES := $(wildcard bin/*)

COMPLETION_FILES := $(wildcard zsh/_*)

all:
	@echo "No compilation"

.PHONY:	all install install-zsh

install: install-zsh install-libs all
	$(INSTALL) -v -D --directory $(DESTDIR)$(BIN_INSTALL_DIR)
	for p in $(BINFILES); do \
	  $(INSTALL) -v -m 555 $$p $(DESTDIR)$(BIN_INSTALL_DIR) ; \
	done


install-libs:
# todo: permissions!
	$(INSTALL) -v -D --directory $(DESTDIR)$(SHARED_INSTALL_DIR)
	for p in share/*; do \
	  $(INSTALL) -v -m 555 $$p $(DESTDIR)$(SHARED_INSTALL_DIR) ; \
	done


install-zsh:
	$(INSTALL) -v -D --directory $(DESTDIR)$(ZSH_COMPLETION_DIR)
	for p in $(COMPLETION_FILES); do \
	  $(INSTALL) -v -m 444 $$p $(DESTDIR)$(ZSH_COMPLETION_DIR) ; \
	done


clean:

git-clean:
	git clean -f -d -x
