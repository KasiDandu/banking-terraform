# banking-terraform

Terraform project with a `Terraform Plan` GitHub Actions workflow that runs
on the self-hosted EC2 runner (see the `ec2-runner` repo).

## Layout

- `versions.tf` / `providers.tf` / `backend.tf` — provider and remote state config. The S3 backend is configured at `init` time via `-backend-config`, not hardcoded, so the same repo works across environments.
- `variables.tf` / `main.tf` — add this project's resources to `main.tf`.
- `envs/*.env` — per-environment variables, sourced before `terraform` commands (as `TF_VAR_*` / `AWS_REGION`).
- `Makefile` — `make plan` / `make apply` / `make destroy`, parameterized by `ENV_FILE`, `BACKEND_BUCKET`, `PREFIX_KEY`, `LOCK_TABLE`.

## State locking

The S3 backend uses a DynamoDB table (`dynamodb_table`, via `LOCK_TABLE`) so
concurrent `plan`/`apply` runs fail fast on a lock conflict instead of racing
and corrupting state. The table (`aws_dynamodb_table.terraform_lock` in
`main.tf`) is itself Terraform-managed, but had to be created once via the
AWS CLI and imported — the backend needs to acquire a lock in that table
before running *any* operation on this config, including the operation that
would create the table. If you point this repo at a new backend
bucket/environment, bootstrap its lock table the same way:

```
aws dynamodb create-table \
  --table-name <project>-<env>-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
terraform import aws_dynamodb_table.terraform_lock <project>-<env>-tfstate-lock
```

## Running locally

```
make plan ENV_FILE=test.env BACKEND_BUCKET=my-tfstate-bucket PREFIX_KEY=envs/test/banking-terraform.tfstate LOCK_TABLE=banking-data-test-tfstate-lock
```

## Running via GitHub Actions

Trigger the `Terraform Plan` workflow manually (`workflow_dispatch`) with:
- `environment_file` — e.g. `test.env`
- `backend_bucket` — your Terraform state S3 bucket
- `prefix_key` — the state file key/prefix
- `lock_table` — defaults to `banking-data-test-tfstate-lock`

Requires repo secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` with
permissions for the backend bucket, the lock table, and any resources in
`main.tf`.

## Environment promotion (Terragrunt)

`live/test/` and `live/prod/` wrap this same module with per-environment
config, so promoting a change is "run it in test, then run the identical
plan in prod" rather than hand-editing variables:

```
cd live/test && terragrunt plan   # or apply
cd live/prod && terragrunt plan   # once prod is real -- see below
```

- `terragrunt.hcl` (repo root) — shared `remote_state` config (backend
  bucket/key/region/lock table), read from each environment's `env.hcl` via
  `get_terragrunt_dir()`. One definition, not copy-pasted per environment.
- `live/<env>/env.hcl` — the small set of facts that actually differ per
  environment (account, region, state location, artifact bucket, build keys).
- `live/<env>/terragrunt.hcl` — `terraform { source = "../.." }` (this repo
  is the module) plus `inputs` sourced from `env.hcl`.
- `live/test/` points at the real, already-deployed stack — `terragrunt
  plan` there reports "No changes", confirming it's the same infrastructure
  build/apply have been managing all along, not a parallel copy.
- `live/prod/` is a **placeholder**: there's no second AWS account yet, so
  every account-specific value (`aws_account_id`, `assume_role_arn`,
  `backend_bucket`, `artifact_bucket`, ...) in `live/prod/env.hcl` points at
  something that doesn't exist. This is deliberate — running Terragrunt
  there fails loudly (AssumeRole / NoSuchBucket) instead of silently
  deploying "prod" resources into the test account. `providers.tf`'s
  `assume_role_arn` variable is what makes cross-account promotion possible
  once a real prod account exists: fill in `live/prod/env.hcl` per its
  inline comments, bootstrap its S3 bucket + lock table the same way test's
  were (see "State locking" above), and it's a real second environment.
