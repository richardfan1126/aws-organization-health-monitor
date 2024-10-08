resource "aws_sns_topic" "account_health_notification" {
  for_each = local.all_account_ids
  name     = "account-health-notification-${each.key}"
}

resource "aws_cloudwatch_log_group" "step_function_log_group" {
  name = "/aws/vendedlogs/states/publish-account-health-notification-Logs"
}

resource "aws_iam_role" "step_function_role" {
  name = "account-health-notification-step-function-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "step_function_policy" {
  statement {
    actions = [
      "sns:Publish"
    ]

    resources = [
      "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:account-health-notification-*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy" "step_function_policy" {
  name = "account-health-notification-step-function"
  role = aws_iam_role.step_function_role.id

  policy = data.aws_iam_policy_document.step_function_policy.json
}

resource "aws_sfn_state_machine" "publish_account_health_notification" {
  name     = "publish-account-health-notification"
  type     = "EXPRESS"
  role_arn = aws_iam_role.step_function_role.arn

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_function_log_group.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  definition = <<EOF
{
  "Comment": "A state machine to publish AWS Health events to the relative SNS topic",
  "StartAt": "SNS Publish",
  "States": {
    "SNS Publish": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:sns:publish",
      "Parameters": {
        "Message.$": "$",
        "TopicArn.$": "States.Format('arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:account-health-notification-{}',$.detail.affectedAccount)"
      },
      "End": true
    }
  }
}
EOF
}

resource "aws_iam_role" "cloudwatch_event_role" {
  name = "account-health-notification-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "invoke_step_function" {
  statement {
    actions = [
      "states:StartExecution"
    ]

    resources = [
      aws_sfn_state_machine.publish_account_health_notification.arn
    ]
  }
}

resource "aws_iam_role_policy" "cloudwatch_event_invoke_step_function" {
  name = "account-health-notification-invoke-step-function"
  role = aws_iam_role.cloudwatch_event_role.id

  policy = data.aws_iam_policy_document.invoke_step_function.json
}

resource "aws_cloudwatch_event_rule" "account_health_notification" {
  name = "account-health-notification"

  event_pattern = jsonencode({
    detail-type = [
      "AWS Health Event",
      "AWS Health Abuse Event"
    ]
    source = [
      "aws.health"
    ]
  })
}

resource "aws_cloudwatch_event_target" "account_health_notification" {
  rule      = aws_cloudwatch_event_rule.account_health_notification.name
  target_id = "account-health-notification"

  arn      = aws_sfn_state_machine.publish_account_health_notification.arn
  role_arn = aws_iam_role.cloudwatch_event_role.arn
}
