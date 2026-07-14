SHELL := /bin/bash

ENV            ?= test
ENV_FILE       := $(CURDIR)/../environments/$(ENV).env
LIVE_DIR       := $(CURDIR)/../terraform/live/banking-data
FOUNDATION_DIR := $(CURDIR)/../terraform/live

# Plan file lives at a fixed path OUTSIDE .terragrunt-cache (whose hashed
# subdirectory name isn't stable across separate plan/apply CI jobs/runs),
# so a later `apply` can always find it regardless of which cache dir
# Terragrunt/Terraform actually execute from.
PLANFILE := $(LIVE_DIR)/tfplan

.PHONY: foundation-plan foundation-apply plan apply destroy-plan destroy validate

# buckets/iam are foundational and low-risk (a handful of S3 buckets and
# IAM roles+managed-policy attachments, nothing business-logic-bearing) and
# idempotent, so they apply directly rather than going through the
# save-plan-then-approve gate. banking-data (the actual pipeline logic)
# depends on both being real first -- its own dependency block deliberately
# only allows mock outputs for `validate`, not `plan`, since a saved plan
# bakes in whatever values were real (or mocked) at plan time and replays
# them verbatim on apply, ignoring any fresher env vars.
foundation-plan:
	set -a && source "$(ENV_FILE)" && set +a && \
	cd "$(FOUNDATION_DIR)/buckets" && terragrunt plan && \
	cd "$(FOUNDATION_DIR)/iam" && terragrunt plan

foundation-apply:
	set -a && source "$(ENV_FILE)" && set +a && \
	cd "$(FOUNDATION_DIR)/buckets" && terragrunt apply -auto-approve && \
	cd "$(FOUNDATION_DIR)/iam" && terragrunt apply -auto-approve

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
