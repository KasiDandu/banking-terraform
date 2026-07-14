# banking-terraform

Terraform + Terragrunt project for the banking-data pipeline's AWS
infrastructure, split into three independently-deployable modules. CI runs
via the `Terraform` GitHub Actions workflow on the self-hosted EC2 runner
(see the `ec2-runner` repo).

## Layout

```
banking-terraform/
├── .github/workflows/main.yaml   # foundation-apply -> plan -> approve -> apply/destroy
├── Makefile                       # make foundation-plan|foundation-apply|plan|apply|destroy-plan|destroy ENV=test|prod
├── deploys/
│   └── Makefile                   # sources environments/<ENV>.env, drives terragrunt
├── environments/
│   ├── test.env                   # real -- points at the deployed test stack
│   ├── prod.env                   # placeholder -- see "Environment promotion" below
│   └── Makefile                   # `make validate` / `make list`
└── terraform/
    ├── backend/                   # one-time bootstrap: state bucket + lock table
    │   └── main.tf                # (local state -- can't depend on the backend it creates)
    ├── live/                      # Terragrunt roots, one per module, siblings
    │   ├── banking-data.tfvars    # sha256 artifact version pins for the banking-data module (CI overwrites this per run)
    │   ├── buckets/
    │   │   ├── terragrunt.hcl
    │   │   └── buckets.json       # factory config: named S3 buckets
    │   ├── iam/
    │   │   └── terragrunt.hcl     # no JSON -- nothing environment-tunable to configure
    │   └── banking-data/
    │       ├── terragrunt.hcl     # dependencies{} on buckets, dependency{} on iam; -var-file points at ../banking-data.tfvars
    │       ├── glue.json          # factory config: named Glue jobs
    │       ├── lambda.json        # factory config: named Lambda functions
    │       └── eventbridge-rules.json  # factory config: EventBridge rules (array)
    └── modules/                   # one Terraform module per Terragrunt root, same names
        ├── buckets/                # S3 bucket factory + SSM params + landing bucket EventBridge notification
        ├── iam/                    # Lambda/Glue-job/crawler roles + baseline managed policy only
        └── banking-data/           # Lambda/Glue/EventBridge -- the actual pipeline logic
            ├── main.tf             # locals, Glue Catalog + Athena, SSM (glue job names)
            ├── data.tf             # SSM bucket lookups + all iam_policy_document data sources
            ├── lambda.tf           # Lambda function factory + EventBridge invoke permissions
            ├── glue.tf             # Glue job factory
            ├── eventbridge-rules.tf   # EventBridge rule/target factory
            ├── iam-roles.tf        # attaches this module's own policies to the iam module's roles
            ├── variables.tf / outputs.tf / versions.tf / providers.tf / backend.tf
            └── config/*.json       # per-source schema configs, uploaded to the config bucket
```

## Three modules, not one

**`buckets`** creates the S3 buckets (`landing`/`config`/`processed`/`athena`)
and publishes each bucket's name to SSM Parameter Store
(`/<project>/<env>/buckets/<key>`) plus enables native S3 → EventBridge
"Object Created" notifications on `landing`.

**`iam`** creates the Lambda/Glue-job/crawler roles — trust policy +
baseline AWS-managed service-role policy only. It doesn't know or care what
those roles will actually be allowed to touch.

**`banking-data`** is the pipeline itself (Lambda, Glue, EventBridge, Glue
Catalog/Athena). It doesn't create buckets or roles — it:
- looks up bucket names via `data "aws_ssm_parameter"` (loose coupling to
  `buckets`; no Terragrunt dependency needed for that unit specifically,
  though `banking-data/terragrunt.hcl` still declares a `dependencies {}`
  block on it purely for **apply ordering** — the SSM parameters must exist
  in AWS, not just be planned, before this module's data sources can read
  them), and
- attaches its **own** service-specific `aws_iam_role_policy` resources to
  the role names/ARNs the `iam` module created, wired in via a Terragrunt
  `dependency "iam" { ... }` block.

This means adding a new bucket, Lambda, Glue job, or EventBridge rule is a
JSON edit in `terraform/live/<module>/`, not a `.tf` edit — see each
module's own JSON file for its shape (`buckets.json`, `lambda.json`,
`glue.json`, `eventbridge-rules.json`).

### A real gotcha this surfaced: mock outputs and saved plans don't mix

`banking-data`'s `dependency "iam"` block sets
`mock_outputs_allowed_terraform_commands = ["validate"]` — deliberately
**not** `"plan"`. Early on this said `["validate", "plan"]`, and a
`terragrunt plan` run before `iam` had ever been applied happily produced a
plan using mock role names/ARNs. That's fine for `plan` alone, but this
repo's whole CI safety model is "save the plan, get it approved, apply
*that exact file* later" — and `terraform apply <planfile>` replays exactly
what was in the file, mock values included, ignoring whatever the *real*
environment variables say by apply time. The result: an attempt to attach
an IAM policy to a role literally named `mock-glue-job-role`, which of
course doesn't exist. Fixed by restricting mocks to `validate` only, so any
`plan` that could later be saved and applied is forced to use `iam`'s real
outputs — which just means `iam` must already be applied first, which it
always is in the normal flow (see below).

### The S3 upload trigger

Native S3 → EventBridge "Object Created" notifications (`buckets` module),
not a CloudTrail data-events trail — cheaper, lower latency, one less
resource to manage. `banking-artifacts`'s `lambda_function.py` parses that
event shape (`detail.bucket.name` / `detail.object.key`, URL-decoded), not
CloudTrail's.

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
make foundation-apply ENV=test   # buckets + iam -- low-risk, idempotent, applies directly
make plan ENV=test               # banking-data only -- the reviewable unit
make apply ENV=test              # (or destroy-plan / destroy)
```

`ENV` selects `environments/<ENV>.env`, sourced (as `TF_VAR_*` plus
`BACKEND_BUCKET`/`PREFIX_KEY`/`AWS_REGION`/`LOCK_TABLE`) before Terragrunt
runs. `PREFIX_KEY` is a *prefix*, not a full state key — each of the three
sibling units appends its own `<unit>/terraform.tfstate` under it, so they
share one backend bucket and lock table without colliding. `make fmt`
formats both the `.tf` files and the Terragrunt HCL.

## Running via GitHub Actions

Trigger the `Terraform` workflow (`workflow_dispatch`) with:
- `environment` — `test` or `prod`
- `action` — `plan`, `apply`, or `destroy`
- `confirm_destroy` — required, must be exactly `destroy`, when `action=destroy`

The `plan` job always applies `buckets`+`iam` directly first (foundational,
idempotent, no business logic — see above), then plans (or destroy-plans)
`banking-data` and uploads that as an artifact. `apply`/`destroy` download
that exact plan and apply it in a second job gated by the `production`
GitHub Environment — requires manual approval, so the one unit with actual
pipeline logic never changes unattended. Requires repo secrets
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` and repo variables
`AWS_REGION` / `ARTIFACT_BUCKET`.

## State locking

The S3 backend uses a DynamoDB table (`dynamodb_table`, wired from
`LOCK_TABLE`) so concurrent `plan`/`apply` runs fail fast on a lock conflict
instead of racing and corrupting state. All three units share the same
table — one lock table safely serves many state files, since the lock ID
incorporates the full state path. It had to be created once via the AWS
CLI and imported into the (now-removed) module that used to own it — the
backend needs to acquire a lock in that table before running *any*
operation on a config, including the operation that would create the table
itself. `terraform/backend/` (see below) is the proper way to do this for a
*new* environment instead of repeating that manual dance.

## Environment promotion (Terragrunt)

One live stack per module (`terraform/live/{buckets,iam,banking-data}/`),
each reused across environments — account/region/state-location
differences come from shell env vars sourced from `environments/<env>.env`,
not from separate per-environment directories:

- Each unit's `terragrunt.hcl` reads `BACKEND_BUCKET`, `PREFIX_KEY`,
  `AWS_REGION`, `LOCK_TABLE` via `get_env(...)`.
- `environments/test.env` sets everything account-specific
  (`TF_VAR_environment`, `TF_VAR_artifact_bucket`, `BACKEND_BUCKET`, etc.)
  for the real, already-deployed stack.
- `environments/prod.env` is a **placeholder**: there's no second AWS
  account yet, so every account-specific value (`assume_role_arn`,
  `BACKEND_BUCKET`, `artifact_bucket`, ...) points at something that doesn't
  exist. This is deliberate — running against `prod` fails loudly
  (AssumeRole / NoSuchBucket) instead of silently deploying "prod"
  resources into the test account.
- The build's sha256 artifact keys (`lambda_s3_keys`, `glue_script_s3_keys`,
  `glue_common_s3_key`) are *not* env-specific — they come from
  `terraform/live/banking-data.tfvars` via the banking-data unit's
  `extra_arguments "-var-file"`, shared across environments since the same
  build has the same content hash regardless of which account's artifact
  bucket it's promoted into. A `-var-file` outranks `TF_VAR_*`, so CI
  overwrites that one file with the latest build's keys before planning
  instead of exporting env vars.
- Each module's `providers.tf`'s `assume_role_arn` variable is what makes
  cross-account promotion possible once a real prod account exists.

To promote to a real second environment:

1. Bootstrap its backend: `cd terraform/backend && terraform init && terraform apply -var="environment=prod" -var="state_bucket_name=<globally-unique-name>"` (see that file's header comment for why this uses local state).
2. Fill in `environments/prod.env` with the real account ID, role ARN,
   bucket names, and build keys.
3. `make foundation-apply ENV=prod && make plan ENV=prod` — same commands,
   same modules, different account.

If more than one prod account is ever needed, add one file per account
(e.g. `123456789012_prod.env`) rather than overloading `prod.env`.
