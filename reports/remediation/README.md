# Cross-Cloud Controlled Remediation Evidence

This directory contains sanitized audit evidence from the controlled
remediation implementation for AWS and Azure.

## Control

- Control: `TAG-001`
- Governed tag: `CostCenter`
- Environment: `dev`
- Remediation type: human-approved controlled remediation
- Authentication: GitHub Actions OIDC
- Static cloud credentials: not used
- Terraform mutation by remediation workflow: not permitted

## AWS Proof

The AWS remediation workflow demonstrated the following control sequence:

1. Detected the governed resource with `CostCenter=Engineering`.
2. Generated a recommendation for `CostCenter=CC-PLATFORM`.
3. Required explicit human approval.
4. Authenticated using GitHub OIDC and a dedicated AWS remediation role.
5. Verified the live resource and approved before-state.
6. Performed only the approved `CostCenter` tag mutation.
7. Verified the live value became `CC-PLATFORM`.
8. Terraform subsequently detected the controlled out-of-band drift.
9. Terraform reconciled the resource back to its authoritative value of `Engineering`.
10. A final Terraform plan confirmed zero drift.

Execution result: `PASS`

## Azure Proof

The Azure remediation workflow demonstrated the following control sequence:

1. Detected the governed VM with `CostCenter=Engineering`.
2. Generated a recommendation for `CostCenter=CC-PLATFORM`.
3. Required explicit human approval.
4. Authenticated using GitHub OIDC and a dedicated Azure remediation identity.
5. Verified the live resource and approved before-state.
6. Performed only the approved `CostCenter` tag mutation.
7. Verified the live value became `CC-PLATFORM`.
8. Terraform subsequently detected the controlled out-of-band drift.
9. Terraform reconciled the VM back to its authoritative value of `Engineering`.
10. A final Terraform plan confirmed zero drift.

Execution result: `PASS`

## Security Properties Demonstrated

The implementation proves that remediation is:

- human approved;
- fail closed;
- authenticated using short-lived OIDC federation;
- executed through dedicated remediation identities;
- constrained to an allow-listed action;
- validated against the approved before-state;
- independently verified after mutation;
- separated from Terraform mutation;
- reconciled back to Terraform's authoritative desired state.

## Evidence Files

- `aws/execution-evidence.json` — sanitized AWS execution evidence.
- `azure/execution-evidence.json` — sanitized Azure execution evidence.
- `cross-cloud-remediation-summary.json` — normalized cross-cloud control summary.

Raw workflow artifacts are intentionally not committed. The JSON evidence in
this directory is sanitized for portfolio publication.

## Fail-Closed DENY Testing

The remediation controls were also tested using deliberately invalid and
tampered requests.

### Approval Boundary

Nine negative approval tests were executed covering:

- incorrect remediation ID;
- incorrect cloud;
- incorrect resource;
- unauthorized action;
- unauthorized tag key;
- before-state mismatch;
- tampered desired value;
- invalid confirmation token;
- missing confirmation token.

All 9 requests were denied.

No denied request produced approval evidence and no cloud mutation occurred.

### Execution Boundary

The AWS and Azure executors were independently tested with 13 tampered
approval-evidence cases per cloud, for a total of 26 negative executor tests.

The cases covered:

- unsupported schema;
- incorrect remediation ID;
- incorrect cloud;
- incorrect environment;
- unauthorized action;
- incorrect resource;
- unauthorized tag key;
- tampered desired value;
- invalid approval requirement state;
- missing human approval;
- unverified confirmation token;
- execution replay;
- invalid lifecycle state.

All 26 executor tests were denied before the cloud-command boundary.

A command tripwire verified that zero AWS CLI or Azure CLI commands were
invoked by the denied executions. No execution evidence was produced for any
denied request.

After the tests, both governed cloud resources retained the Terraform
authoritative `CostCenter=Engineering` value.

DENY-test result: `PASS`

See `deny-test-summary.json` for the normalized audit summary.
