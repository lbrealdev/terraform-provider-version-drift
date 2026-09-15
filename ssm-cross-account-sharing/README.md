# Cross-Account SSM Parameter Store Sharing

This case demonstrates sharing SSM Parameter Store parameters across AWS accounts with Advanced-tier parameters, AWS RAM, and a customer managed KMS key.

## Context

Account A runs EC2 workloads. Account B is the shared-services account holding configuration in Parameter Store. Both accounts are in the same AWS Organization, and the workloads in account A need to read a handful of parameters owned by account B.

Parameters are private to their owning account by default. There is no "just add a resource policy" path the way there is for S3 or Secrets Manager — Parameter Store has no resource-based policy. Cross-account access is only possible through Parameter Store's AWS Resource Access Manager (RAM) integration, [launched February 2024](https://aws.amazon.com/blogs/mt/introducing-parameter-store-cross-account-sharing/).

The two failure modes below are the reason this case exists. Both fail in ways that point at the wrong component.

## Failed Attempt 1 — Standard tier parameters

The parameter simply is not shareable. RAM's resource type is *Parameter Store Advanced Parameters*: a Standard-tier parameter never appears as a selectable resource in the RAM console, and `associate-resource-share` rejects it outright. The AWS prerequisite is explicit:

> To share a parameter, it must be in the advanced parameter tier.

An existing Standard parameter can be promoted in place — no recreation, no new version. In Terraform that is a single argument:

```terraform
resource "aws_ssm_parameter" "config" {
  name  = "/shared-app/config"
  type  = "String"
  tier  = "Advanced"
  value = "https://api.example.internal"
}
```

Note the asymmetry: promoting Standard → Advanced is an in-place update, but *downgrading* back to `Standard` forces resource replacement. Promotion also introduces a per-API-call charge that Standard parameters do not have (see the cost note below).

## Failed Attempt 2 — Advanced tier alone

Advanced tier makes a parameter *eligible* for sharing. It does not grant anyone anything. Four further requirements have to be satisfied, and three of them fail quietly.

### 1. A RAM resource share must exist and list the parameters

Eligibility is not sharing. The owner needs `aws_ram_resource_share` plus one `aws_ram_resource_association` per parameter, and a principal association for the consumer:

```terraform
resource "aws_ram_resource_association" "parameters" {
  provider = aws.owner

  for_each = local.shared_parameter_arns

  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.parameters.arn
}
```

The principal here is the consumer's **IAM role ARN**, not its account ID, so no other identity in account A gains access. RAM's [shareable resources table](https://docs.aws.amazon.com/ram/latest/userguide/shareable.html) confirms `ssm:Parameter` can be shared with IAM users and roles. The registry documentation for `aws_ram_principal_association` still describes principals as only an account ID, an Organization ARN, or an OU ARN — that documentation lags the API, and the provider's own schema validation accepts any valid ARN.

### 2. `SecureString` needs a customer managed KMS key with a key policy

**This is the #1 silent failure.** The AWS managed `aws/ssm` key cannot be shared across accounts, so a `SecureString` encrypted with it is unreadable from the consumer account no matter what RAM says. The `String` and `StringList` parameters start working immediately, while the `SecureString` keeps returning `AccessDeniedException` — which reads like an SSM permissions problem but originates in KMS.

The RAM share never grants `kms:Decrypt`. The key has to authorize the consumer role itself:

```json
{
  "Sid": "AllowConsumerRoleToDecrypt",
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::222222222222:role/shared-app-ec2-parameter-reader" },
  "Action": ["kms:Decrypt", "kms:DescribeKey"],
  "Resource": "*"
}
```

Cross-account KMS access requires **both** sides to allow it: the key's resource policy in the owner account *and* the role's identity policy in the consumer account. Granting only one is not enough. Keep the `EnableOwnerAccountIAMPolicies` statement as well — omitting it makes the key unmanageable by the owner account's own IAM policies.

### 3. The consumer principal still needs its own IAM policy

RAM authorizes the resource; IAM still gates the API call. Both must allow. `ssm:DescribeParameters` is the trap: it supports **no resource-level permissions**, so it must be granted on `"*"`. Scoping it to a parameter ARN denies the call silently, and AWS's own [Setting up Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-setting-up.html) guidance splits it into its own statement for exactly this reason.

```json
{
  "Sid": "ListSharedParameters",
  "Effect": "Allow",
  "Action": "ssm:DescribeParameters",
  "Resource": "*"
}
```

The reads themselves are scoped to the owner-account ARN prefix, `arn:aws:ssm:us-east-1:111111111111:parameter/shared-app/*`. A wildcard over the prefix mirrors how teams actually grant access to a shared path, keeps the policy readable, and means adding a fourth parameter under the prefix needs no IAM change. The trade-off is that the policy no longer enumerates exactly what the share exposes — but RAM is the authoritative gate and it lists the three parameters explicitly, so the wildcard cannot over-grant beyond what is shared. To tighten it to per-parameter ARNs instead:

```terraform
Resource = [for arn in local.shared_parameter_arns : arn]
```

### 4. Reads must use the full ARN

The short name resolves against the *caller's* account and returns `ParameterNotFound`:

```shell
# Fails from the consumer account
aws ssm get-parameter --name /shared-app/config

# Works
aws ssm get-parameter --name arn:aws:ssm:us-east-1:111111111111:parameter/shared-app/config
```

The same applies in Terraform — `data.aws_ssm_parameter` takes the owner's ARN as its `name`.

## The Correct Recipe

| Step | Side | Terraform resource |
|---|---|---|
| Create a customer managed key, grant `kms:Decrypt` to the consumer role | owner | `aws_kms_key.parameters`, `aws_kms_alias.parameters` |
| Store parameters in the Advanced tier | owner | `aws_ssm_parameter.config` / `.features` / `.secret` |
| Create the resource share with the read-only managed permission | owner | `aws_ram_resource_share.parameters` |
| Add each parameter to the share | owner | `aws_ram_resource_association.parameters` |
| Grant the consumer role as principal | owner | `aws_ram_principal_association.consumer_role` |
| Create the EC2 instance role | consumer | `aws_iam_role.parameter_reader`, `aws_iam_instance_profile.parameter_reader` |
| Allow the SSM reads and the KMS decrypt | consumer | `aws_iam_role_policy.parameter_reader` |
| Read by full owner ARN | consumer | `data.aws_ssm_parameter.shared_config` / `.shared_secret` |

Both halves live in one directory here, wired through two aliased providers (`aws.owner`, `aws.consumer`), so the owner↔consumer relationship is readable in a single file. There is no default provider block, so **every** resource and data block names its provider explicitly. A real deployment would typically split the two halves into separate workspaces applied with different credentials, since one set of credentials rarely has admin in both accounts.

## Parameter Type Matrix

| Type | Advanced tier | Customer managed KMS key | Consumer `kms:Decrypt` | Read notes |
|---|---|---|---|---|
| `String` | required | not applicable | not needed | plain value |
| `StringList` | required | not applicable | not needed | comma-separated; use `split(",", ...)` |
| `SecureString` | required | **required** — `aws/ssm` cannot be shared | **required**, via the key policy *and* the consumer IAM policy | `with_decryption = true` |

A `StringList` reads identically to a `String`; only the caller-side parsing differs:

```terraform
locals {
  feature_flags = split(",", data.aws_ssm_parameter.shared_features.value)
}
```

## Same-Org vs Cross-Org

The primary example is same-organization sharing with RAM sharing with AWS Organizations enabled: `allow_external_principals = false`, the association is automatic, and there is no invitation to accept and no `aws_ram_resource_share_accepter`.

For a consumer outside the organization, set `allow_external_principals = true` on the share; the consumer then has to accept the invitation:

```terraform
resource "aws_ram_resource_share_accepter" "parameters" {
  provider = aws.consumer

  share_arn = aws_ram_resource_share.parameters.arn
}
```

If RAM sharing with AWS Organizations is *not* enabled, even same-org account principals receive an invitation, so the accepter is needed there too.

## Read-Only Semantics and Other Constraints

- Consumers get `DescribeParameters`, `GetParameter`, and `GetParameters`, plus `GetParameterHistory` with the `AWSRAMPermissionSSMParameterReadOnlyWithHistory` permission set. They cannot update, delete, or re-share the parameters.
- `GetParametersByPath` is not in either managed permission set and does not accept cross-account ARNs, so `aws_ssm_parameters_by_path` will not work against shared parameters. Enumerate the ARNs instead — this config uses `data "aws_ssm_parameter"` only.
- Reserved namespaces cannot be shared: names beginning with `aws` or `ssm` are rejected, hence the neutral `/shared-app/` prefix.
- Owner and consumer must be in the **same region**. Parameter Store sharing is not cross-region.
- If the owner account is closed, consumers lose access; it is recoverable within 90 days.
- The supported-integration list is narrow. Shared parameters work with CloudFormation template parameters, the Parameters and Secrets Lambda extension, EC2 launch templates, `ImageId` for `RunInstances`, and Automation runbooks — but **not** with Run Command, CloudFormation dynamic references, CodeBuild or App Runner environment variables, or ECS secrets.

## Prerequisites Not Represented in This Config

- **RAM sharing with AWS Organizations must be enabled.** This is done once in the organization's management account — a third account outside this two-account model. `aws_ram_sharing_with_organization` exists in the provider but belongs to that management account, so it is deliberately not part of this configuration. The Terraform here is not self-sufficient without it.
- **The managed RAM permission ARN spelling.** The AWS Systems Manager user guide names it `AWSRAMDefaultPermissionSSMParameterReadOnly` (singular "Permission"); some third-party write-ups use the plural form. This config uses the AWS documentation spelling, exposed as `var.ram_permission_arn`. Omitting `permission_arns` altogether makes RAM attach the correct default for `ssm:Parameter` automatically, which is the safer choice when adapting this for real use.

## Architecture Note — Would Secrets Manager Be Better?

Even-handed comparison, since this is a fair question to raise for the `SecureString` half of the problem:

- **Secrets Manager is structurally simpler for cross-account access.** It has supported it since day one through a resource-based policy on the secret (`aws_secretsmanager_secret_policy`). No RAM, no tier upgrade, no invitation, no resource-share lifecycle to manage — meaningfully fewer moving parts.
- **But the KMS constraint is identical.** Cross-account secret access also requires a customer managed key; the AWS managed `aws/secretsmanager` key cannot be used across accounts. Migrating would not eliminate the single hardest part of this setup, which is the two-sided KMS grant.
- **Secrets Manager adds capabilities** Parameter Store lacks: built-in rotation, a 64 KB value limit, and much broader native service integration — including the ECS, CodeBuild, and App Runner cases that shared parameters explicitly do not support.
- **Cost, stated plainly.** An Advanced parameter is USD 0.05 per parameter per month plus USD 0.05 per 10,000 API calls; the owner pays storage and each consuming account pays for its own calls. A Secrets Manager secret is roughly USD 0.40 per secret per month plus API charges. Note that promoting Standard → Advanced introduces a per-API-call charge that did not exist before, which is easy to overlook at scale.

**Conclusion.** Given a stack already fully on Parameter Store, where the shared data is mostly configuration (`String` / `StringList`) with a single `SecureString`, staying on Parameter Store + RAM is defensible and avoids a migration. If the number of genuine secrets grows, or if rotation or ECS/CodeBuild integration is needed, Secrets Manager is the better home for *those specific values*. A mixed estate — configuration in Parameter Store, rotating secrets in Secrets Manager — is a legitimate outcome, not a failure.

## Validation

```shell
terraform -chdir=ssm-cross-account-sharing init -backend=false
terraform -chdir=ssm-cross-account-sharing validate
terraform -chdir=ssm-cross-account-sharing fmt -check -recursive
```

Or with the repository's recipes:

```shell
just validate ssm-cross-account-sharing
just fmt ssm-cross-account-sharing
```

**This case is never applied against a real cloud.** Every account ID, role ARN, and parameter value is a placeholder, and the two data sources are illustrative — their `depends_on` blocks defer evaluation to apply time, which never happens here. Unlike the S3 case in this repository, there is no captured `plan` or `apply` output, because none was produced; every requirement documented above comes from AWS documentation and provider source rather than from an executed end-to-end reproduction.

A real apply would require: enabling RAM sharing with AWS Organizations in the management account, substituting real account IDs and assume-role ARNs, and in practice splitting the owner and consumer halves into separate workspaces applied with separate credentials.

## Files

- `main.tf` - Owner and consumer configuration: KMS key, Advanced-tier parameters, RAM share and associations, consumer IAM role and policy, illustrative data sources
- `variables.tf` - Input variables for region, placeholder account IDs and assume-role ARNs, parameter prefix, consumer role name, and RAM permission ARN
- `versions.tf` - AWS provider version constraints
- `README.md` - Failure modes, correct recipe, constraints, and the Secrets Manager comparison

## Reference

- [Working with shared parameters](https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-shared-parameters.html) - AWS prerequisites, constraints, and supported integrations
- [Introducing Parameter Store cross-account sharing](https://aws.amazon.com/blogs/mt/introducing-parameter-store-cross-account-sharing/) - Launch announcement, February 2024
- [Shareable AWS resources](https://docs.aws.amazon.com/ram/latest/userguide/shareable.html) - Confirms `ssm:Parameter` can be shared with IAM users and roles
- [Setting up Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-setting-up.html) - Recommended policy shape, including `ssm:DescribeParameters` on `"*"`
- [Service authorization reference for Systems Manager](https://docs.aws.amazon.com/service-authorization/latest/reference/list_ssm.html) - Which SSM actions support resource-level permissions
- [`aws_ssm_parameter`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) - Parameter resource, including `tier` and `key_id`
- [`aws_ram_resource_share`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) - RAM resource share
- [`aws_ram_resource_association`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) - Associates a resource with a share
- [`aws_ram_principal_association`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) - Associates a principal with a share
- [`aws_kms_key`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) - Customer managed KMS key and key policy
