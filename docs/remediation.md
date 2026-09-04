# Controlled Remediation

## Purpose

This project separates governance detection from infrastructure mutation.

A governance violation must never directly trigger an automatic cloud change.

The remediation lifecycle is:

Violation
→ Recommendation
→ Human approval
→ Dedicated remediation identity
→ Allow-listed action
→ Verification
→ Audit evidence

## Design Principles

1. Detection and remediation are separate responsibilities.
2. Pull request governance remains non-mutating.
3. Pull request workflows must not receive cloud write credentials.
4. Remediation requires explicit trusted invocation.
5. Remediation uses dedicated AWS and Azure identities.
6. Deployment identities must not be reused for remediation.
7. Only explicitly allow-listed remediation actions may execute.
8. Generic Terraform apply/destroy is prohibited in remediation workflows.
9. Generic unrestricted AWS CLI or Azure CLI mutation is prohibited.
10. One narrowly scoped resource/control is remediated at a time.
11. Before-state and after-state must be captured.
12. Every remediation must be independently verified.
13. Verification failure causes the remediation result to fail closed.
14. Terraform remains the authoritative infrastructure definition.
15. Automatic destructive self-healing is out of scope.

## Initial Supported Remediation

The first supported remediation class is:

- Resource tag correction

Examples:

- Add a missing mandatory tag.
- Correct an explicitly approved tag value.

Initial mandatory tag keys:

- Project
- Environment
- Owner
- CostCenter
- BusinessUnit
- DataClassification

## Why Tag Remediation First

Tag remediation is intentionally selected because it is:

- low risk
- deterministic
- reversible
- easy to verify
- suitable for least-privilege IAM/RBAC
- directly relevant to FinOps attribution
- capable of demonstrating real controlled remediation without destructive infrastructure changes

## Explicitly Prohibited Actions

The remediation system must not automatically perform:

### AWS

- EC2 termination
- EC2 instance resizing
- EBS deletion
- S3 bucket deletion
- VPC deletion
- subnet deletion
- route-table mutation
- security-group restructuring
- IAM administrator privilege assignment
- unrestricted resource deletion

### Azure

- resource-group deletion
- virtual-machine deletion
- virtual-machine resizing
- disk deletion
- VNet deletion
- subnet deletion
- NSG restructuring
- unrestricted role assignment
- unrestricted resource deletion

### Terraform

The remediation workflow must not execute:

- terraform apply
- terraform destroy
- terraform import

## Approval Model

Preferred model:

GitHub Environment protected by required reviewers.

If repository/account capabilities do not support protected environment reviewers for this private repository, the fallback model is:

workflow_dispatch
+
explicit confirmation token
+
exact cloud
+
exact resource identifier
+
exact remediation action
+
expected current value
+
desired value

The fallback must be documented as an account/platform limitation and must still fail closed.

## Identity Model

### AWS

A dedicated GitHub Actions OIDC remediation role must be used.

The role must:

- be separate from the deployment role
- be separate from the resolved-cost role
- trust only the approved GitHub repository/branch/workflow context
- have only the permissions required for supported tag remediation
- have read permissions needed for before/after verification

### Azure

A dedicated federated remediation identity must be used.

The identity must:

- be separate from deployment identity
- use GitHub OIDC/federated authentication
- have only the minimum scope required for supported tag remediation
- have read access for verification
- avoid broad subscription-level roles wherever practical

## Recommendation Contract

A detected finding must first become a non-mutating recommendation containing:

- remediation_id
- cloud
- control_id
- resource_type
- resource_identifier
- observed_value
- desired_value
- recommended_action
- action_type
- risk_level
- requires_approval

The recommendation engine itself must not authenticate to AWS or Azure and must not mutate any resource.

## Remediation Evidence Contract

Each controlled remediation must record:

### Metadata

- repository
- commit
- workflow
- workflow run ID
- event
- environment
- generated timestamp

### Remediation

- remediation ID
- cloud
- control ID
- action type
- resource type
- resource identifier

### Before

- compliance status
- observed value

### Recommendation

- desired value
- recommended action
- risk level
- approval requirement

### Approval

- required
- approval model
- approved status

### Execution

- attempted
- authentication type
- OIDC used
- dedicated remediation identity used
- command class

### After

- compliance status
- observed value

### Result

- remediation result
- verification result
- reason

Evidence must never contain:

- access tokens
- cloud secrets
- GitHub tokens
- private SSH keys
- passwords

## Fail-Closed Conditions

The remediation process must stop without mutation if:

- the cloud is unsupported
- the action is unsupported
- the control ID is unsupported
- the resource identifier is invalid
- approval is missing
- the expected current state does not match
- the requested desired value is invalid
- authentication fails
- authorization exceeds the allow-list
- verification cannot be completed

## Phase 10 Acceptance Criteria

Phase 10 is complete only when:

- a non-mutating recommendation engine exists
- remediation recommendation JSON is machine-readable
- AWS uses a dedicated remediation OIDC role
- Azure uses a dedicated remediation federated identity
- pull_request cannot trigger remediation
- trusted invocation is required
- supported actions are allow-listed
- before/after evidence is captured
- approval is required
- AWS controlled tag-remediation proof succeeds
- Azure controlled tag-remediation proof succeeds
- invalid/destructive requests are denied
- audit artifacts are generated
- no secrets are stored in evidence
- Terraform state remains coherent
- no generic terraform apply/destroy is used
- no automatic destructive self-healing exists
