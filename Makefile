GROUPS := azhubs spoke-projects

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
	@set -e; for group in spoke-projects azhubs; do \
		if [ -f "$$group/Makefile" ]; then \
			printf '\n==> %s: destroy\n' "$$group"; \
			$(MAKE) -C "$$group" destroy; \
		fi; \
	done

.PHONY: list init validate plan apply clean destroy
