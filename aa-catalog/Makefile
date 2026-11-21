ROOTS := catalog

.DEFAULT_GOAL := list

list:
	@printf '%s\n' $(ROOTS)

init validate plan apply clean destroy:
	@set -e; for root in $(ROOTS); do \
		if [ -f "$$root/terraform/Makefile" ]; then \
			printf '\n==> %s/terraform: %s\n' "$$root" "$@"; \
			$(MAKE) -C "$$root/terraform" "$@"; \
		fi; \
	done

.PHONY: list init validate plan apply clean destroy
