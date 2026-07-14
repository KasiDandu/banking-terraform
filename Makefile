ENV    ?= test
MODULE ?= banking-data

.PHONY: fmt plan apply destroy-plan destroy validate

fmt:
	terraform fmt -recursive terraform/
	terragrunt hclfmt

plan:
	$(MAKE) -C deploys plan ENV=$(ENV) MODULE=$(MODULE)

apply:
	$(MAKE) -C deploys apply ENV=$(ENV) MODULE=$(MODULE)

destroy-plan:
	$(MAKE) -C deploys destroy-plan ENV=$(ENV) MODULE=$(MODULE)

destroy:
	$(MAKE) -C deploys destroy ENV=$(ENV) MODULE=$(MODULE)

validate:
	$(MAKE) -C deploys validate ENV=$(ENV) MODULE=$(MODULE)
