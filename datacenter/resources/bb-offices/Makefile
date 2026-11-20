# Makefile for terraform -- tame the beast
org				:= xyz9
include ../project.mk
state_container_name	:= $(project)
state_key				:= $(shell basename $(shell pwd))
state_key_file_name		:= $(state_key).tfstate
planz					:= $(project)-$(state_key).tfplan.zip
tfopts					:= \
	-input=false \
	-refresh=true \
	-parallelism=32
tfvar_file	 			:= $(HOME)/.tfvars
tfbackend_file			:= $(HOME)/.tfbackend.hcl
tfvars					:= \
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
module_sources := $(shell \
	sed -n 's/^[[:space:]]*source[[:space:]]*=[[:space:]]*"\(\.[^"]*\)".*/\1/p' $(root_module_tfs) 2>/dev/null | sort -u)
submodule_tfs := $(foreach module,$(module_sources),$(wildcard $(module)/*.tf))
tf_deps := $(root_module_tfs) $(submodule_tfs) $(tfvar_file) $(tfbackend_file)
declared_modules_cmd := sed -n 's/^[[:space:]]*module[[:space:]]*"\([^"]*\)".*/\1/p' $(root_module_tfs) | sort -u
plan: validate $(planz)
	terraform show $(planz)
$(planz): $(tf_deps)
	terraform plan $(tfopts) $(tfvars) -out $(planz) > /dev/null || (rm -f $(planz) && exit 1)
apply: plan
	terraform apply $(tfopts) $(planz) && rm $(planz) || (rm $(planz) && exit 1)
destroy:
	terraform apply -auto-approve $(tfopts) -destroy $(tfvars)
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
