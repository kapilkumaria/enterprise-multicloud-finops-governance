# Project Charter

## Enterprise Multi-Cloud FinOps, Governance & Controlled Remediation Platform

## 1. Project Overview

This project implements an enterprise-style multi-cloud governance and FinOps platform across AWS and Microsoft Azure.

The platform demonstrates how infrastructure teams can combine Infrastructure as Code, policy enforcement, cost governance, runtime compliance validation, federated cloud authentication, and controlled remediation into a single governance operating model.

The implementation uses Terraform to provision governed baseline infrastructure in both clouds and GitHub Actions as the CI/CD governance control plane.

The project intentionally addresses three different stages of the infrastructure lifecycle:

1. **Pre-deployment governance** — validate infrastructure before deployment.
2. **Runtime governance** — verify that deployed cloud resources remain compliant.
3. **Controlled remediation** — safely correct approved governance violations without allowing unrestricted automated mutation.

The platform was designed as a portfolio implementation of controls commonly required by platform engineering, cloud governance, FinOps, security, and SRE teams.

---

## 2. Business Problem

Organizations operating across multiple cloud providers face several recurring governance challenges:

- infrastructure can be deployed into unapproved regions;
- mandatory ownership and cost-allocation tags can be omitted;
- infrastructure changes can introduce unexpected cloud costs;
- cloud environments can drift from approved Infrastructure-as-Code state;
- governance controls can differ between cloud providers;
- long-lived CI/CD credentials increase security risk;
- automated remediation can become dangerous if mutation is unrestricted;
- compliance evidence can expose sensitive cloud identifiers;
- cost and compliance reporting can become fragmented across cloud platforms.

The objective of this project is to demonstrate a centralized governance model that addresses these problems while preserving cloud-specific controls where appropriate.

---

## 3. Project Objectives

The platform was designed to provide the following capabilities:

### Infrastructure as Code

Provision governed AWS and Azure baseline infrastructure using reusable Terraform modules and remote state.

### Multi-Cloud Region Governance

Restrict infrastructure to approved deployment regions:

- AWS: `us-east-1`
- Azure: `canadacentral`

Infrastructure targeting disallowed regions is rejected by governance validation.

### Mandatory Tag Governance

Require standardized metadata for cost allocation, ownership, and governance.

Core mandatory tags include:

- `Project`
- `Environment`
- `Owner`
- `CostCenter`
- `BusinessUnit`
- `DataClassification`

### Pre-Deployment Policy Enforcement

Evaluate Terraform changes before deployment using:

- Terraform formatting and validation;
- Checkov static analysis;
- custom region policies;
- mandatory tag validation;
- FinOps cost policy validation;
- Infracost estimates.

### Cost Governance

Provide both modeled and provider-native cost visibility through:

- Infracost pre-deployment estimates;
- AWS Budgets;
- Azure Consumption Budgets;
- AWS cost reporting;
- Azure cost reporting;
- multi-cloud cost summaries;
- configurable cost thresholds.

### Runtime Compliance

Validate deployed AWS and Azure resources against expected governance controls and generate machine-readable compliance evidence.

Validated runtime results included:

- AWS: **15/15 controls passed**
- Azure: **18/18 controls passed**
- Multi-cloud aggregate: **33/33 controls passed**

### Secure CI/CD Authentication

Use GitHub Actions OpenID Connect federation instead of long-lived AWS or Azure cloud credentials.

The architecture separates deployment and remediation identities so that remediation workflows do not inherit unrestricted infrastructure-management permissions.

### Controlled Remediation

Implement a human-approved remediation workflow capable of correcting an approved `CostCenter` tag violation.

The remediation model includes:

- governance finding;
- remediation recommendation;
- allow-listed action validation;
- human approval;
- exact confirmation token;
- fail-closed approval validation;
- short-lived OIDC authentication;
- dedicated remediation identity;
- live before-state verification;
- narrowly scoped cloud mutation;
- post-change verification;
- Terraform drift detection;
- Terraform reconciliation;
- final zero-drift verification.

### Evidence Publication

Maintain a separation between operational reports and portfolio-safe evidence.

Raw cloud reports containing potentially sensitive identifiers remain local and Git-ignored, while curated and sanitized evidence is intentionally committed to the repository.

---

## 4. Cloud Scope

The project implements equivalent governance concepts across two cloud providers.

### AWS

Primary region:

```text
us-east-1
```

The governed baseline included:

- Amazon VPC;
- public subnet;
- Internet Gateway;
- route table;
- hardened security groups;
- EC2 baseline instance;
- IAM role and instance profile;
- VPC Flow Logs;
- CloudWatch Logs;
- KMS encryption;
- AWS Budget.

The EC2 workload used a private IP only and did not receive a public IP address.

### Microsoft Azure

Primary region:
```test
Canada Central
```
The governed baseline included:

- Resource Group;
- Virtual Network;
- compute subnet;
- Network Security Group;
- Network Interface;
- Linux Virtual Machine;
- system-assigned managed identity;
- Secure Boot;
- virtual TPM;
- Azure Consumption Budget.

The Azure workload used a private IP only, and default outbound subnet access was disabled.

---

## 5. FinOps Baseline

The project combines pre-deployment modeling with provider-native cost information.

### Pre-Deployment Modeled Cost

The validated Infracost baseline estimated approximately:

| Cloud | Baseline Workload             | Estimated Monthly Cost |
| ----- | ----------------------------- | ---------------------: |
| AWS   | EC2 `t3.micro` baseline       |                 USD 11 |
| Azure | VM `Standard_D2s_v3` baseline |                 USD 72 |

These values represent modeled infrastructure estimates rather than finalized provider invoices.

### Governance Thresholds

The project applies cost-policy thresholds of:

| Cloud | Threshold |
| ----- | --------: |
| AWS   |    USD 25 |
| Azure |       100 |


The Azure threshold is evaluated by the project cost-governance logic, while provider-native Azure billing evidence retains its native billing currency.

Modeled cost and actual provider billing are intentionally treated as different evidence types.

---

## 6. Governance Operating Model

The project uses multiple governance layers rather than relying on a single scanner.

### Layer 1 — Terraform Validation

Terraform formatting, initialization, validation, and planning establish Infrastructure-as-Code correctness.

### Layer 2 — Static Security and Configuration Analysis

Checkov evaluates Terraform against infrastructure security and configuration policies.

### Layer 3 — Custom Governance

Custom controls validate requirements such as:

approved regions;
mandatory tags;
cost thresholds.

### Layer 4 — Runtime Compliance

Cloud APIs are queried after deployment to verify that the live AWS and Azure environments match expected governance requirements.

### Layer 5 — Controlled Remediation

Selected violations can enter a tightly controlled remediation workflow requiring explicit human approval before cloud mutation.

### Layer 6 — Terraform Reconciliation

After an approved out-of-band remediation, Terraform detects the resulting drift and restores the Infrastructure-as-Code authoritative state.

This demonstrates that remediation automation does not silently replace Terraform as the infrastructure source of truth.

---

## 7. CI/CD Governance Model

GitHub Actions provides the automation and governance control plane.

Key workflows include:

- PR Governance;
- Resolved Cost Governance;
- AWS OIDC Validation;
- Azure OIDC Validation;
- AWS Remediation OIDC Validation;
- Azure Remediation OIDC Validation;
- Controlled Remediation Approval;
- AWS Controlled Remediation;
- Azure Controlled Remediation.

The PR governance workflow evaluates infrastructure changes before they can be considered compliant.

The resolved-cost workflow uses short-lived federated cloud authentication to evaluate provider-resolved Terraform plans and cost estimates.

Controlled remediation workflows are intentionally separated from general infrastructure workflows.

---

## 8. Security Principles

The implementation follows several security principles.

### No Long-Lived Cloud Credentials

GitHub Actions uses OIDC federation for AWS and Azure authentication.

Static AWS access keys and Azure client secrets are not required by the workflows.

### Least Privilege

Deployment and remediation identities are separated.

Remediation identities are scoped to the actions and resources required by the controlled remediation use case.

### Human-in-the-Loop Mutation

A recommendation does not automatically authorize a cloud change.

The remediation workflow requires explicit approval and validates the requested action against the approved evidence before execution.

### Fail-Closed Validation

Invalid, modified, mismatched, replayed, or otherwise unauthorized remediation requests are denied before cloud mutation.

### Evidence Sanitization

Sensitive cloud identifiers are excluded from curated public evidence.

---

## 9. Controlled Remediation Safety Model

The project intentionally avoids unrestricted self-healing.

The implemented remediation capability is constrained to an allow-listed action:
```
set-tag
```
The governed tag is:
```
CostCenter
```
AWS remediation uses the controlled mutation class:
```
aws ec2 create-tags
```
Azure remediation uses:
```
az tag update
```
The remediation workflows do not perform an automatic Terraform apply, destroy, or import operation.

Terraform remains authoritative for infrastructure configuration.

---

## 10. Evidence and Validation

The repository contains curated evidence demonstrating successful operation of the platform.

Evidence includes:

- AWS cost summary;
- Azure cost summary;
- multi-cloud cost summary;
- modeled monthly cost baseline;
- AWS runtime compliance evidence;
- Azure runtime compliance evidence;
- multi-cloud compliance evidence;
- AWS remediation execution evidence;
- Azure remediation execution evidence;
- cross-cloud remediation summary;
- remediation DENY-path evidence.

Validated compliance results:
```text
AWS:         15 / 15 controls passed
Azure:       18 / 18 controls passed
Multi-cloud: 33 / 33 controls passed
```
The project also validated both successful remediation and fail-closed denial behavior.

---

## 11. Repository Organization

The repository separates infrastructure, policy, automation, evidence, examples, and documentation.

```text
terraform/
  aws/
  azure/

policies/
  checkov/
  cost/
  tagging/

scripts/
  aws/
  azure/
  compliance/
  cost/
  remediation/

examples/
  compliant/
  violations/

reports/
  cost/
  compliance/
  remediation/

docs/
  images/
  adr/
```
This separation keeps the governance platform modular and makes individual controls easier to test and reason about.

---

## 12. Success Criteria

The project is considered successful when the following conditions are demonstrated:

- AWS and Azure infrastructure can be managed through Terraform;
- approved-region policies are enforced;
- mandatory tags are validated;
- infrastructure cost can be estimated before deployment;
- cost thresholds can fail governance checks;
- provider-native budgets exist;
- runtime cloud resources can be evaluated for compliance;
- CI/CD uses OIDC rather than static cloud credentials;
- compliant and intentionally non-compliant scenarios are testable;
- remediation requires explicit human approval;
- remediation execution is restricted to allow-listed mutations;
- unauthorized remediation attempts fail closed;
- successful remediation is independently verified;
- Terraform detects out-of-band remediation as drift;
- Terraform can reconcile the environment back to authoritative state;
- sanitized evidence can be safely committed to the repository.

All of these capabilities were exercised during implementation and validation.

---

## 13. Project Outcome

The completed platform demonstrates an end-to-end governance lifecycle:

```text
Infrastructure Change
        |
        v
Pre-Deployment Governance
        |
        v
Cost + Policy Validation
        |
        v
Cloud Infrastructure
        |
        v
Runtime Compliance
        |
        v
Governance Finding
        |
        v
Controlled Recommendation
        |
        v
Human Approval
        |
        v
Scoped Remediation
        |
        v
Post-Change Verification
        |
        v
Terraform Drift Detection
        |
        v
Terraform Reconciliation
        |
        v
Evidence
```
The result is a multi-cloud governance platform that integrates FinOps, policy-as-code, secure CI/CD identity, runtime compliance, controlled remediation, and Infrastructure-as-Code reconciliation across AWS and Azure.
EOF

Now validate it:

```bash
echo "===== PROJECT CHARTER VALIDATION ====="

wc -l docs/project-charter.md

grep -nE \
  'TODO|TBD|FIXME|<AWS_ACCOUNT_ID>|<AZURE_SUBSCRIPTION_ID>|<AZURE_TENANT_ID>|kapil\.azure\.lab@gmail\.com' \
  docs/project-charter.md \
  || echo "PASS - no placeholders or sensitive identifiers"

echo
git diff --check

echo
git diff -- docs/project-charter.md

echo
git status --short
```
