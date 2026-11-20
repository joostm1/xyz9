# Makefile for orchestrating Terraform root modules in resources
roots := $(sort $(patsubst %/Makefile,%,$(wildcard */Makefile)))
roots_reverse := $(shell printf '%s\n' $(roots) | sort -r)
.DEFAULT_GOAL := validate
roots:
	@printf '%s\n' $(roots)
init validate plan apply clean:
	@set -e; for root in $(roots); do printf '\n==> %s: %s\n' "$$root" "$@"; $(MAKE) -C "$$root" "$@"; done
destroy:
	@set -e; for root in $(roots_reverse); do printf '\n==> %s: destroy\n' "$$root"; $(MAKE) -C "$$root" destroy; done
.PHONY: roots init validate plan apply clean destroy
