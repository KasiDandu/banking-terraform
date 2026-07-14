ENV ?= test

.PHONY: fmt foundation-plan foundation-apply plan apply destroy-plan destroy validate

fmt:
	terraform fmt -recursive terraform/
	terragrunt hclfmt

foundation-plan:
	$(MAKE) -C deploys foundation-plan ENV=$(ENV)

foundation-apply:
	$(MAKE) -C deploys foundation-apply ENV=$(ENV)

plan:
	$(MAKE) -C deploys plan ENV=$(ENV)

apply:
	$(MAKE) -C deploys apply ENV=$(ENV)

destroy-plan:
	$(MAKE) -C deploys destroy-plan ENV=$(ENV)

destroy:
	$(MAKE) -C deploys destroy ENV=$(ENV)

validate:
	$(MAKE) -C deploys validate ENV=$(ENV)
