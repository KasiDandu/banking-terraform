SHELL := /bin/bash

ENV_FILE ?= test.env
BACKEND_BUCKET ?=
PREFIX_KEY ?=
AWS_REGION ?= us-east-2
LOCK_TABLE ?= banking-data-test-tfstate-lock

.PHONY: init fmt validate plan apply destroy

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

plan: init
	set -a && source envs/$(ENV_FILE) && set +a && \
	terraform plan -out=tfplan

apply:
	terraform apply tfplan

destroy: init
	set -a && source envs/$(ENV_FILE) && set +a && \
	terraform destroy
