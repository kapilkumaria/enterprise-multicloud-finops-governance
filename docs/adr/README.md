# Architecture Decision Records

## 1. Overview

This directory documents the major architectural decisions made while building the Enterprise Multi-Cloud FinOps, Governance & Controlled Remediation Platform.

The purpose of these Architecture Decision Records is to preserve:

- the engineering problem;
- the selected design;
- the reasoning behind the decision;
- important trade-offs;
- the resulting operational model.

The project currently maintains the major decisions in this consolidated ADR index.

---

## 2. ADR-001 — Separate Bootstrap and Workload Terraform State

### Decision

Bootstrap infrastructure is managed separately from workload infrastructure.

AWS and Azure each maintain dedicated bootstrap Terraform roots and separate workload environment roots.

### Reason

Bootstrap resources have a different lifecycle from workload resources.

Examples include:

- Terraform state infrastructure;
- GitHub OIDC trust configuration;
- cloud identities used by automation.

Workload infrastructure may be created and destroyed frequently, while bootstrap resources should normally remain stable.

### Result

The architecture supports:

```text
Bootstrap Infrastructure
        |
        +--> Long-Lived State / Identity Foundation

Workload Infrastructure
        |
        +--> Provision
        +--> Validate
        +--> Destroy

This allowed the project workload to be destroyed after evidence collection without automatically removing foundational state and identity resources.
```
---

## 3. ADR-002 — Use GitHub OIDC Instead of Static Cloud Credentials

### Decision

GitHub Actions authenticates to AWS and Azure using OpenID Connect federation.

### Reason

Long-lived cloud credentials create:

- secret-rotation overhead;
- leakage risk;
- persistent access after compromise;
- additional secret-management responsibilities.

OIDC provides short-lived cloud credentials based on trusted GitHub workflow identity.

### Result

The CI/CD architecture does not require long-lived:

- AWS access keys;
- Azure client secrets.

Authentication is federated while authorization remains controlled through:

- AWS IAM;
- Azure RBAC.

---

## 4. ADR-003 — Separate Deployment and Remediation Identities

### Decision

Deployment-oriented automation and controlled-remediation automation use separate cloud identities.

### Reason

The two workflow classes have different permission requirements.

Using one shared identity would create unnecessary privilege and increase blast radius.

### Result

AWS separates:

- deployment IAM role;
- remediation IAM role.

Azure separates:

- deployment federated identity;
- remediation federated identity.

This provides separation of duties and supports least privilege.

---

## 5. ADR-004 — Use Cloud-Specific Terraform Modules With a Common Governance Model

### Decision

AWS and Azure infrastructure are implemented using separate Terraform modules while governance logic is centralized at the repository level.

### Reason

AWS and Azure expose different:

- resource models;
- networking constructs;
- IAM models;
- billing APIs;
- security controls.

Attempting to force both providers into identical infrastructure modules would hide important cloud-specific behavior.

At the same time, governance requirements such as:

- approved regions;
- mandatory tags;
- cost thresholds;
- evidence generation;

can follow a common operating model.

### Result

The architecture uses:

```text
AWS Terraform
      \
       \
        +--> Shared Governance Model
       /
      /
Azure Terraform
```
This preserves provider-specific implementation while maintaining centralized policy intent.

---

## 6. ADR-005 — Enforce Governance Before Deployment

### Decision

Region, tag, security, Terraform, and cost controls are evaluated before infrastructure deployment where possible.

### Reason

Detecting violations after deployment is more expensive and increases operational risk.

Pre-deployment governance allows invalid infrastructure to be blocked before cloud mutation.

### Result

The pull-request governance pipeline evaluates:

- repository safety;
- Terraform static validation;
- Checkov;
- approved regions;
- mandatory tags;
- Infracost;
- cost thresholds.

This implements a shift-left governance model.

---

## 7. ADR-006 — Use Both Static and Runtime Compliance Validation

### Decision

The project validates both Terraform configuration and live cloud resources.

### Reason

Infrastructure-as-Code represents intended state.

It does not by itself prove that live infrastructure currently matches that intent.

Runtime validation is required to detect:

- manual changes;
- provider-side differences;
- configuration drift;
- unexpected runtime conditions.

### Result

Final compliance validation produced:

AWS: `15 / 15 PASS`;
Azure: `18 / 18 PASS`;
Multi-cloud: `33 / 33 PASS`.

---

## 8. ADR-007 — Treat FinOps as a CI/CD Governance Control

### Decision

Cost estimation and cost thresholds are integrated into the governance pipeline.

### Reason

Cost should be considered before infrastructure is created, not only after receiving a cloud bill.

### Result

The platform combines:

- Infracost;
- cloud-specific cost thresholds;
- AWS Budgets;
- Azure Consumption Budgets;
- provider-native cost reporting.

Modeled cost can therefore participate directly in deployment governance.

---

## 9. ADR-008 — Preserve Native Cloud Billing Currencies

### Decision

Provider-native AWS and Azure cost values are not directly combined when they use different currencies.

### Reason

Adding values such as:

`USD + CAD`

would produce a financially meaningless number without an explicit foreign-exchange conversion strategy.

### Result

The multi-cloud cost summary preserves:

- cloud;
- cost;
- native currency.

A future implementation could normalize costs only after defining:

- target currency;
- exchange-rate source;
- conversion timestamp.

---

## 10. ADR-009 — Use Human-Approved Controlled Remediation

### Decision

Governance findings do not automatically trigger cloud mutation.

Supported remediation requires explicit human approval.

### Reason

Unrestricted self-healing can introduce significant operational and security risk.

Examples include:

- modifying the wrong resource;
- acting on stale evidence;
- changing unsupported attributes;
- executing an incorrect desired state.

### Result

The remediation lifecycle is:

```text
Finding
   |
   v
Recommendation
   |
   v
Policy Validation
   |
   v
Human Approval
   |
   v
Execution
```
The approval format is:

`APPROVE:<remediation-id>`

---

## 11. ADR-010 — Restrict Remediation to an Allow-Listed Mutation

### Decision

Controlled remediation is limited to the supported:

`set-tag`

operation for:

`CostCenter`

### Reason

Broad remediation authority would create unnecessary risk.

The project is intended to demonstrate safe governance automation rather than unrestricted cloud administration.

### Result

AWS uses:

`aws ec2 create-tags`

Azure uses:

`az tag update`

The workflow does not permit arbitrary infrastructure changes.

---

## 12. ADR-011 — Verify Live State Before and After Remediation

### Decision

Remediation executors validate the live resource before mutation and again after mutation.

### Reason

Approval can become stale if resource state changes between authorization and execution.

A successful cloud API call also does not necessarily prove the desired state was reached.

### Result

The execution lifecycle is:

```text
Approved Evidence
      |
      v
Verify Before State
      |
      v
Cloud Mutation
      |
      v
Verify After State
```
Unexpected state results in denial or failure rather than blind execution.

---

## 13. ADR-012 — Terraform Remains the Authoritative Source of Truth

### Decision

Controlled remediation does not permanently replace Terraform-managed configuration.

## Reason

Allowing remediation automation and Terraform to independently manage the same attributes would create competing sources of truth.

## Result

The validated lifecycle was:

```text
Terraform Desired State
        |
        v
Cloud Resource
        |
        v
Approved Remediation
        |
        v
Terraform Drift
        |
        v
Terraform Reconciliation
        |
        v
Zero Drift
```
Controlled remediation may temporarily change runtime state, but Terraform remains authoritative.

---

## 14. ADR-013 — Fail Closed on Invalid Remediation Requests

### Decision

If remediation authorization cannot be fully validated, execution is denied.

## Reason

Security-sensitive automation should not infer intent or continue with incomplete evidence.

## Result

Negative-path validation completed:

`35 / 35 PASS`

The DENY tests confirmed:

- invalid approval was rejected;
- invalid execution was rejected;
- cloud mutation invocations remained zero;
- governed cloud state remained unchanged.

---

## 15. ADR-014 — Separate Raw Operational Evidence From Public Evidence

### Decision

Raw cloud reports are kept separate from sanitized portfolio evidence.

### Reason

Operational evidence can contain:

- account identifiers;
- subscription identifiers;
- tenant identifiers;
- resource IDs;
- IAM ARNs;
- user identities;
- other environment metadata.

These details are unnecessary for demonstrating the project publicly.

### Result

The evidence model is:

```text
Cloud / CI/CD Output
        |
        v
Raw Operational Evidence
        |
        v
Sanitization
        |
        v
Curated Public Evidence
```
Only approved sanitized evidence is committed to the public repository.

---

## 16. ADR-015 — Keep Workload Infrastructure Ephemeral

### Decision

The project workload infrastructure is destroyed after implementation, validation, and evidence collection.

### Reason

Keeping portfolio infrastructure running continuously would create cost without providing meaningful additional project value.

### Result

The lifecycle is:

```text
Provision
   |
   v
Validate
   |
   v
Collect Evidence
   |
   v
Destroy
```
AWS and Azure workload environments were destroyed after final validation.

Bootstrap and state infrastructure are managed separately.

---

## 17. Architectural Decision Summary

The major architectural decisions establish the following operating model:

- Terraform remains the infrastructure source of truth;
- AWS and Azure retain provider-specific implementation;
- governance is centralized;
- FinOps is enforced before deployment;
- runtime state is independently validated;
- GitHub OIDC eliminates static cloud credentials;
- deployment and remediation permissions are separated;
- remediation requires explicit human approval;
- remediation actions are narrowly allow-listed;
- invalid remediation requests fail closed;
- raw operational evidence is separated from public evidence;
- workload infrastructure is removed when no longer required.

Together, these decisions support a platform that is:

- secure;
- auditable;
- cost-aware;
- policy-driven;
- reproducible;
- suitable for multi-cloud enterprise governance.
