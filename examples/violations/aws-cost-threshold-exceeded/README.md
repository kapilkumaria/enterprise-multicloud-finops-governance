# AWS Cost Threshold Violation

> Controlled negative test only. Do not apply.

This configuration intentionally requests an `m6i.4xlarge`
EC2 instance in the approved `us-east-1` region.

The resource contains the required governance tags.

Expected policy behavior:

- Region governance: ALLOW
- Mandatory-tag governance: ALLOW
- FinOps cost governance: DENY
- Unified governance: DENY

The configuration exists only to prove that expensive infrastructure
can be rejected before deployment.
