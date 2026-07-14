ENV ?= test

.PHONY: fmt plan apply destroy-plan destroy validate

fmt:
	terraform fmt -recursive terraform/
	terragrunt hclfmt

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
