# Examples

Each subdirectory is a **root module** — a small, standalone Terraform
configuration that calls the module living one level up. That's what makes them
useful: the module itself can't be planned or applied on its own, because it has
no provider configuration and no backend. These directories supply both.

| Example | What it shows |
|---|---|
| `basic` | The minimum: one hostname, no logs, no analytics |
| `complete` | Extra hostnames, access logs, Athena queries, WAF tuning, a widened CSP |

## Running one

```sh
cd examples/basic

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: your AWS profile and your own domain

terraform init
terraform plan
```

`init` downloads the providers and links the module through its relative
`source = "../.."`. Because the path is relative, you're always planning the code
in your working copy — edit something in the module and re-run `plan`, no commit,
no tag, no cache to clear.

`profile`, `dns_profile` and `domain` deliberately have **no defaults**. Terraform
will stop and ask if you haven't set them, which is the point: nobody should be
able to apply an example against an account or a DNS zone they didn't
consciously choose. The remaining variables have harmless placeholder defaults.

`terraform.tfvars` is gitignored, so your values stay local. The `.example` file
next to it is committed and is the only thing that describes the shape.

If you actually apply, tear it down afterwards:

```sh
terraform destroy
```

Bear in mind CloudFront distributions take 10–15 minutes to delete, and the KMS
key created for the logs sticks around for its 7-day deletion window.

## Why the module can't just be planned directly

Run `terraform plan` at the repository root and you'll get an error about
undeclared provider configurations. That's by design. A reusable module declares
which providers it *needs* — here `aws.use1` and `aws.r53` — and the caller
supplies them. Putting `provider` blocks inside the module would make it
unusable by anyone whose credentials or regions differ from yours.

Which is exactly why these examples exist: they're the only place the module gets
exercised end to end.

## Checking them without an AWS account

```sh
terraform -chdir=examples/basic init -backend=false
terraform -chdir=examples/basic validate
```

`-backend=false` skips state setup and `validate` never talks to AWS, so this
catches syntax errors, bad references and type mismatches without credentials.
Worth wiring into CI for both examples.
