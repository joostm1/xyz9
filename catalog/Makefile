repo_root := $(shell git rev-parse --show-toplevel)
catalog_dir := $(repo_root)/catalog

ifeq ($(CURDIR),$(catalog_dir))

ROOTS := terraform

.DEFAULT_GOAL := list

list:
	@printf '%s\n' $(ROOTS)

init validate plan apply clean destroy:
	@set -e; for root in $(ROOTS); do \
		printf '\n==> %s: %s\n' "$$root" "$@"; \
		$(MAKE) -C "$$root" "$@"; \
	done

.PHONY: list init validate plan apply clean destroy

else

relative_dir := $(patsubst $(repo_root)/%,%,$(CURDIR))
path_parts := $(subst /, ,$(relative_dir))
org := $(shell jq -r .name $(catalog_dir)/org.json)
project := $(if $(filter azhubs/%,$(relative_dir)),datacenter,$(if $(filter spoke-projects/%,$(relative_dir)),$(word 2,$(path_parts)),catalog))
state_container_name := $(project)
state_key := $(if $(filter azhubs/aa-foundation,$(relative_dir)),aa-config,$(notdir $(CURDIR)))
state_key_file_name := $(state_key).tfstate
planz := $(project)-$(state_key).tfplan.zip
tfopts := \
	-input=false \
	-refresh=true \
	-parallelism=32
tfvar_file := $(HOME)/.tfvars
tfbackend_file := $(HOME)/.tfbackend.hcl
tfvars := \
	-var org_name=$(org) \
	-var project_name=$(project) \
	-var state_key=$(state_key) \
	-var-file=$(tfvar_file)
tfinitops := \
	-input=false \
	-backend-config=$(tfbackend_file) \
	-backend-config=container_name=$(state_container_name) \
	-backend-config=key=$(state_key_file_name) \
	-reconfigure \
	-upgrade

root_module_tfs := $(wildcard *.tf)
local_sources = $(if $(wildcard $(1)/*.tf),$(shell \
	sed -n 's/^[[:space:]]*source[[:space:]]*=[[:space:]]*"\(\.[^"]*\)".*/\1/p' $(wildcard $(1)/*.tf) 2>/dev/null | sort -u))
define collect_module_dirs
$(foreach source,$(call local_sources,$(1)),$(abspath $(1)/$(source)) $(call collect_module_dirs,$(abspath $(1)/$(source))))
endef
local_module_dirs := $(sort $(call collect_module_dirs,$(CURDIR)))
local_module_tfs := $(foreach module,$(local_module_dirs),$(wildcard $(module)/*.tf))

catalog_inputs := $(catalog_dir)/org.json
ifneq ($(filter azhubs/%,$(relative_dir)),)
catalog_inputs += $(catalog_dir)/azhubs.json
endif
ifneq ($(filter azhubs/ca-spokes,$(relative_dir)),)
catalog_inputs += $(wildcard $(catalog_dir)/spoke-projects/*.json)
endif
ifneq ($(filter spoke-projects/%,$(relative_dir)),)
catalog_inputs += $(catalog_dir)/spoke-projects/$(project).json
endif

tf_deps := $(root_module_tfs) $(local_module_tfs) $(catalog_inputs) $(tfvar_file) $(tfbackend_file)

plan: validate $(planz)
	terraform show $(planz)

$(planz): $(tf_deps)
	terraform plan $(tfopts) $(tfvars) -out $(planz) > /dev/null || (rm -f $(planz) && exit 1)

apply: plan
	terraform apply $(tfopts) $(planz) && rm $(planz) || (rm -f $(planz) && exit 1)

destroy:
	terraform apply -auto-approve -refresh=false -destroy $(tfvars)

zapstate:
	terraform state rm `terraform state list`

clean:
	rm -rf .terraform $(planz) .terraform.lock.hcl

import:
	terraform import $(tfvars) $(to) $(id)

init:
	terraform init $(tfinitops) || (rm -rf .terraform && exit 1)

validate:
	terraform validate

.PHONY: clean zapstate destroy apply plan import init validate

endif
