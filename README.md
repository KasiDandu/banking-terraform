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
    │   ├── glue.json              # factory config: named Glue jobs
    │   ├── lambda.json            # factory config: named Lambda functions
    │   ├── buckets.json           # factory config: named S3 buckets
    │   ├── eventbridge-rules.json # factory config: EventBridge rules (array)
    │   └── banking-data.tfvars    # the one value that's truly constant: project_name
    └── modules/banking-data/      # the actual resources, split by AWS service
        ├── main.tf                # locals, state lock table, Glue Catalog + Athena, SSM
        ├── data.tf                # aws_caller_identity + all iam_policy_document data sources
        ├── buckets.tf             # S3 bucket factory + native S3->EventBridge notifications
        ├── lambda.tf              # Lambda function factory + EventBridge invoke permissions
        ├── glue.tf                # Glue job factory
        ├── eventbridge-rules.tf   # EventBridge rule/target factory
        ├── iam-roles.tf           # Lambda/Glue-job/crawler roles, policies, attachments
        ├── variables.tf / outputs.tf / versions.tf / providers.tf / backend.tf
        └── config/*.json          # per-source schema configs, uploaded to the config bucket
```

## Generic resource factories

`buckets.tf`/`lambda.tf`/`glue.tf`/`eventbridge-rules.tf` are `for_each`
factories over their matching JSON file in `terraform/live/banking-data/` —
adding a new bucket, Lambda, Glue job, or EventBridge rule is a JSON edit,
not a `.tf` edit:

- **`buckets.json`** — `{ with_terraform_buckets = { <key> = { bucket_suffix = "..." } } }`. Other resources reference a bucket by key, e.g. `aws_s3_bucket.this["landing"]`. This pipeline's roles: `landing` (S3 upload trigger source), `config` (per-source JSON), `processed` (Glue output), `athena` (query results).
- **`lambda.json`** — keyed by logical function name. A function's own `environment_variables` always apply; adding `glue_job_key` additionally wires in `CONFIG_BUCKET`/`GLUE_JOB_NAME`/`RAW_KEY_PREFIX`/`CONFIG_KEY_PREFIX` automatically (this is how `event_handler` knows which Glue job to start). Code location comes from `lambda_s3_keys[<key>]`, not this file (see "Build artifacts" below).
- **`glue.json`** — keyed by logical job name. `--DATA_BUCKET`/`--CRAWLER_ROLE_ARN`/`--TempDir`/`--extra-py-files` are always merged in on top of each job's own `default_arguments`. Script location comes from `glue_script_s3_keys[<key>]`.
- **`eventbridge-rules.json`** — a JSON *array* (each rule has its own `name`); converted to a map keyed by that name for `for_each`. A rule is either `bucket_key` (auto-builds an S3 "Object Created" pattern against that bucket, filtered by `raw_key_prefix` — this pipeline's real trigger) or a raw `event_pattern`/`schedule_expression`. `target` is either `function_key` (an internally-managed Lambda) or a direct external `arn` (e.g. a Step Function), with `role_arn` where the target service needs one.

The S3 upload trigger is native S3 → EventBridge "Object Created"
notifications (`aws_s3_bucket_notification` with `eventbridge = true` on the
landing bucket) — not a CloudTrail data-events trail. Cheaper, lower
latency, one less resource to manage. `banking-artifacts`'
`lambda_function.py` parses that event shape (`detail.bucket.name` /
`detail.object.key`, URL-decoded), not CloudTrail's.

### Build artifacts

`lambda_s3_keys` / `glue_script_s3_keys` are `map(string)` (keyed the same
as `lambda.json`/`glue.json`), separate from the structural JSON above
because they change every release. CI resolves them dynamically (see
`main.yaml`); `environments/test.env` pins a fallback snapshot for
local/manual runs via `${VAR:-default}`, which a pre-set CI value survives.
`glue_common_s3_key` is a single shared string — the same `--extra-py-files`
applies to every Glue job.

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
  (`TF_VAR_environment`, `TF_VAR_artifact_bucket`, the build S3 key maps,
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
