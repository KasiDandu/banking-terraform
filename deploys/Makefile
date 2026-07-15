SHELL := /bin/bash

ENV      ?= test
MODULE   ?= banking-data
ENV_FILE := $(CURDIR)/../environments/$(ENV).env
LIVE_ROOT := $(CURDIR)/../terraform/live

# MODULE=all fans out to every unit, in the order dependencies actually
# require: buckets/iam must exist before banking-data is planned (its
# `dependency "iam"` block needs iam's *real* outputs, not mocks -- see
# terragrunt.hcl). Destroying goes the other way: banking-data must be torn
# down before the buckets/roles it depends on, or it's left referencing
# resources that no longer exist.
APPLY_ORDER   := buckets iam banking-data
DESTROY_ORDER := banking-data iam buckets

MODULES_APPLY   := $(if $(filter all,$(MODULE)),$(APPLY_ORDER),$(MODULE))
MODULES_DESTROY := $(if $(filter all,$(MODULE)),$(DESTROY_ORDER),$(MODULE))

# Plan file lives at a fixed path per unit (LIVE_ROOT/<module>/tfplan),
# OUTSIDE .terragrunt-cache (whose hashed subdirectory name isn't stable
# across separate plan/apply CI jobs/runs), so a later `apply` can always
# find it regardless of which cache dir Terragrunt/Terraform actually
# executed from.

.PHONY: plan apply destroy-plan destroy validate

plan:
	set -a && source "$(ENV_FILE)" && set +a && \
	for m in $(MODULES_APPLY); do \
	  echo "==> plan: $$m" && \
	  (cd "$(LIVE_ROOT)/$$m" && terragrunt plan -out="$(LIVE_ROOT)/$$m/tfplan") || exit 1; \
	done

apply:
	set -a && source "$(ENV_FILE)" && set +a && \
	for m in $(MODULES_APPLY); do \
	  echo "==> apply: $$m" && \
	  (cd "$(LIVE_ROOT)/$$m" && terragrunt apply "$(LIVE_ROOT)/$$m/tfplan") || exit 1; \
	done

destroy-plan:
	set -a && source "$(ENV_FILE)" && set +a && \
	for m in $(MODULES_DESTROY); do \
	  echo "==> destroy-plan: $$m" && \
	  (cd "$(LIVE_ROOT)/$$m" && terragrunt plan -destroy -out="$(LIVE_ROOT)/$$m/tfplan") || exit 1; \
	done

destroy:
	set -a && source "$(ENV_FILE)" && set +a && \
	for m in $(MODULES_DESTROY); do \
	  echo "==> destroy: $$m" && \
	  (cd "$(LIVE_ROOT)/$$m" && terragrunt apply "$(LIVE_ROOT)/$$m/tfplan") || exit 1; \
	done

validate:
	set -a && source "$(ENV_FILE)" && set +a && \
	for m in $(MODULES_APPLY); do \
	  echo "==> validate: $$m" && \
	  (cd "$(LIVE_ROOT)/$$m" && terragrunt validate) || exit 1; \
	done
