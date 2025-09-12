variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "isms-golden-ami"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID for Image Builder resources"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Image Builder instances"
  type        = string
}

variable "kms_key_id" {
  description = "KMS Key ID for encryption"
  type        = string
  default     = ""
}

variable "instance_types" {
  description = "Instance types for Image Builder"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "allowed_principals" {
  description = "AWS account IDs allowed to use the AMI"
  type        = list(string)
  default     = []
}