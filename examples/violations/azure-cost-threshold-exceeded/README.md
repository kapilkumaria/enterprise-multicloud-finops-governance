# Azure Cost Threshold Violation

> Controlled negative test only. Do not apply.

This configuration intentionally requests a `Standard_D16s_v5`
virtual machine in the approved `canadacentral` region.

Resources use the required governance tags.

Expected policy behavior:

- Region governance: ALLOW
- Mandatory-tag governance: ALLOW
- FinOps cost governance: DENY
- Unified governance: DENY

The configuration exists only to demonstrate preventive FinOps controls.
