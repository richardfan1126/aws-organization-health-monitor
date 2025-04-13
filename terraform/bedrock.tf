resource "aws_bedrock_inference_profile" "amazon_nova_micro" {
  name = "Amazon Nova Micro for AWS Organization Health Monitor"

  model_source {
    copy_from = "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:inference-profile/${local.bedrock_inference_profile_region}.${local.bedrock_model_id}"
  }
}
