locals {
  config         = yamldecode(file("${path.module}/../../config.yaml"))
  ops_account_id = local.config["ops_account_id"]
}

resource "aws_organizations_delegated_administrator" "account_management" {
  account_id        = local.ops_account_id
  service_principal = "account.amazonaws.com"
}
