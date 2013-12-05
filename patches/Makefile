SHELL=/bin/zsh
GIT_CORE_DIR := /usr/lib/git-core/

SOURCES := git-am  git-rebase--am git-rebase
ORIGINS := $(foreach x,$(SOURCES),$(GIT_CORE_DIR)$(x))


diff:
	cdiff -r . $(GIT_CORE_DIR)

copy:
	cp --target-directory . $(ORIGINS)


install:
	@foreach file ($(SOURCES)) {\
		if ! diff $$file $(GIT_CORE_DIR)/$$file; \
		then sudo cp -va $$file $(GIT_CORE_DIR)/$$file;\
	fi \
	}

#@echo $(SOURCES)
#@echo $(ORIGINS)
