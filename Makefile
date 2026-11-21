GROUPS := aa-catalog ab-hub-spoke az-hub-projects

.DEFAULT_GOAL := list

list:
	@printf '%s\n' $(GROUPS)

init validate plan apply clean:
	@set -e; for group in $(GROUPS); do \
		if [ -f "$$group/Makefile" ]; then \
			printf '\n==> %s: %s\n' "$$group" "$@"; \
			$(MAKE) -C "$$group" "$@"; \
		fi; \
	done

destroy:
	@set -e; for group in az-hub-projects ab-hub-spoke; do \
		if [ -f "$$group/Makefile" ]; then \
			printf '\n==> %s: destroy\n' "$$group"; \
			$(MAKE) -C "$$group" destroy; \
		fi; \
	done

.PHONY: list init validate plan apply clean destroy
