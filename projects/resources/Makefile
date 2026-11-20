# Dispatch terraform targets across root modules in lifecycle order
roots := $(sort $(patsubst %/,%,$(dir $(wildcard */*.tf))))
reverse = $(if $1,$(call reverse,$(wordlist 2,$(words $1),$1)) $(firstword $1))

.DEFAULT_GOAL := plan
.PHONY: roots init validate plan apply clean import destroy zapstate

roots:
	@echo $(roots)

init validate plan apply clean import:
	@for r in $(roots); do $(MAKE) -C $$r $@ || exit 1; done

destroy zapstate:
	@for r in $(strip $(call reverse,$(roots))); do $(MAKE) -C $$r $@ || exit 1; done
