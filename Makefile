

INSTALL=install
BIN_INSTALL_DIR = /usr/bin
SHARED_INSTALL_DIR = /usr/share/git-hierarchy/

BINFILES=$(wildcard bin/*)

all:
	echo ""

install:
	$(INSTALL) -v -D --directory $(DESTDIR)$(BIN_INSTALL_DIR)
	for p in $(BINFILES); do \
	  $(INSTALL) -v -m 555 $$p $(DESTDIR)$(BIN_INSTALL_DIR) ; \
	done
# todo: permissions!
	$(INSTALL) -v -D --directory $(DESTDIR)$(SHARED_INSTALL_DIR)
	for p in share/*; do \
	  $(INSTALL) -v -m 555 $$p $(DESTDIR)$(SHARED_INSTALL_DIR) ; \
	done


clean:

git-clean:
	git clean -f -d -x

