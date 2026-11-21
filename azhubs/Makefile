ROOTS := aa-foundation ba-hubs bb-sp1-connectivity ca-spokes
ROOTS_REVERSE := ca-spokes bb-sp1-connectivity ba-hubs aa-foundation

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
