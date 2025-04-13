# SNS Topic
resource "aws_sns_topic" "account_health_notification" {
  for_each = local.all_account_ids
  name     = "${local.project_name}-${each.key}"
}

# Step Function
resource "aws_cloudwatch_log_group" "step_function_log_group" {
  name = "/aws/vendedlogs/states/${local.project_name}-step-function-Logs"
}

resource "aws_iam_role" "step_function_role" {
  name = "${local.project_name}-step-function-role"
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
      "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${local.project_name}-*"
    ]
  }

  # Allow invoking Bedrock model via inference profile
  statement {
    actions = [
      "bedrock:InvokeModel"
    ]

    resources = [
      "arn:aws:bedrock:*::foundation-model/${local.bedrock_model_id}"
    ]

    condition {
      test     = "StringLike"
      variable = "bedrock:InferenceProfileArn"
      values   = [aws_bedrock_inference_profile.amazon_nova_micro.arn]
    }
  }

  statement {
    actions = [
      "bedrock:InvokeModel"
    ]

    resources = [
      aws_bedrock_inference_profile.amazon_nova_micro.arn
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
  name = "${local.project_name}-step-function"
  role = aws_iam_role.step_function_role.id

  policy = data.aws_iam_policy_document.step_function_policy.json
}

resource "aws_sfn_state_machine" "publish_account_health_notification" {
  name     = local.project_name
  type     = "EXPRESS"
  role_arn = aws_iam_role.step_function_role.arn

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_function_log_group.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  definition = jsonencode({
    Comment       = "A state machine to publish AWS Health events to the relative SNS topic"
    QueryLanguage = "JSONata"
    StartAt       = "SNS Publish"
    States = {
      "SNS Publish" = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:sns:publish"
        Arguments = {
          Message  = "{% $states.input %}"
          TopicArn = "{% 'arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${local.project_name}-' & $states.input.detail.affectedAccount %}"
        },
        End = true
      }
    }
  })
}

# Centralized EventBridge
resource "aws_iam_role" "centralized_cloudwatch_event_role" {
  name = "${local.project_name}-centralized-event-role"
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

data "aws_iam_policy_document" "centralized_cloudwatch_event_policy" {
  statement {
    actions = [
      "states:StartExecution"
    ]

    resources = [
      aws_sfn_state_machine.publish_account_health_notification.arn
    ]
  }
}

resource "aws_iam_role_policy" "centralized_cloudwatch_event_role" {
  name = "${local.project_name}-centralized-event-role"
  role = aws_iam_role.centralized_cloudwatch_event_role.id

  policy = data.aws_iam_policy_document.centralized_cloudwatch_event_policy.json
}

resource "aws_cloudwatch_event_rule" "centralized_event_rule" {
  name           = "${local.project_name}-centralized-rule"
  event_bus_name = aws_cloudwatch_event_bus.centralized_event_bus.name

  event_pattern = local.eventbridge_rule_pattern
}

resource "aws_cloudwatch_event_target" "centralized_event_target" {
  rule           = aws_cloudwatch_event_rule.centralized_event_rule.name
  target_id      = local.project_name
  event_bus_name = aws_cloudwatch_event_bus.centralized_event_bus.name

  arn      = aws_sfn_state_machine.publish_account_health_notification.arn
  role_arn = aws_iam_role.centralized_cloudwatch_event_role.arn
}

resource "aws_cloudwatch_event_bus" "centralized_event_bus" {
  name = local.project_name
}

# IAM role for regional EventBridge
resource "aws_iam_role" "regional_cloudwatch_event_role" {
  name = "${local.project_name}-regional-event-role"
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

data "aws_iam_policy_document" "regional_cloudwatch_event_policy" {
  statement {
    actions = [
      "events:PutEvents"
    ]

    resources = [
      aws_cloudwatch_event_bus.centralized_event_bus.arn
    ]
  }
}

resource "aws_iam_role_policy" "regional_cloudwatch_event_role" {
  name = "${local.project_name}-regional-event-role"
  role = aws_iam_role.regional_cloudwatch_event_role.id

  policy = data.aws_iam_policy_document.regional_cloudwatch_event_policy.json
}

# IAM roles for StackSet
resource "aws_iam_role" "stackset_admin_role" {
  name = "${local.stackset_name}-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudformation.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringLike = {
            "aws:SourceArn" = "arn:aws:cloudformation:*:${data.aws_caller_identity.current.account_id}:stackset/${local.stackset_name}:*"
          }
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "stackset_admin_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.stackset_exec_role_name}"
    ]
  }
}

resource "aws_iam_role_policy" "stackset_admin_role" {
  name = "${local.stackset_name}-admin-policy"
  role = aws_iam_role.stackset_admin_role.id

  policy = data.aws_iam_policy_document.stackset_admin_role_policy.json
}

resource "aws_iam_role" "stackset_execution_role" {
  name = local.stackset_exec_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.stackset_admin_role.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "stackset_execution_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "cloudformation:CancelUpdateStack",
      "cloudformation:DescribeStackResources",
      "cloudformation:UpdateTerminationProtection",
      "cloudformation:DescribeStackResource",
      "cloudformation:DescribeStacks",
      "cloudformation:ContinueUpdateRollback",
      "cloudformation:RollbackStack",
      "cloudformation:DescribeStackEvents",
      "cloudformation:CreateStack",
      "cloudformation:DeleteStack",
      "cloudformation:TagResource",
      "cloudformation:UpdateStack",
      "cloudformation:UntagResource",
      "cloudformation:ListStackResources"
    ]
    resources = [
      "arn:aws:cloudformation:*:${data.aws_caller_identity.current.account_id}:stack/StackSet-${local.stackset_name}-*/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "events:TagResource",
      "events:DeleteRule",
      "events:PutTargets",
      "events:DescribeRule",
      "events:EnableRule",
      "events:PutRule",
      "events:RemoveTargets",
      "events:ListTargetsByRule",
      "events:UntagResource",
      "events:DisableRule"
    ]
    resources = [
      "arn:aws:events:*:${data.aws_caller_identity.current.account_id}:rule/${local.project_name}"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.regional_cloudwatch_event_role.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudformation:ListStacks",
      "events:ListRules"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "stackset_execution_role" {
  name = "${local.project_name}-stackset-exec-policy"
  role = aws_iam_role.stackset_execution_role.id

  policy = data.aws_iam_policy_document.stackset_execution_role_policy.json
}

# CloudFormation StackSet
resource "aws_cloudformation_stack_set" "regional_resource_stackset" {
  depends_on = [
    aws_iam_role.stackset_admin_role,
    aws_iam_role.stackset_execution_role,
    aws_iam_role_policy.stackset_admin_role,
    aws_iam_role_policy.stackset_execution_role
  ]

  name = local.stackset_name
  template_body = templatefile("${path.module}/templates/stackset.json.tpl", {
    eventPattern = local.eventbridge_rule_pattern
  })
  permission_model        = "SELF_MANAGED"
  administration_role_arn = aws_iam_role.stackset_admin_role.arn
  execution_role_name     = local.stackset_exec_role_name

  operation_preferences {
    max_concurrent_count    = 10
    failure_tolerance_count = 10
    region_concurrency_type = "PARALLEL"
  }

  parameters = {
    StackName              = local.project_name
    CentralizedEventBusArn = aws_cloudwatch_event_bus.centralized_event_bus.arn
    EventBridgeRoleArn     = aws_iam_role.regional_cloudwatch_event_role.arn
  }
}

resource "aws_cloudformation_stack_instances" "regional_resource_stackset_instance" {
  stack_set_name = aws_cloudformation_stack_set.regional_resource_stackset.name
  accounts = [
    data.aws_caller_identity.current.account_id
  ]
  regions = local.deployment_regions

  operation_preferences {
    max_concurrent_count    = 10
    failure_tolerance_count = 10
    region_concurrency_type = "PARALLEL"
  }
}
