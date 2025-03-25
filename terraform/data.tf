data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_organizations_organization" "main" {}

data "aws_chatbot_slack_workspace" "main" {
  slack_team_name = local.slack_workspace_name
}

resource "random_string" "random" {
  length  = 4
  special = false
  lower   = true
  upper   = false
  numeric = true
}

locals {
  member_account_ids = toset([for account in data.aws_organizations_organization.main.non_master_accounts : account.id if account.status == "ACTIVE"])
  all_account_ids    = toset([for account in data.aws_organizations_organization.main.accounts : account.id if account.status == "ACTIVE"])

  config               = yamldecode(file("${path.module}/../config.yaml"))
  alternate_contacts   = try(local.config["alternate_contacts"], { enabled : false })
  slack_workspace_name = local.config["slack_workspace_name"]
  deployment_regions   = local.config["deployment_regions"]

  project_name            = "account-health-notification-${random_string.random.id}"
  stackset_name           = "${local.project_name}-stackset"
  stackset_exec_role_name = "${local.project_name}-stackset-exec-role"

  slack_channel_name = "aws-health-notification"

  eventbridge_rule_pattern = jsonencode({
    detail-type = [
      "AWS Health Event",
    ]
    source = [
      "aws.health"
    ]
    "detail" = {
      "page" = [
        "1" # Avoid processing multiple pages of the same event
      ]
      "eventTypeCategory" = [
        "issue",
        "accountNotification",
        "scheduledChange",
        "investigation"
      ]
    }
  })
}
