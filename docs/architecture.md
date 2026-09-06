# Architecture

## 1. Overview

The Enterprise Multi-Cloud FinOps, Governance & Controlled Remediation Platform implements a governance control plane across AWS and Microsoft Azure.

The architecture combines:

- Terraform-based Infrastructure as Code;
- GitHub Actions governance workflows;
- policy-as-code and custom governance controls;
- Infracost pre-deployment cost estimation;
- provider-native cost and budget controls;
- runtime compliance validation;
- GitHub OpenID Connect (OIDC) federation;
- dedicated remediation identities;
- human-approved controlled remediation;
- Terraform drift detection and reconciliation;
- sanitized evidence publication.

The design intentionally separates the following concerns:

1. source control and change management;
2. CI/CD governance;
3. policy and FinOps evaluation;
4. cloud authentication;
5. AWS infrastructure;
6. Azure infrastructure;
7. controlled remediation;
8. evidence and reporting.

This separation limits blast radius, makes governance decisions observable, and preserves Terraform as the authoritative infrastructure configuration.

---

## 2. High-Level Architecture

The canonical architecture diagram is maintained as source in:

`diagrams/mc-finops-architecture.mmd`

and rendered for repository documentation as:

`docs/images/architecture/mc-finops-architecture.png`

Once rendered, the architecture is displayed below:

At a high level, the architecture follows this flow:

```text
Engineer
   |
   v
GitHub Repository / Pull Request
   |
   v
GitHub Actions Governance
   |
   +--------------------+
   |                    |
   v                    v
Policy / FinOps      GitHub OIDC
Evaluation              |
   |              +-----+------+
   |              |            |
   v              v            v
Governance       AWS          Azure
Decision          |            |
                  v            v
             Runtime Cloud Infrastructure
                  |
                  v
             Compliance Validation
                  |
                  v
            Governance Findings
                  |
                  v
         Controlled Remediation
                  |
                  v
       Drift Detection / Reconciliation
                  |
                  v
          Sanitized Evidence
```
---

## 3. Architectural Layers

### 3.1 Developer and Source-Control Layer

GitHub is the central source-control system for:

- Terraform configuration;
- governance scripts;
- policy definitions;
- GitHub Actions workflows;
- compliant test fixtures;
- violation fixtures;
- curated evidence;
- project documentation.

Infrastructure and governance changes enter the lifecycle through the repository and pull-request process.

The repository therefore acts as both:

- the Infrastructure-as-Code source of truth; and
- the version-controlled definition of governance behavior.

---

### 3.2 CI/CD Governance Control Plane

GitHub Actions provides the automation control plane.

The implementation contains dedicated workflows for:

- pull-request governance;
- resolved cost governance;
- AWS OIDC validation;
- Azure OIDC validation;
- AWS remediation OIDC validation;
- Azure remediation OIDC validation;
- remediation approval;
- AWS controlled remediation;
- Azure controlled remediation.

The workflows are deliberately separated by responsibility instead of implementing all behavior in one highly privileged pipeline.

This allows authentication, governance, cost evaluation, approval, and mutation to be independently validated.

---

## 4. Terraform Architecture

AWS and Azure use separate Terraform roots while following the same high-level modular structure.

```text
terraform/
├── aws/
│   ├── bootstrap/
│   ├── environments/
│   │   └── dev/
│   └── modules/
│       ├── networking/
│       ├── compute/
│       └── budget/
└── azure/
    ├── bootstrap/
    ├── environments/
    │   └── dev/
    └── modules/
        ├── networking/
        ├── compute/
        └── budget/
```
---

### 4.1 Bootstrap Layer

Each cloud has a separate bootstrap root.

The bootstrap layer establishes foundational state and CI/CD identity resources required before the main environment can be managed.

Keeping bootstrap infrastructure separate avoids creating a circular dependency in which Terraform would need its own remote-state infrastructure before that infrastructure existed.

### 4.2 Environment Layer

The dev environment composes the reusable modules.

### AWS:

```text
dev
├── networking
├── compute
└── budget
```
### Azure:

```text
dev
├── networking
├── compute
└── budget
```
This creates equivalent governance domains across both cloud providers without attempting to force cloud-specific resources into an artificial common abstraction.

### 4.3 Module Design

The modules separate:

- networking;
- compute;
- cost/budget governance.

This makes individual governance concerns easier to test and allows cloud-specific security controls to remain explicit.

---

## 5. AWS Architecture

The AWS implementation is deployed in the approved region:

`us-east-1`

The environment contains the following primary Terraform-managed resources.

### 5.1 Networking

The networking module provisions:

- VPC;
- Internet Gateway;
- public subnet;
- public route table;
- route-table association;
- compute security group;
= managed default security group;
- VPC Flow Logs;
- CloudWatch log group;
- KMS key and alias;
- IAM role and policy for VPC Flow Logs.

Conceptually:

```text
AWS / us-east-1
|
+-- VPC
    |
    +-- Internet Gateway
    |
    +-- Public Subnet
    |     |
    |     +-- EC2 baseline
    |
    +-- Public Route Table
    |
    +-- Compute Security Group
    |
    +-- VPC Flow Logs
          |
          +-- IAM Role
          |
          +-- CloudWatch Logs
                  |
                  +-- KMS Encryption
```
### Important Network Design Detail

The baseline EC2 instance resides in a subnet classified as public because the subnet's route table has a route through an Internet Gateway.

However, the instance itself is configured with:

`associate_public_ip_address = false`

Therefore, the architecture should not describe the workload as residing in a private subnet.

The accurate description is:

> The EC2 baseline is deployed into a public subnet but uses a private address only and is not assigned a public IP.

This distinction is important because subnet classification and instance-level public addressing are separate architectural properties.

---

### 5.2 AWS Compute

The compute module provisions:

- EC2 instance;
- IAM role;
- IAM instance profile.

The validated baseline instance type is:

`t3.micro`

Security-oriented compute configuration includes:

- no public IP assignment;
- EC2 metadata controls;
- detailed monitoring;
- dedicated security-group attachment;
- IAM role-based workload permissions.

The AMI is resolved dynamically through AWS Systems Manager Parameter Store rather than hardcoding an AMI identifier into the architecture.

---

### 5.3 AWS Logging and Encryption

VPC network telemetry is sent through:

```text
VPC
 |
 v
VPC Flow Logs
 |
 v
CloudWatch Log Group
 |
 v
KMS Encryption
```
A dedicated IAM role allows the VPC Flow Logs service to publish the required log data.

The CloudWatch log group uses a dedicated KMS key, providing encrypted network-flow evidence.

---

### 5.4 AWS Cost Governance

AWS cost governance contains two distinct layers:

### Modeled Cost

Infracost evaluates the Terraform configuration before deployment.

The validated modeled AWS baseline was approximately:

`USD 11 / month`

with the EC2 t3.micro instance as the primary modeled cost driver.

### Native Budget

Terraform provisions an AWS Budget with a monthly threshold of:

`USD 25`

This provides provider-native cost governance in addition to pre-deployment modeling.

---

## 6. Azure Architecture

The Azure implementation is deployed in the approved region:

`Canada Central`

The Terraform environment contains:

- Resource Group;
- Virtual Network;
- compute subnet;
- Network Security Group;
- subnet/NSG association;
- Network Interface;
- Linux Virtual Machine;
- Azure Consumption Budget.

Conceptually:

```text
Azure / Canada Central
|
+-- Resource Group
    |
    +-- Virtual Network
    |    |
    |    +-- Compute Subnet
    |          |
    |          +-- Network Security Group
    |          |
    |          +-- Network Interface
    |                 |
    |                 +-- Linux VM
    |
    +-- Consumption Budget
```
---

### 6.1 Azure Networking

The networking module provisions:

- Virtual Network;
- compute subnet;
- Network Security Group;
- subnet-to-NSG association.

The compute subnet explicitly disables default outbound access:

`default_outbound_access_enabled = false`

This prevents reliance on implicit platform-provided outbound connectivity.

The VM is not assigned a public IP.

---

### 6.2 Azure Compute

The validated baseline VM size is:

`Standard_D2s_v3`

The VM uses:

- private IP addressing;
- no public IP;
- system-assigned managed identity;
- Secure Boot;
- virtual TPM.

The architecture therefore incorporates both network-level and workload-level security controls.

---

### 6.3 Azure Identity

The Linux VM uses a system-assigned managed identity.

This avoids embedding application credentials directly into the VM configuration and provides an Azure-native identity that can be authorized independently if workload access is required.

This workload identity is separate from the GitHub Actions federated identities used by CI/CD.

---

### 6.4 Azure Cost Governance

Azure also uses separate modeled and provider-native cost controls.

### Modeled Cost

The validated pre-deployment Infracost baseline was approximately:

`USD 72 / month`

with Standard_D2s_v3 as the primary modeled VM SKU.

### Native Budget

Terraform provisions a Resource Group-scoped Azure Consumption Budget with a threshold of:

`100`

Provider-native billing reports retain their native billing currency rather than being artificially combined with AWS billing data.

---

## 7. Multi-Cloud Governance Architecture

The platform intentionally implements governance above the individual cloud environments.

The governance layer evaluates both infrastructure definitions and live infrastructure state.

Major controls include:

```text
Terraform Validation
        |
        +--> Checkov
        |
        +--> Region Policy
        |
        +--> Mandatory Tag Policy
        |
        +--> Infracost
        |
        +--> Cost Threshold Policy
        |
        +--> Runtime Compliance
```
This provides defense in depth.

A single successful Terraform validation does not imply that the infrastructure is compliant with organizational requirements.

---

### 7.1 Region Governance

Approved deployment regions are:

| Cloud | Approved Region |
| ----- | --------------- |
| AWS   | `us-east-1`     |
| Azure | `canadacentral` |

Custom governance scripts validate these requirements.

Violation fixtures demonstrate that infrastructure targeting other regions is rejected.

---

### 7.2 Mandatory Tag Governance

The governance platform requires standardized metadata including:

| Tag                  | Purpose                                    |
| -------------------- | ------------------------------------------ |
| `Project`            | associates resources with the project      |
| `Environment`        | identifies lifecycle environment           |
| `Owner`              | identifies accountable ownership           |
| `CostCenter`         | supports cost allocation                   |
| `BusinessUnit`       | maps resources to organizational ownership |
| `DataClassification` | provides governance/security context       |

Missing-tag violation fixtures are maintained under:

`examples/violations/`

This allows negative-path governance behavior to be tested intentionally.

---

## 8. FinOps Architecture

The FinOps architecture distinguishes three concepts that should not be conflated:

1 .modeled infrastructure cost;
2. governance thresholds;
3. actual provider billing.

### 8.1 Modeled Cost

Infracost evaluates planned Terraform infrastructure before deployment.

Validated planning baselines were approximately:

| Cloud | Modeled Monthly Cost |
| ----- | -------------------: |
| AWS   |               USD 11 |
| Azure |               USD 72 |

These estimates represent infrastructure pricing assumptions rather than provider invoices.

### 8.2 Governance Thresholds

The project evaluates configured cost thresholds:

| Cloud | Cost Threshold |
| ----- | -------------: |
| AWS   |             25 |
| Azure |            100 |

Violation fixtures intentionally exceed these thresholds to validate DENY behavior.

### 8.3 Actual Provider Billing

Separate scripts collect provider-native cost information.

The reporting architecture preserves native currencies and does not simply add unrelated currency values together.

```
AWS Billing Data --------+
                         |
                         +--> Multi-Cloud Cost Summary
                         |
Azure Billing Data ------+
```
The multi-cloud report therefore provides aggregation and visibility without presenting an invalid cross-currency total.

----

## 9. GitHub OIDC Trust Architecture

A major security design goal is eliminating long-lived cloud credentials from GitHub Actions.

The authentication model is:

```
GitHub Actions
      |
      v
GitHub OIDC Token
      |
      +----------------------+
      |                      |
      v                      v
AWS IAM Federation      Azure Federation
      |                      |
      v                      v
Short-Lived AWS         Short-Lived Azure
Credentials             Authentication
```
No workflow requires:
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AZURE_CLIENT_SECRET
```
---

### 9.1 AWS Identity Separation

AWS uses separate identities for deployment-oriented operations and controlled remediation.

Conceptually:
```
GitHub OIDC
   |
   +--> Deployment IAM Role
   |
   +--> Dedicated Remediation IAM Role
```
The remediation role is intentionally separate so that a remediation workflow does not automatically inherit general infrastructure-management authority.

---

### 9.2 Azure Identity Separation

Azure follows the same principle:

```
GitHub OIDC
   |
   +--> Deployment Federated Identity
   |
   +--> Dedicated Remediation Federated Identity
```
The remediation identity receives only the permissions required for the governed remediation use case.

This creates a clear trust boundary between planning/deployment operations and controlled cloud mutation.

---

## 10. Pull-Request Governance Flow

Infrastructure changes are evaluated through the PR Governance workflow.

Conceptually:

```
Pull Request
     |
     v
Repository Safety
     |
     v
Terraform Static Validation
     |
     v
Checkov
     |
     v
Custom Governance
     |
     v
FinOps Policy
     |
     v
Governance Result
     |
  +--+--+
  |     |
 PASS  FAIL
```
The workflow validates infrastructure and governance behavior before the change is considered acceptable.

The project includes both successful and intentionally failing historical workflow evidence.

---

## 11. Resolved Cost Governance

Static configuration alone may not contain every provider-resolved value required for accurate infrastructure analysis.

The Resolved Cost Governance workflow therefore authenticates to AWS and Azure using OIDC and performs provider-aware Terraform planning.

Conceptually:
```
GitHub Actions
      |
      v
GitHub OIDC
      |
 +----+----+
 |         |
 v         v
AWS       Azure
 |         |
 v         v
Terraform Resolved Plans
      |
      v
Infracost
      |
      v
Cost Policy
      |
      v
Resolved Cost Gate
```
This workflow is intended for planning and governance.

It does not automatically perform Terraform infrastructure mutation.

---

## 12. Runtime Compliance Architecture

Pre-deployment governance is complemented by runtime validation.

### 12.1 AWS Runtime Compliance

The AWS compliance scanner validates deployed infrastructure against expected controls.

The final validated AWS result was:

`15 / 15 controls passed`

The checks cover governance characteristics such as region, tags, infrastructure controls, logging/encryption, and budget configuration.

### 12.2 Azure Runtime Compliance

The Azure compliance scanner performs equivalent cloud-specific validation.

The final validated result was:

`18 / 18 controls passed`

### 12.3 Multi-Cloud Aggregation

The cloud-specific results are aggregated:
```
AWS Compliance:    15 / 15
                         \
                          +--> Multi-Cloud: 33 / 33
                         /
Azure Compliance:  18 / 18
```
This allows centralized reporting while retaining cloud-specific control implementations.

---

## 13. Controlled Remediation Architecture

Controlled remediation is intentionally designed as a separate security domain.

The lifecycle is:
```
Governance Finding
       |
       v
Recommendation Engine
       |
       v
Allow-Listed Action?
       |
   +---+---+
   |       |
  NO      YES
   |       |
   v       v
 DENY   Human Approval
           |
           v
   Exact Confirmation Token
           |
           v
     Approval Validator
           |
       +---+---+
       |       |
     DENY    ALLOW
               |
               v
         GitHub OIDC
               |
        +------+------+
        |             |
        v             v
   AWS Remediation Azure Remediation
        |             |
        v             v
  Scoped Mutation  Scoped Mutation
        |             |
        +------+------+
               |
               v
     Post-Change Verification
               |
               v
       Terraform Detects Drift
               |
               v
       Terraform Reconciliation
               |
               v
          Final Zero Drift
```
---

### 13.1 Recommendation Boundary

The recommendation engine converts a supported governance finding into a structured remediation recommendation.

A recommendation does not authorize execution.

The supported mutation class is deliberately narrow:

`set-tag`

with:

`CostCenter`

as the governed tag.

---

### 13.2 Human Approval Boundary

Remediation requires an explicit confirmation token following the approved remediation identifier.

Conceptually:

`APPROVE:<remediation-id>`

The approval validator compares:

- remediation ID;
- cloud;
- target resource;
- action;
- tag key;
- current value;
- desired value;
- pre-approval evidence;
- confirmation token.

Any mismatch results in DENY behavior.

---

### 13.3 AWS Mutation Boundary

The AWS executor permits the approved CostCenter mutation through:

`aws ec2 create-tags`

Before mutation, the executor verifies that the live resource still matches the approved before-state.

After mutation, the live tag is queried again to verify the expected value.

### 13.4 Azure Mutation Boundary

The Azure executor performs the equivalent controlled operation using:

`az tag update`

The same before-state and post-change verification principles apply.

### 13.5 Terraform Authority

The controlled remediation operation deliberately changes a Terraform-managed property outside Terraform.

This creates expected drift.

The lifecycle demonstrates:

```text
Terraform State
      |
      | initially matches
      v
Cloud Resource
      |
      | approved remediation changes CostCenter
      v
Runtime Drift
      |
      | terraform plan
      v
Drift Detected
      |
      | controlled reconciliation
      v
Terraform-Authoritative Value Restored
      |
      v
Zero Drift
```
This is an important architectural property.

The remediation system is not treated as a replacement for Infrastructure as Code.

Terraform remains authoritative.

---

## 14. Fail-Closed Architecture

A safe remediation platform must prove not only that authorized mutation works, but also that unauthorized mutation does not occur.

The project therefore includes DENY-path validation.

Failure scenarios validate conditions such as:

- invalid approval;
- mismatched evidence;
- unsupported action;
- invalid resource;
- incorrect current state;
- invalid desired value;
- missing or incorrect confirmation;
- previously executed evidence;
- other inconsistent remediation inputs.

The expected behavior is:
```
Invalid Request
     |
     v
Validation Failure
     |
     v
DENY
     |
     v
No Cloud Mutation
```
This behavior is part of the platform's security architecture rather than merely a test convenience.

---

## 15. Evidence Architecture

Operational evidence is separated from portfolio-safe evidence.

### 15.1 Raw Operational Reports

Cloud-generated or runtime reports may contain:

- cloud account identifiers;
- subscription identifiers;
- tenant identifiers;
- IAM ARNs;
- user identifiers;
- resource identifiers.

These reports remain local and Git-ignored when they are not suitable for public publication.

### 15.2 Curated Evidence

Sanitized evidence is intentionally committed under:
```
reports/
├── compliance/
├── cost/
└── remediation/
```
Tracked evidence includes:

- AWS compliance evidence;
- Azure compliance evidence;
- multi-cloud compliance evidence;
- AWS cost summary;
- Azure cost summary;
- multi-cloud cost summary;
- modeled cost baseline;
- AWS remediation execution evidence;
- Azure remediation execution evidence;
- cross-cloud remediation summary;
- DENY-test summary.

The architecture therefore establishes an evidence-publication boundary:
```
Cloud / Runtime Data
        |
        v
Operational Reports
        |
        v
Sanitization / Curation
        |
   +----+----+
   |         |
   v         v
Local Raw   Public-Safe
Evidence    Evidence
Ignored     Tracked in Git
```
---

## 16. Security and Trust Boundaries

The platform has several explicit trust boundaries.

| Boundary                         | Purpose                                                      |
| -------------------------------- | ------------------------------------------------------------ |
| GitHub repository                | controls versioned infrastructure and governance definitions |
| Pull-request governance          | validates proposed changes                                   |
| GitHub OIDC                      | establishes short-lived cloud federation                     |
| AWS IAM                          | authorizes AWS workflow capabilities                         |
| Azure federated identity/RBAC    | authorizes Azure workflow capabilities                       |
| Human remediation approval       | prevents autonomous mutation                                 |
| Remediation validator            | validates recommendation and approval integrity              |
| Dedicated remediation identities | constrain mutation permissions                               |
| Evidence-publication boundary    | prevents raw sensitive operational data from being published |

These boundaries reduce the likelihood that a compromise or logic error in one component automatically grants unrestricted access to another.

---

## 17. Architecture Design Decisions

Several design decisions are central to the platform.

### Terraform remains authoritative

Runtime remediation is reconciled back through Terraform rather than allowing two competing configuration authorities.

### Governance is multi-layered

Terraform validation, Checkov, custom policies, cost governance, runtime compliance, and remediation validation solve different problems and are intentionally complementary.

### Cloud-specific controls remain explicit

AWS and Azure use equivalent governance concepts, but the implementation does not hide important provider-specific behavior behind unnecessary abstraction.

### Authentication and authorization are separate concerns

OIDC establishes identity. IAM and Azure RBAC determine what that identity may actually do.

### Remediation identities are isolated

A workflow capable of changing a tag does not need unrestricted infrastructure-management permissions.

### Cost evidence types remain distinct

Modeled estimates, governance thresholds, and provider billing are not represented as if they were the same measurement.

### Evidence is treated as an architectural concern

Sanitization and publication rules are designed into the platform rather than performed as an afterthought.

---

## 18. Architecture Validation

Before documentation closure, the implementation was validated against the architecture.

Key validated facts included:

- AWS Terraform modules: networking, compute, budget;
- Azure Terraform modules: networking, compute, budget;
- AWS baseline instance: t3.micro;
- Azure baseline VM: Standard_D2s_v3;
- AWS EC2 public-IP assignment disabled;
- Azure VM has no public IP;
- Azure subnet default outbound access disabled;
- Azure Secure Boot enabled;
- Azure vTPM enabled;
- AWS VPC Flow Logs enabled;
- CloudWatch logging protected with KMS;
- AWS monthly budget configured at USD 25;
- Azure monthly budget configured at 100;
- GitHub Actions OIDC authentication validated;
- no static AWS access keys required by workflows;
- no Azure client secret required by workflows;
- AWS remediation restricted to controlled tag mutation;
- Azure remediation restricted to controlled tag mutation;
- human approval required before remediation;
- AWS runtime compliance: 15/15;
- Azure runtime compliance: 18/18;
- aggregate compliance: 33/33;
- Terraform zero drift verified after reconciliation.

The environment was subsequently destroyed after evidence collection and validation to avoid unnecessary cloud cost.

---

## 19. Architecture Outcome

The resulting architecture demonstrates an end-to-end enterprise governance lifecycle:
```
CODE
 |
 v
POLICY
 |
 v
COST
 |
 v
IDENTITY
 |
 v
CLOUD
 |
 v
COMPLIANCE
 |
 v
REMEDIATION
 |
 v
RECONCILIATION
 |
 v
EVIDENCE
```
Rather than treating FinOps, DevSecOps, Infrastructure as Code, compliance, and remediation as isolated capabilities, this project integrates them into one multi-cloud governance operating model.
EOF

Now validate it:

```bash
echo "===== ARCHITECTURE DOCUMENT VALIDATION ====="

wc -l docs/architecture.md

echo
echo "----- Placeholder / sensitive identifier audit -----"

grep -nE \
  'TODO|TBD|FIXME|<AWS_ACCOUNT_ID>|<AZURE_SUBSCRIPTION_ID>|<AZURE_TENANT_ID>|kapil\.azure\.lab@gmail\.com' \
  docs/architecture.md \
  || echo "PASS - no placeholders or sensitive identifiers"

echo
echo "----- Required architecture concepts -----"

for term in \
  'GitHub OIDC' \
  'Infracost' \
  'VPC Flow Logs' \
  'Secure Boot' \
  'Controlled Remediation' \
  'Terraform Reconciliation' \
  '33 / 33' \
  'Evidence Architecture'
do
  if grep -Fq "$term" docs/architecture.md; then
    echo "PASS - $term"
  else
    echo "FAIL - $term"
  fi
done

echo
echo "----- Markdown integrity -----"

git diff --check

echo
echo "----- Repository state -----"

git status --short
```
