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
  member_account_ids = toset(data.aws_organizations_organization.main.non_master_accounts[*].id)
  all_account_ids    = toset(data.aws_organizations_organization.main.accounts[*].id)

  config               = yamldecode(file("${path.module}/../config.yaml"))
  alternate_contacts   = local.config["alternate_contacts"]
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
    "detail.page" = [
      "1"
    ]
  })
}
