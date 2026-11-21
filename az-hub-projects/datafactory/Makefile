ROOTS := ab-sfbootstrap ac-sflz ad-devops ae-azure
ROOTS_REVERSE := ae-azure ad-devops ac-sflz ab-sfbootstrap

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
