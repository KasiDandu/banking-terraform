SHELL := /bin/bash

ENV_FILE ?= test.env
BACKEND_BUCKET ?=
PREFIX_KEY ?=
AWS_REGION ?= us-east-2
LOCK_TABLE ?= banking-data-test-tfstate-lock
DESTROY ?= false

.PHONY: init fmt validate plan apply destroy destroy-interactive

init:
	set -a && source envs/$(ENV_FILE) && set +a && \
	terraform init \
	  -backend-config="bucket=$(BACKEND_BUCKET)" \
	  -backend-config="key=$(PREFIX_KEY)" \
	  -backend-config="region=$(AWS_REGION)" \
	  -backend-config="dynamodb_table=$(LOCK_TABLE)"

fmt:
	terraform fmt -recursive

validate: init
	terraform validate

# DESTROY=true produces a destroy-plan instead of a regular plan; the saved
# tfplan file is consumed identically either way by `make apply`, since
# `terraform apply <planfile>` just performs whatever that plan contains.
plan: init
	set -a && source envs/$(ENV_FILE) && set +a && \
	terraform plan $(if $(filter true,$(DESTROY)),-destroy,) -out=tfplan

apply:
	terraform apply tfplan

# Interactive-only: prompts for confirmation, so it hangs non-interactively.
# CI destroys go through `make plan DESTROY=true` + `make apply` instead,
# same as a regular apply, so it can use a saved plan and a manual-approval
# gate rather than -auto-approve.
destroy-interactive: init
	set -a && source envs/$(ENV_FILE) && set +a && \
	terraform destroy
