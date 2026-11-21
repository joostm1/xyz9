PROJECTS := datafactory

.DEFAULT_GOAL := list

list:
	@printf '%s\n' $(PROJECTS)

init validate plan apply clean destroy:
	@set -e; for project in $(PROJECTS); do \
		if [ -f "$$project/Makefile" ]; then \
			printf '\n==> %s: %s\n' "$$project" "$@"; \
			$(MAKE) -C "$$project" "$@"; \
		fi; \
	done

.PHONY: list init validate plan apply clean destroy
