.PHONY: list validate

list:
	@ls *.env

# Sanity-checks each env file is sourceable shell, without actually
# exporting anything into the calling shell.
validate:
	@for f in *.env; do \
	  echo "Checking $$f..."; \
	  bash -n "$$f" || exit 1; \
	done
	@echo "All environment files are syntactically valid."
