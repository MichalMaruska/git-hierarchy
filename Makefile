

INSTALL=install
BIN_INSTALL_DIR = /usr/bin

BINFILES=$(wildcard bin/*)

all:
	echo ""

install:
	$(INSTALL) -v -D --directory $(DESTDIR)$(BIN_INSTALL_DIR)
	for p in $(BINFILES); do \
	  $(INSTALL) -v -m 555 $$p $(DESTDIR)$(BIN_INSTALL_DIR) ; \
	done




clean:

git-clean:
	git clean -f -d -x

