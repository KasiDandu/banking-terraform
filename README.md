# banking-terraform

Terraform project with a `Terraform Plan` GitHub Actions workflow that runs
on the self-hosted EC2 runner (see the `ec2-runner` repo).

## Layout

- `versions.tf` / `providers.tf` / `backend.tf` — provider and remote state config. The S3 backend is configured at `init` time via `-backend-config`, not hardcoded, so the same repo works across environments.
- `variables.tf` / `main.tf` — add this project's resources to `main.tf`.
- `envs/*.env` — per-environment variables, sourced before `terraform` commands (as `TF_VAR_*` / `AWS_REGION`).
- `Makefile` — `make plan` / `make apply` / `make destroy`, parameterized by `ENV_FILE`, `BACKEND_BUCKET`, `PREFIX_KEY`.

## Running locally

```
make plan ENV_FILE=test.env BACKEND_BUCKET=my-tfstate-bucket PREFIX_KEY=envs/test/banking-terraform.tfstate
```

## Running via GitHub Actions

Trigger the `Terraform Plan` workflow manually (`workflow_dispatch`) with:
- `environment_file` — e.g. `test.env`
- `backend_bucket` — your Terraform state S3 bucket
- `prefix_key` — the state file key/prefix

Requires repo secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` with
permissions for the backend bucket and any resources in `main.tf`.
