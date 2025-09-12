output "image_pipeline_arn" {
  description = "ARN of the Image Builder pipeline"
  value       = aws_imagebuilder_image_pipeline.isms_golden_ami_pipeline.arn
}

output "image_recipe_arn" {
  description = "ARN of the Image Builder recipe"
  value       = aws_imagebuilder_image_recipe.isms_golden_ami_recipe.arn
}

output "infrastructure_config_arn" {
  description = "ARN of the Infrastructure Configuration"
  value       = aws_imagebuilder_infrastructure_configuration.isms_infra_config.arn
}

output "distribution_config_arn" {
  description = "ARN of the Distribution Configuration"
  value       = aws_imagebuilder_distribution_configuration.isms_distribution_config.arn
}

output "security_hardening_component_arn" {
  description = "ARN of the ISMS Security Hardening Component"
  value       = aws_imagebuilder_component.isms_security_hardening.arn
}

output "cloudwatch_agent_component_arn" {
  description = "ARN of the CloudWatch Agent Configuration Component"
  value       = aws_imagebuilder_component.cloudwatch_agent_config.arn
}

output "s3_logs_bucket" {
  description = "S3 bucket for Image Builder logs"
  value       = aws_s3_bucket.image_builder_logs.bucket
}

output "instance_profile_name" {
  description = "Instance Profile name for Image Builder"
  value       = aws_iam_instance_profile.image_builder_instance_profile.name
}

output "security_group_id" {
  description = "Security Group ID for Image Builder instances"
  value       = aws_security_group.image_builder_sg.id
}