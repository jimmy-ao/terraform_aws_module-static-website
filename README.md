# terraform_aws_module-static-website

A Terraform module to host a static website on AWS. You get a private S3 bucket,
a CloudFront distribution in front of it, an HTTPS certificate, and the DNS
records to tie the whole thing together. Access logging and a WAF come along for
the ride, and you can switch both off.

Nothing is ever served straight from S3 🔒 — the bucket blocks all public access
and CloudFront reaches it through an Origin Access Control, so the distribution
is the only way in.

## What gets created

- A private S3 bucket for your files, versioned and encrypted
- A CloudFront distribution, HTTP redirected to HTTPS, with a solid set of
  security headers (HSTS, CSP, X-Frame-Options, Referrer-Policy)
- An ACM certificate in us-east-1, validated over DNS
- Route 53 A and AAAA alias records for every hostname you serve
- A WAF web ACL with a rate limit and three AWS managed rule groups (optional)
- CloudFront standard logging v2, delivered to a second bucket as Parquet (optional)
- An Athena database, a Glue table and six ready-made queries over those logs (optional)

## Before you start

You'll need a **public Route 53 hosted zone** for your domain, already up and
actually answering for it. The module looks the zone up by name and drops records
into it — it won't create the zone for you.

Credentials and regions aren't the module's business, they're set in the calling
code. Three provider configurations are expected:

| Provider | What it's for |
|---|---|
| default | Everything regional: buckets, KMS, Athena |
| `aws.use1` | Has to be us-east-1. CloudFront certificates, WAF and log delivery only live there |
| `aws.r53` | Whichever account owns the hosted zone |

If your DNS sits in the same account as the rest, just pass your default provider
for `aws.r53` too. The alias is there so a shared DNS account is *possible*, not
because you need one.

Terraform 1.15+, AWS provider 6.x.

## Usage

```hcl
provider "aws" {
  region = "eu-north-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

module "website" {
  source = "github.com/archnops/terraform_aws_module-static-website?ref=v1.0.0"

  providers = {
    aws      = aws
    aws.use1 = aws.use1
    aws.r53  = aws
  }

  environment = "prd"
  project     = "corporate-site"
  app         = "www"
  domain      = "example.com"
}
```

That puts the site on `https://www.example.com` — the hostname is stitched
together from `app` and `domain`. Want more names? List them in `sub_domains` and
they'll each land on the certificate with their own DNS records.

With logs and queries switched on:

```hcl
module "website" {
  # ...

  logging = {
    enabled        = true
    retention_days = 90
  }

  analyzing = {
    enabled = true
  }
}
```

## Examples

Two runnable configurations live under [`examples/`](examples/):

| Example | What it shows |
|---|---|
| [`basic`](examples/basic) | The minimum: one hostname, no logs, no analytics |
| [`complete`](examples/complete) | Extra hostnames, access logs, Athena queries, WAF tuning, a widened CSP |

They're the only place the module actually gets exercised — it can't be planned
on its own, since it deliberately ships no provider configuration. Copy one as a
starting point, or use it to try a change before committing:

```sh
cd examples/basic
cp terraform.tfvars.example terraform.tfvars   # then fill in your details
terraform init
terraform plan
```

No AWS account handy? This checks the syntax and references without ever calling
AWS:

```sh
terraform -chdir=examples/basic init -backend=false
terraform -chdir=examples/basic validate
```

## 🚀 Getting your site online

Terraform creates the bucket, but it never touches what's inside. That part's on
you:

```sh
aws s3 sync ./public "s3://$(terraform output -raw web_bucket_id)/" --delete

aws cloudfront create-invalidation \
  --distribution-id "$(terraform output -raw cloudfront_id)" \
  --paths '/*'
```

Don't skip the invalidation. CloudFront caches hard, and without it your visitors
will happily keep seeing yesterday's files for hours. The module does invalidate
by itself when the *distribution* changes, but it has no idea you just uploaded
something.

One more thing: double-check that your error page actually exists in the bucket.
No `error.html`, and anyone hitting a dead link gets CloudFront's ugly default
page instead of yours.

## Inputs

The ones you have to provide:

| Name | What it does |
|---|---|
| `environment` | One of `prd`, `npe`, `uat`, `lab`, `tst`, `sbx`. Shows up in resource names |
| `project` | Project name, used for tagging |
| `app` | Application name — also the first label of your hostname |
| `domain` | Your apex domain, matching the Route 53 hosted zone |

The optional ones worth knowing about:

| Name | Default | What it does |
|---|---|---|
| `sub_domains` | `[]` | Extra hostnames to serve. They have to sit inside `domain` |
| `cloudfront_index_document` | `index.html` | Served at the site root |
| `cloudfront_error_document` | `error.html` | Served when a page can't be found |
| `cloudfront_error_caching_min_ttl` | `10` | Seconds CloudFront caches an error before retrying the origin |
| `cloudfront_price_class` | `PriceClass_All` | `PriceClass_100` is cheaper and covers North America and Europe |
| `cloudfront_content_security_policy_directives` | strict `'self'` policy | Read the warning below first |
| `cloudfront_hsts` | 1 year, subdomains, preload on | Read the warning below first |
| `waf` | on | `enabled = false` to skip it, or hand it a `web_acl_arn` to reuse one you already have |
| `logging` | off | `{ enabled = true }` and you get access logs |
| `analyzing` | off | Athena and Glue over those logs. Needs `logging` on |

`terraform-docs markdown .` spits out the full list if you need the
geo-restriction, TLS or WAF tuning knobs.

## Outputs

| Name | What you get |
|---|---|
| `website_url` | The HTTPS URL your site answers on |
| `web_bucket_id` | Bucket name — this is where your files go |
| `web_bucket_arn` | Handy for granting a pipeline write access |
| `cloudfront_id` | Distribution ID, needed for cache invalidations |
| `cloudfront_domain_name` | The `dxxxx.cloudfront.net` one |
| `cloudfront_arn`, `cloudfront_hosted_zone_id`, `cloudfront_aliases` | |
| `acm_certificate_arn` | |
| `waf_web_acl_arn` | `null` when the WAF is off |
| `logs_bucket_id`, `logs_bucket_arn`, `logs_kms_key_arn` | `null` when logging is off |
| `athena_workgroup_name`, `glue_table_name` | `null` when analyzing is off |

## ⚠️ Things that will bite you

**The default CSP blocks inline scripts.** `script-src 'self'` is the right call
security-wise, but most modern site builders inline a bootstrap script, and
analytics snippets are inline by definition. Blank page plus console errors about
Content Security Policy? That's this. Override
`cloudfront_content_security_policy_directives` with what your site really needs
— but try hard not to reach for `'unsafe-inline'`, it throws away most of the
benefit.

**HSTS preload is a one-way door, and it's on by default.** Once your domain is
on the browser preload list, getting off takes months, and until then every
browser flat-out refuses plain HTTP on your domain *and every subdomain under
it*. Got an internal subdomain still on HTTP? It'll break. Go with
`cloudfront_hsts = { preload = false }` if you're not completely sure.

**The WAF isn't free.** Somewhere around ten dollars a month per distribution
before request charges, and it's enabled by default. If a managed rule starts
blocking real visitors, don't kill the whole group — flip just that rule to count
mode with `waf.rule_overrides`.

**Logs take their sweet time.** AWS says logging changes take effect within 12
hours, so an empty bucket an hour after `apply` is perfectly normal. Go do
something else.

**Athena needs one manual check before you trust it.** The Glue table columns are
derived from the log fields you asked for, assuming AWS normalises the names a
certain way (`cs(Host)` → `cs_host`, and so on). That assumption isn't documented
anywhere. So: turn on `logging` first, wait for real files to land, crack one
open, *then* turn on `analyzing`. If the names don't match, feed the right ones
through `analyzing.columns` rather than editing the module.

**S3 answers 403, not 404.** Behind an Origin Access Control, a missing object
comes back as access-denied. That's why the module maps 403 to your error page and
returns a 404 status, and why there's no separate 404 rule.

## 💸 What it costs, roughly

For a small site most of the bill is fixed: the Route 53 hosted zone, plus the
WAF if you keep it. S3 storage and CloudFront traffic are pocket change at low
volume. Logging adds a KMS key and some storage; Athena bills per query, capped
by `analyzing.bytes_scanned_cutoff`. The one that can genuinely surprise you at
scale is `cloudfront_price_class` — `PriceClass_All` serves from every edge
location on the planet, including the pricey ones.

## License

See [LICENSE](LICENSE).
