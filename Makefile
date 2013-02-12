

INSTALL=install
BIN_INSTALL_DIR = /usr/bin
SHARED_INSTALL_DIR = /usr/share/git-hierarchy/

ZSH_COMPLETION_DIR=/usr/share/zsh/site-functions/Completion/

BINFILES=$(wildcard bin/*)

COMPLETION_FILES= zsh/_git-segment zsh/_git-sum zsh/_git-delete zsh/_git-segment-name zsh/_git-sum-name

all:
	@echo "No compilation"

.PHONY:	all install install-zsh

install: install-zsh all
	$(INSTALL) -v -D --directory $(DESTDIR)$(BIN_INSTALL_DIR)
	for p in $(BINFILES); do \
	  $(INSTALL) -v -m 555 $$p $(DESTDIR)$(BIN_INSTALL_DIR) ; \
	done
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

