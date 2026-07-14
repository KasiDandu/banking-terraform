SHELL := /bin/bash

ENV        ?= test
ENV_FILE   := $(CURDIR)/../environments/$(ENV).env
LIVE_DIR   := $(CURDIR)/../terraform/live/banking-data

# Plan file lives at a fixed path OUTSIDE .terragrunt-cache (whose hashed
# subdirectory name isn't stable across separate plan/apply CI jobs/runs),
# so a later `apply` can always find it regardless of which cache dir
# Terragrunt/Terraform actually execute from.
PLANFILE := $(LIVE_DIR)/tfplan

.PHONY: plan apply destroy-plan destroy validate

plan:
	set -a && source "$(ENV_FILE)" && set +a && \
	cd "$(LIVE_DIR)" && terragrunt plan -out="$(PLANFILE)"

apply:
	set -a && source "$(ENV_FILE)" && set +a && \
	cd "$(LIVE_DIR)" && terragrunt apply "$(PLANFILE)"

# `terragrunt apply <destroy-planfile>` performs the destroy transparently
# -- the same `apply` mechanics as a normal deploy, just fed a plan that was
# generated with -destroy. This keeps the reviewable-plan-then-gated-apply
# flow identical for both directions.
destroy-plan:
	set -a && source "$(ENV_FILE)" && set +a && \
	cd "$(LIVE_DIR)" && terragrunt plan -destroy -out="$(PLANFILE)"

destroy:
	set -a && source "$(ENV_FILE)" && set +a && \
	cd "$(LIVE_DIR)" && terragrunt apply "$(PLANFILE)"

validate:
	set -a && source "$(ENV_FILE)" && set +a && \
	cd "$(LIVE_DIR)" && terragrunt validate
