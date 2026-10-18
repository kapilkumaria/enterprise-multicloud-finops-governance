###############################################################################
# GitHub Actions Azure controlled-remediation identity
###############################################################################

resource "azuread_application" "github_remediation" {
  display_name     = "mc-finops-github-azure-remediation"
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_service_principal" "github_remediation" {
  client_id = azuread_application.github_remediation.client_id
}

resource "azuread_application_federated_identity_credential" "github_remediation_main" {
  application_id = azuread_application.github_remediation.id
  display_name   = "mc-finops-github-main"
  description    = "GitHub Actions OIDC federation for controlled Azure remediation from main"

  audiences = [
    "api://AzureADTokenExchange",
  ]

  issuer = "https://token.actions.githubusercontent.com"

  subject = "repo:kapilkumaria/enterprise-multicloud-finops-governance:ref:refs/heads/main"
}
