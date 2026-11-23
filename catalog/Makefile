repo_root := $(shell git rev-parse --show-toplevel)
catalog_dir := $(repo_root)/catalog

# Parent directory is the project. This directory is the state key.
project := $(notdir $(patsubst %/,%,$(dir $(CURDIR))))
org := $(shell jq -r .name $(catalog_dir)/org.json)
state_key := $(notdir $(CURDIR))
state_container_name := $(project)
state_key_file_name := $(state_key).tfstate
planz := $(project)-$(state_key).tfplan.zip
tfopts := \
	-input=false \
	-refresh=true \
	-parallelism=128
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

catalog_inputs := $(catalog_dir)/org.json $(wildcard $(catalog_dir)/projects/*.json)
# Objective: rebuild the plan when this root or a shared module changes.
# Approach: find *.tf in this root and the module trees; skip .terraform. Do not parse source lines.
module_trees := $(CURDIR) $(catalog_dir)/terraform/modules $(repo_root)/azhubs/shared $(wildcard $(repo_root)/spoke-projects/*/modules)
tf_deps := $(shell find $(module_trees) -name '*.tf' -not -path '*/.terraform/*') $(catalog_inputs) $(tfvar_file) $(tfbackend_file)

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
	terraform import $(tfvars) '$(to)' '$(id)'

init:
	terraform init $(tfinitops) || (rm -rf .terraform && exit 1)

validate:
	terraform validate

.PHONY: clean zapstate destroy apply plan import init validate
