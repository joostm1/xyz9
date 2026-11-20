PROJECTS := config offices projects homeapps datacenter datafactory

.DEFAULT_GOAL := list

list:
	@printf '%s\n' $(PROJECTS)

init validate plan apply clean:
	@set -e; for project in $(PROJECTS); do \
		if [ -d "$$project/resources" ]; then \
			printf '\n==> %s/resources: %s\n' "$$project" "$@"; \
			$(MAKE) -C "$$project/resources" "$@"; \
		fi; \
	done

destroy:
	@set -e; for project in datafactory datacenter homeapps projects offices; do \
		if [ -d "$$project/resources" ]; then \
			printf '\n==> %s/resources: destroy\n' "$$project"; \
			$(MAKE) -C "$$project/resources" destroy; \
		fi; \
	done

.PHONY: list init validate plan apply clean destroy
