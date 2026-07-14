# banking-terraform

Terraform + Terragrunt project for the banking-data pipeline's AWS
infrastructure. CI runs via the `Terraform` GitHub Actions workflow on the
self-hosted EC2 runner (see the `ec2-runner` repo).

## Layout

```
banking-terraform/
├── .github/workflows/main.yaml   # plan / apply / destroy, one workflow
├── Makefile                       # make plan|apply|destroy-plan|destroy ENV=test|prod
├── deploys/
│   └── Makefile                   # sources environments/<ENV>.env, drives terragrunt
├── environments/
│   ├── test.env                   # real -- points at the deployed test stack
│   ├── prod.env                   # placeholder -- see "Environment promotion" below
│   └── Makefile                   # `make validate` / `make list`
└── terraform/
    ├── backend/                   # one-time bootstrap: state bucket + lock table
    │   └── main.tf                # (local state -- can't depend on the backend it creates)
    ├── live/banking-data/         # Terragrunt root: wires the module to a backend
    │   ├── terragrunt.hcl
    │   ├── glue.json              # resource-tuning inputs, split by AWS service
    │   ├── lambda.json
    │   ├── buckets.json
    │   ├── eventbridge-rules.json
    │   └── banking-data.tfvars    # the one value that's truly constant: project_name
    └── modules/banking-data/      # the actual resources, split by AWS service
        ├── main.tf                # locals, state lock table, Glue Catalog + Athena, SSM
        ├── data.tf                # aws_caller_identity + all iam_policy_document data sources
        ├── buckets.tf             # S3 buckets + bucket policy
        ├── lambda.tf              # Lambda function + permission
        ├── glue.tf                # Glue ETL job
        ├── eventbridge-rules.tf   # CloudTrail + EventBridge rule/target
        ├── iam-roles.tf           # Lambda/Glue-job/crawler roles, policies, attachments
        ├── variables.tf / outputs.tf / versions.tf / providers.tf / backend.tf
        └── config/*.json          # per-source schema configs, uploaded to the config bucket
```

## Running locally

```
make plan ENV=test      # or apply / destroy-plan / destroy
```

`ENV` selects `environments/<ENV>.env`, which is sourced (as `TF_VAR_*` plus
`BACKEND_BUCKET`/`PREFIX_KEY`/`AWS_REGION`/`LOCK_TABLE`) before Terragrunt
runs in `terraform/live/banking-data`. `make fmt` formats both the `.tf`
files and the Terragrunt HCL.

## Running via GitHub Actions

Trigger the `Terraform` workflow (`workflow_dispatch`) with:
- `environment` — `test` or `prod`
- `action` — `plan`, `apply`, or `destroy`
- `confirm_destroy` — required, must be exactly `destroy`, when `action=destroy`

Every run does a `plan` first (auto-resolving the latest build's S3 keys by
querying `LastModified` under `banking-artifacts`' sha256-keyed prefixes, no
manual paste-in) and uploads it as an artifact. `apply`/`destroy` download
that exact plan and apply it in a second job gated by the `production`
GitHub Environment — requires manual approval, so nothing ever touches real
infrastructure unattended. Requires repo secrets `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` and repo variables `AWS_REGION` / `ARTIFACT_BUCKET`.

## State locking

The S3 backend uses a DynamoDB table (`dynamodb_table`, wired from
`LOCK_TABLE`) so concurrent `plan`/`apply` runs fail fast on a lock conflict
instead of racing and corrupting state. `aws_dynamodb_table.terraform_lock`
in `terraform/modules/banking-data/main.tf` is itself Terraform-managed for
`test`, but had to be created once via the AWS CLI and imported — the
backend needs to acquire a lock in that table before running *any*
operation on this config, including the operation that would create the
table. `terraform/backend/` (see below) is the proper way to do this for a
*new* environment instead of repeating that manual dance.

## Environment promotion (Terragrunt)

One live stack (`terraform/live/banking-data/`), reused across
environments — account/region/state-location differences come from shell
env vars sourced from `environments/<env>.env`, not from separate
per-environment directories:

- `terraform/live/banking-data/terragrunt.hcl` reads `BACKEND_BUCKET`,
  `PREFIX_KEY`, `AWS_REGION`, `LOCK_TABLE` via `get_env(...)`, and merges
  `glue.json`/`lambda.json`/`buckets.json`/`eventbridge-rules.json` into its
  `inputs` (only the values that *don't* vary by environment).
- `environments/test.env` sets everything account/build-specific
  (`TF_VAR_environment`, `TF_VAR_artifact_bucket`, the three build S3 keys,
  `BACKEND_BUCKET`, etc.) for the real, already-deployed stack.
- `environments/prod.env` is a **placeholder**: there's no second AWS
  account yet, so every account-specific value (`assume_role_arn`,
  `BACKEND_BUCKET`, `artifact_bucket`, ...) points at something that doesn't
  exist. This is deliberate — running against `prod` fails loudly
  (AssumeRole / NoSuchBucket) instead of silently deploying "prod"
  resources into the test account.
- `terraform/modules/banking-data/providers.tf`'s `assume_role_arn`
  variable is what makes cross-account promotion possible once a real prod
  account exists.

To promote to a real second environment:

1. Bootstrap its backend: `cd terraform/backend && terraform init && terraform apply -var="environment=prod" -var="state_bucket_name=<globally-unique-name>"` (see that file's header comment for why this uses local state).
2. Fill in `environments/prod.env` with the real account ID, role ARN,
   bucket names, and build keys.
3. `make plan ENV=prod` — same command, same module, different account.

If more than one prod account is ever needed, add one file per account
(e.g. `123456789012_prod.env`) rather than overloading `prod.env`.
