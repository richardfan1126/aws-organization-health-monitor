resource "slack_conversation" "account_notification_channel" {
  for_each = local.all_account_ids

  name                               = "aws-health-notification-${each.key}"
  topic                              = "AWS notification for account ${each.key}"
  is_private                         = false
  adopt_existing_channel             = true
  action_on_update_permanent_members = "none"
  action_on_destroy                  = "none"
}

resource "aws_iam_role" "chatbot_role" {
  name = "${local.project_name}-chatbot-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_chatbot_slack_channel_configuration" "account_notification_channel" {
  for_each = local.all_account_ids

  configuration_name    = "${local.project_name}-${each.key}"
  slack_channel_id      = slack_conversation.account_notification_channel[each.key].id
  slack_team_id         = data.aws_chatbot_slack_workspace.main.slack_team_id
  iam_role_arn          = aws_iam_role.chatbot_role.arn
  sns_topic_arns        = [aws_sns_topic.account_health_notification[each.key].arn]
  guardrail_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}
