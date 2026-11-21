ROOTS := .

.DEFAULT_GOAL := list

list:
	@printf '%s\n' $(ROOTS)

init validate plan apply clean destroy:
	@set -e; for root in $(ROOTS); do \
		if [ -f "$$root/terraform/Makefile" ] && ls "$$root/terraform"/*.tf >/dev/null 2>&1; then \
			printf '\n==> aa-catalog/terraform: %s\n' "$@"; \
			$(MAKE) -C "$$root/terraform" "$@"; \
		elif [ -f "$$root/terraform/Makefile" ]; then \
			printf '\n==> aa-catalog/terraform: skipped (%s) (no root .tf files)\n' "$@"; \
		fi; \
	done

.PHONY: list init validate plan apply clean destroy
