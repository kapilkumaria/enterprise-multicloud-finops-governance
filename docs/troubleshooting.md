# Troubleshooting

## 1. Overview

This document records significant implementation and validation issues encountered while building the Enterprise Multi-Cloud FinOps, Governance & Controlled Remediation Platform.

The purpose of this document is to preserve:

- symptoms;
- root causes;
- troubleshooting approach;
- resolution;
- engineering lessons.

The issues span:

- Terraform;
- AWS;
- Azure;
- GitHub Actions;
- OpenID Connect federation;
- Checkov;
- Infracost;
- cost reporting;
- runtime compliance;
- controlled remediation;
- evidence management;
- shell automation.

The troubleshooting process followed a consistent model:

```text
Observe Failure
      |
      v
Collect Evidence
      |
      v
Isolate Layer
      |
      v
Identify Root Cause
      |
      v
Apply Minimal Fix
      |
      v
Re-Test
      |
      v
Validate No Regression
```
---

## 2. Troubleshooting Principles

The project followed several troubleshooting principles.

- Do not change multiple layers simultaneously.
- Validate local scripts before debugging CI/CD.
- Separate authentication failures from authorization failures.
- Separate Terraform desired state from live cloud state.
- Treat intentional governance failures differently from implementation failures.
- Preserve failed test cases as evidence where appropriate.
- Re-run zero-drift validation after remediation.
- Avoid exposing sensitive cloud identifiers during troubleshooting.
- Prefer reproducible shell and Terraform checks over manual console inspection.

---

## 3. Checkov Returned a Non-Zero Exit Code

### Symptom

An initial Checkov validation returned multiple failed checks and a non-zero exit code.

The sample validation showed both:

- passed checks;
- failed checks.

### Root Cause

The test Terraform resource was intentionally minimal.

Checkov correctly identified missing security and governance controls such as:

- versioning;
- logging;
- public-access protection;
- replication-related controls.

The non-zero exit code represented policy failure, not a Checkov installation problem.

### Resolution

The output was interpreted as expected policy behavior.

The test confirmed that Checkov was functioning correctly.

### Lesson

A security scanner returning a non-zero exit code does not necessarily indicate a broken pipeline.

The first troubleshooting question should be:

`Did the tool fail to execute, or did it successfully detect a policy violation?`

---

## 4. Distinguishing Expected Governance Failure From Pipeline Failure

### Symptom

Negative-path fixtures intentionally caused governance jobs to fail.

At first glance, these failures can look identical to implementation defects.

### Root Cause

The repository deliberately contains invalid examples for:

- disallowed regions;
- missing mandatory tags;
- excessive modeled cost;
- invalid remediation requests.

The expected outcome for these fixtures is:

`FAIL`

### Resolution

Governance validation was evaluated against expected outcomes rather than assuming every successful test must return exit code zero.

### Lesson

A governance platform must prove both:

- valid input passes;
- invalid input fails.

A failed negative-path test can represent a successful governance control.

---

## 5. AWS Region Policy Violation

### Symptom

Terraform configuration targeting a region other than the approved AWS region was rejected.

### Root Cause

The project explicitly restricts AWS deployments to:

`us-east-1`

The test fixture intentionally violated this policy.

### Resolution

The compliant configuration was kept in:

`us-east-1`

The violation fixture remained in the repository for negative-path testing.

### Lesson

Governance tests should preserve invalid fixtures rather than deleting them after validation.

They provide reproducible evidence that policy enforcement works.

---

## 6. Azure Region Policy Violation

### Symptom

Terraform configuration targeting a non-approved Azure region failed governance.

### Root Cause

The platform restricts Azure deployment to:

`canadacentral`

The test fixture intentionally targeted another region.

### Resolution

The production baseline remained in:

`canadacentral`

The invalid fixture remained under:

`examples/violations/azure-disallowed-region/`

### Lesson

Cloud-region governance should be tested independently for each provider rather than assuming equivalent behavior.

---

## 7. Missing Mandatory Tags

### Symptom

Governance validation failed when required metadata was absent.

### Root Cause

The project requires:

- `Project`;
- `Environment`;
- `Owner`;
- `CostCenter`;
- `BusinessUnit`;
- `DataClassification`.

The violation fixture intentionally removed required tags.

### Resolution

The compliant baseline was updated or validated with the complete mandatory-tag set.

Negative fixtures were retained for CI/CD testing.

### Lesson

Tagging should be treated as policy rather than documentation.

Required metadata must be executable and testable.

---

## 8. Cost Threshold Violation

### Symptom

A test Terraform configuration failed the FinOps policy stage.

### Root Cause

The modeled infrastructure cost exceeded the configured threshold.

The project thresholds are:

AWS: `25`;
Azure: `100`.

### Resolution

The compliant baseline was kept below the approved thresholds.

Separate high-cost fixtures were retained to prove the failure path.

### Lesson

Cost governance is strongest when implemented as an enforceable CI/CD gate rather than an informational report.

---

## 9. Infracost Installation and Initial Validation

### Symptom

During the initial tooling setup, Infracost installation or first execution required validation before it could be trusted in the governance pipeline.

### Troubleshooting

The troubleshooting approach was:

- confirm the executable was available;
- confirm the version;
- validate the project configuration;
- test cost estimation independently of GitHub Actions;
- only then integrate the tool into CI/CD.

### Resolution

Infracost was successfully integrated through:

`infracost.yml`

and later used for AWS and Azure modeled cost validation.

### Lesson

External CLI dependencies should be validated locally before pipeline integration.

This isolates installation problems from workflow problems.

---

## 10. Modeled Cost Differed From Provider Billing

### Symptom

Infracost showed modeled monthly infrastructure cost while provider-native cost reports showed little or no cost.

### Root Cause

The two data sources measure different things.

####  Infracost provides:

`modeled future infrastructure cost`

Provider billing APIs provide:

`recorded historical consumption`

Cloud billing data can also lag behind recently created resources.

### Resolution

The project deliberately separated:

- modeled cost;
- governance threshold;
- provider-native cost.

### Lesson

Modeled infrastructure pricing should never be presented as if it were a finalized cloud invoice.

---

## 11. Provider Cost Report Returned Zero

### Symptom

AWS or Azure native cost reporting could return:

`0`

even though infrastructure had recently existed.

### Root Cause

Cloud billing APIs can have ingestion and processing delay.

Recently created resources may not appear immediately in billing data.

### Resolution

The zero-cost provider result was preserved as actual provider evidence for that reporting window.

Modeled cost evidence remained separate.

### Lesson

Billing lag is normal operational behavior.

A FinOps implementation should preserve the reporting timestamp and avoid interpreting short-term zero billing as proof of zero infrastructure cost.

---

## 12. AWS and Azure Used Different Billing Currencies

### Symptom

AWS and Azure cost evidence could not be safely combined into one numerical multi-cloud total.

### Root Cause

The provider-native reports used different currencies.

AWS evidence used:

`USD`

Azure provider-native evidence could use:

`CAD`

Directly calculating:

`USD + CAD`

would be financially incorrect.

### Resolution

The multi-cloud summary preserved provider-specific cost and currency values.

No artificial cross-currency total was created.

### Lesson

Multi-cloud cost aggregation requires explicit currency normalization.

Without a defined exchange-rate strategy, preserving native currencies is more accurate.

---

## 13. Provider-Aware Terraform Planning Required Cloud Authentication

### Symptom

Some Terraform planning and resolved-cost operations required live provider access.

### Root Cause

Certain Terraform data sources and provider-resolved values cannot be evaluated from static configuration alone.

### Resolution

A dedicated Resolved Cost Governance workflow was created.

The workflow uses GitHub OIDC to authenticate to:

- AWS;
- Azure.

It then performs provider-aware Terraform planning before Infracost evaluation.

### Lesson

Static analysis and provider-resolved planning solve different problems.

Both are useful governance layers.

---

## 14. Avoiding Static AWS Credentials in GitHub Actions

### Symptom

GitHub Actions required AWS authentication for resolved planning and remediation.

A traditional implementation could have required:

`AWS_ACCESS_KEY_ID`

and:

`AWS_SECRET_ACCESS_KEY`

### Risk

Long-lived CI/CD credentials create:

- rotation overhead;
- secret leakage risk;
- wider persistence after compromise.

### Resolution

GitHub OIDC federation was implemented.

AWS workflows assume IAM roles using short-lived credentials.

### Lesson

OIDC should be preferred for modern GitHub-to-cloud authentication whenever supported.

---

## 15. Avoiding Azure Client Secrets

### Symptom

Azure workflows required authenticated access for planning and remediation.

### Risk

Using an Azure client secret would introduce another long-lived CI/CD secret.

### Resolution

Microsoft Entra federated identity credentials were configured for GitHub OIDC.

No workflow requires:

`AZURE_CLIENT_SECRET`

### Lesson

Federated identity reduces secret-management burden and makes CI/CD trust more explicit.

---

## 16. Authentication Worked but Authorization Still Required Validation

### Symptom

A workflow could authenticate successfully through OIDC but still lack permission to perform a cloud operation.

### Root Cause

Authentication and authorization are separate.

### OIDC proves:

`who the workflow is`

IAM or Azure RBAC controls:

`what the workflow may do`

### Resolution

Deployment and remediation permissions were validated independently from OIDC authentication.

### Lesson

An OIDC login success should not be treated as proof that the cloud authorization model is correct.

---

## 17. Deployment and Remediation Permissions Needed Separation

### Problem

Using one highly privileged identity for both infrastructure management and remediation would create excessive blast radius.

### Resolution

Separate identities were created.

#### AWS:

- deployment IAM role;
- remediation IAM role.

#### Azure:

- deployment federated identity;
- remediation federated identity.

### Lesson

CI/CD workflows should be separated by responsibility when their permission requirements differ significantly.

----

## 18. GitHub Environment Approval Was Not Available

### Problem

The ideal remediation design included a GitHub Environment approval boundary.

The required environment capability was not available for the repository configuration being used.

### Risk

Removing approval entirely would allow remediation to proceed without human authorization.

### Resolution

A controlled fallback approval model was implemented using an exact confirmation token:

`APPROVE:<remediation-id>`

The token is validated against the remediation evidence before execution.

### Lesson

When a preferred platform feature is unavailable, the replacement control must preserve the underlying security requirement.

The requirement was:

`explicit human approval`

not:

`use one specific GitHub feature`

---

## 19. Preventing Approval From Becoming a Generic Yes/No Prompt

### Problem

A generic confirmation such as:

`yes`

would provide weak binding between approval and the remediation request.

Resolution

The project uses:

`APPROVE:<remediation-id>`

The approval validator checks the identifier against the remediation evidence.

### Lesson

Approval should be bound to the specific change being authorized.

---

## 20. Preventing Remediation Before Approval

### Risk

If cloud authentication or mutation occurred before approval validation, the human-in-the-loop model would be weakened.

### Resolution

The workflow separates:

- recommendation;
- approval;
- approval validation;
- authentication for execution;
- mutation.

Evidence validation confirms execution was not attempted before authorization.

### Lesson

Workflow sequencing is a security control.

Human approval should occur before privileged execution begins.

---

## 21. AWS Tag Remediation Required a Narrow Mutation Boundary

### Problem

A remediation workflow with broad EC2 permissions could modify much more than governance metadata.

### Resolution

AWS remediation was designed around:

`aws ec2 create-tags`

The governed field is:

`CostCenter`

The executor validates:

- target resource;
- tag key;
- before-state;
- desired value.

### Lesson

A remediation identity should receive permissions for the exact mutation class it performs.

---

## 22. Azure Tag Remediation Required a Narrow RBAC Boundary

### Problem

Using broad Azure subscription-level permissions would exceed the requirements of the remediation use case.

### Resolution

The dedicated Azure remediation identity was scoped to the governed workload and required tagging permissions.

The mutation command class is:

`az tag update`

### Lesson

Resource-level RBAC is preferable when the workflow only needs to modify one controlled resource class.

---

## 23. Before-State Changed Between Approval and Execution

### Risk

A remediation could be approved while the resource had one value and executed later after that value had changed.

Example:
```text
Approval:
CostCenter = Engineering

Execution:
CostCenter = DifferentValue
```
Blind execution would make the approval stale.

### Resolution

Both remediation executors verify live before-state immediately before mutation.

If the current value no longer matches the approved evidence, execution is denied.

### Lesson

Human approval alone does not eliminate time-of-check/time-of-use risk.

Live state must be verified at execution time.

---

## 24. Successful API Call Was Not Enough

### Problem

A cloud API command can return success without proving that the resource reached the intended governance state.

## Resolution

After mutation, the executors query the live resource again and verify:

`CostCenter = CC-PLATFORM`

### Lesson

Post-change verification should be part of automation rather than assuming command success equals desired-state success.

---

## 25. Remediation Created Terraform Drift

### Symptom

After successful controlled remediation, Terraform reported a change.

### Root Cause

This was expected.

Terraform declared:

`CostCenter = Engineering`

Controlled remediation changed the live resource to:

`CostCenter = CC-PLATFORM`

### Resolution

Terraform planning was used to prove the drift.

Terraform was then used to reconcile the infrastructure to the declared state.

### Lesson

Not every Terraform plan showing changes represents accidental drift.

In this project, drift was intentionally created to prove that Terraform remained authoritative.

---

## 26. Terraform Detailed Exit Code During Drift Testing

### Problem

Terraform drift validation requires distinguishing:

- no changes;
- changes present;
- execution error.

### Resolution

`terraform plan -detailed-exitcode` was used.

The important exit codes are:

- `0` -> success, no changes;
- `2` -> success, changes detected;
- `1` -> error.
Lesson

Exit code 2 from terraform plan -detailed-exitcode is not a failure.

It is the expected signal when testing known drift.

---

## 27. Terraform Drift Needed Reconciliation

### Symptom

After controlled remediation, Terraform detected the modified CostCenter tag.

### Resolution

Terraform was used to restore:

`CostCenter = Engineering`

A subsequent Terraform plan confirmed:

`zero drift`

### Lesson

A remediation platform should define how out-of-band changes interact with Infrastructure as Code.

Leaving permanent unexplained drift would create competing configuration authorities.

---

## 28. Remediation DENY Tests Needed to Prove No Mutation

### Problem

Simply receiving a validation error did not prove that no cloud mutation had occurred.

### Resolution

The DENY test suite tracked cloud mutation invocations.

The final result showed:

`0`

cloud mutation commands during denied cases.

## Lesson

Negative security tests should verify the absence of side effects, not only the presence of an error.

---

## 29. Approval DENY Tests

### Validation

Invalid approval scenarios were exercised.

The approval suite completed:

`9 / 9 PASS`

Every invalid case resulted in:

`DENY`

### Lesson

Approval logic should be tested against malformed and inconsistent input, not only against a successful request.

---

## 30. AWS Execution DENY Tests

### Validation

AWS invalid execution scenarios were tested.

The result was:

`13 / 13 PASS`

No unauthorized AWS cloud mutation occurred.

### Lesson

Execution-layer checks remain necessary even after approval validation.

Defense in depth prevents one control failure from automatically becoming a cloud mutation.

---

## 31. Azure Execution DENY Tests

### Validation

Azure invalid execution scenarios were tested.

The result was:

`13 / 13 PASS`

No unauthorized Azure mutation occurred.

### Lesson

The same remediation security principles should be independently proven for each cloud provider.

---

## 32. Combined Remediation DENY Validation

The complete negative-path suite produced:

`35 / 35 PASS`

This consisted of:

approval: `9 / 9`;
execution: `26 / 26`.

The combined result proved fail-closed behavior.

---

## 33. GitHub CLI Version Compatibility

### Symptom

Some newer `gh` CLI query patterns were not supported by the installed GitHub CLI version.

In particular, using certain `gh run list` options together with jq-style argument passing did not behave as expected.

### Root Cause

The local GitHub CLI version did not support the desired argument pattern.

### Resolution

The workflow-history queries were adjusted to use:

- supported `gh run list` filters;
- `--branch`;
- `--commit`;
- external jq processing where necessary.

### Lesson

CLI syntax should be validated against the installed tool version rather than assuming the latest documentation matches the local environment.

---

## 34. Historical Workflow Proof Required Exact Run Identification

### Problem

Final project validation required evidence of specific GitHub Actions outcomes.

Examples included:

- PR Governance PASS;
- PR Governance FAIL;
- remediation approval PASS;
- remediation approval FAIL;
- AWS remediation PASS;
- Azure remediation PASS.

### Resolution

Workflow history was queried and specific known runs were validated.

A final historical proof matrix passed:

`7 / 7`

### Lesson

CI/CD evidence should identify concrete workflow executions rather than relying only on workflow definitions.

---

## 35. Shell set -e Could Terminate the Interactive Session

### Symptom

During some validation commands, shell error behavior could terminate the active terminal flow unexpectedly.

### Root Cause

Using:

`set -e`

directly in the user's interactive shell can cause the shell to exit when a test intentionally returns non-zero.

This is especially dangerous when testing governance failure paths.

### Resolution

Risky validation was isolated inside child Bash processes.

Example pattern:

```bash
bash <<'STEP'
set +e

# validation logic

STEP

echo "child exit code: $?"
```
### Lesson

Test harness behavior should not affect the operator's interactive shell.

Negative-path testing frequently requires controlled non-zero exits.

---

## 36. Pipeline Exit Codes Could Be Hidden by tee

### Problem

Commands such as Terraform plans were sometimes piped through tools such as:

`tee`

A pipeline can make it easy to read the exit code of the wrong process.

### Resolution

Where exact Terraform exit status mattered, the command was executed inside Bash and the original command status was retrieved using:

`${PIPESTATUS[0]}`

### Lesson

When exit codes are part of the test result, pipeline semantics must be handled explicitly.

---

## 37. Raw Reports Were Hidden by .gitignore

### Symptom

Some generated cost and compliance reports existed locally but did not appear in:

`git status`

### Root Cause

The repository intentionally ignores raw operational reports.

These files can contain sensitive cloud identifiers.

### Resolution

Curated sanitized evidence files were generated separately and explicitly published.

### Lesson

An ignored file is not necessarily missing evidence.

The distinction between:

- operational evidence;
- public evidence

must be intentional.

---

## 38. Evidence Needed to Be Public but Sensitive Data Had to Remain Private

### Problem

The portfolio required real evidence, but raw reports could contain:

- AWS account IDs;
- Azure subscription IDs;
- tenant IDs;
- IAM ARNs;
- resource identifiers;
- user email addresses.

### Resolution

A two-tier evidence model was implemented.

Raw operational reports:

- local;
- Git-ignored.

Curated evidence:

- sanitized;
- validated;
- committed to Git.

### Lesson

Evidence publication is a security design problem, not only a documentation task.

---

## 39. Evidence Files Required Explicit Tracking

### Symptom

Sanitized evidence had been created but some report patterns were still affected by repository ignore behavior.

### Root Cause

The `.gitignore` rules were originally designed to prevent operational reports from being published.

Curated evidence required explicit exceptions.

### Resolution

The ignore configuration was refined so that only approved sanitized evidence files were tracked.

Final evidence publication included:

- AWS compliance evidence;
- Azure compliance evidence;
- multi-cloud compliance evidence;
- AWS cost summary;
- Azure cost summary;
- multi-cloud cost summary;
- modeled cost baseline.

### Lesson

Git ignore rules should support the security model rather than being treated as a static one-time configuration.

---

## 40. Evidence Publication Required Sensitive-Pattern Scanning

### Problem

Manually reviewing JSON evidence alone could miss identifiers unsuitable for public GitHub publication.

Resolution

Before committing curated evidence, staged content was scanned for patterns including:

- AWS account IDs;
- Azure subscription IDs;
- Azure tenant IDs;
- IAM ARNs;
- GitHub tokens;
- private keys;
- secrets;
- user email addresses.

The publication-safety validation passed.

### Lesson

Security checks should operate on staged content before commit whenever possible.

This tests exactly what is about to be published.

---

## 41. JSON Evidence Needed Structural Validation

### Problem

Sanitization or transformation could accidentally create invalid JSON.

### Resolution

All staged evidence JSON files were parsed before commit.

The curated publication validation completed:

`7 / 7 PASS`

### Lesson

Evidence must be both safe and machine-readable.

Sanitization should never sacrifice structural validity.

---

## 42. Runtime Compliance Needed Live Cloud State

### Problem

Terraform configuration alone could not prove that runtime cloud resources matched expected governance controls.

## Resolution

Dedicated live compliance scanners were implemented:

`scripts/compliance/check-aws-compliance.sh`

and:

`scripts/compliance/check-azure-compliance.sh`

Final Results

AWS:

`15 / 15 PASS`

Azure:

`18 / 18 PASS`

Combined:

`33 / 33 PASS`

### Lesson

Infrastructure intent and runtime state are different evidence sources.

Both should be validated.

---

## 43. AWS Public Subnet Was Initially Easy to Describe Incorrectly

### Problem

The EC2 instance had:

private IP only;
no public IP.

This could easily lead to documentation describing it as:

`private subnet EC2`

Root Cause

Instance addressing and subnet classification are different properties.

The subnet route table contains an Internet Gateway route, so the subnet is:

`public`

Correct Description

The accurate statement is:

`EC2 in a public subnet with private addressing only and no public IP`

### Lesson

Architecture documentation should be derived from actual routing and resource configuration rather than inferred from workload IP assignment.

----

## 44. Azure Outbound Behavior Needed Explicit Validation

### Problem

A VM with no public IP does not automatically prove that outbound networking is explicitly restricted.

### Resolution

The Azure subnet was validated to use:

`default_outbound_access_enabled = false`

### Lesson

Inbound exposure and outbound behavior are separate security properties.

Both should be documented independently.

---

## 45. Azure VM Security Needed Live Verification

### Validation

The Azure VM was validated for:

`secure_boot_enabled = true`

and:

`vtpm_enabled = true`

### Lesson

Security features declared in Terraform should be confirmed against the final implementation before being presented as architectural facts.

---

## 46. Architecture Documentation Needed a Fact Model

### Problem

The project contained many Terraform resources, scripts, workflows, and evidence files.

Creating an architecture diagram from memory risked introducing incorrect claims.

### Resolution

A final architecture fact model was built from:

- Terraform module references;
- Terraform resource types;
- Terraform state;
- Terraform outputs;
- workflow definitions;
- governance scripts;
- remediation scripts;
- evidence files.

### Lesson

Architecture diagrams should be derived from implementation facts rather than from the original design alone.

---

## 47. Public Architecture Must Exclude Sensitive Identifiers

### Problem

Live Terraform outputs and workflows contained identifiers that should not appear in a public portfolio diagram.

### Resolution

The architecture model uses logical names such as:

- AWS Deployment IAM Role;
- Azure Deployment Identity;
- AWS Remediation IAM Role;
- Azure Remediation Identity.

Sensitive account, subscription, tenant, and user identifiers are excluded.

### Lesson

A public architecture diagram should show trust relationships and resource roles without exposing unnecessary identity metadata.

---

## 48. Terraform Static Validation Needed Multiple Roots

### Problem

The repository contains multiple independent Terraform roots and modules.

Validating only the top-level environment would not prove the entire repository was healthy.

### Resolution

Final Terraform validation covered:

- AWS bootstrap;
- AWS environment;
- AWS networking module;
- AWS compute module;
- AWS budget module;
- Azure bootstrap;
- Azure environment;
- Azure networking module;
- Azure compute module;
- Azure budget module.

All roots passed validation.

### Lesson

Multi-root Terraform repositories require explicit validation coverage.

---

## 49. Terraform Provider Versions Needed Stability During Final Validation

### Problem

Changing provider or Terraform versions during final project validation could introduce unrelated behavior changes.

### Resolution

The validated environment was kept stable during closure.

The final validation used the already-working toolchain rather than introducing unnecessary upgrades.

### Lesson

Version upgrades should not be mixed into final evidence collection unless required.

Stability is more valuable than novelty during closure.

---

## 50. Workload Teardown Needed to Preserve Bootstrap Infrastructure

### Problem

After final validation, the AWS and Azure workloads needed to be destroyed to prevent charges.

However, destroying bootstrap infrastructure at the same time could remove remote-state and foundational identity resources needed for repository continuity.

### Resolution

Workload environment roots were destroyed separately from bootstrap roots.

The workload states were confirmed empty.

Bootstrap/state infrastructure was handled independently.

### Lesson

Terraform lifecycle boundaries should align with infrastructure ownership boundaries.

Bootstrap and workload stacks should not be treated as one disposable unit.

---

## 51. Final Teardown Verification

### Validation

After destroying the workload environments:

AWS Terraform environment state contained no workload resources;
Azure Terraform environment state contained no workload resources;
live infrastructure checks confirmed teardown;
the repository remained clean.

### Lesson

A successful `terraform destroy` message should be followed by state and live-provider verification when cost control matters.

---

## 52. Troubleshooting Outcome

The project troubleshooting process validated several important engineering principles.

- Governance failures must be distinguished from tool failures.
- Cloud billing data must be interpreted with billing lag in mind.
- OIDC authentication does not replace IAM or RBAC authorization.
- Human approval should be cryptographically or structurally bound to the  intended action where possible.
- Remediation must validate live state before and after mutation.
- Terraform drift can be intentional and should still be reconciled.
- Negative-path security tests must prove absence of mutation.
- Public evidence requires sanitization.
- Architecture documentation must be derived from verified implementation facts.
- Infrastructure teardown must be verified, not assumed.

The final troubleshooting model is:

```text
OBSERVE
   |
   v
CLASSIFY
   |
   v
ISOLATE
   |
   v
VERIFY
   |
   v
CORRECT
   |
   v
RE-TEST
   |
   v
DOCUMENT
```
These troubleshooting practices helped convert individual AWS, Azure, Terraform, CI/CD, FinOps, and remediation problems into repeatable engineering controls.
