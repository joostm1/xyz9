# Child directories that contain a Makefile, in ls order. Destroy walks that list backwards.
ROOTS := $(shell ls -d */Makefile | sed 's|/Makefile||')
ROOTS_REVERSE := $(shell printf '%s\n' $(ROOTS) | tac)

.DEFAULT_GOAL := list

list:
	@printf '%s\n' $(ROOTS)

init validate plan apply clean:
	@set -e; for root in $(ROOTS); do \
		if [ -f "$$root/Makefile" ]; then \
			printf '\n==> %s: %s\n' "$$root" "$@"; \
			$(MAKE) -C "$$root" "$@"; \
		fi; \
	done

destroy:
	@set -e; for root in $(ROOTS_REVERSE); do \
		if [ -f "$$root/Makefile" ]; then \
			printf '\n==> %s: destroy\n' "$$root"; \
			$(MAKE) -C "$$root" destroy; \
		fi; \
	done

.PHONY: list init validate plan apply clean destroy
