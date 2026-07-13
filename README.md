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
