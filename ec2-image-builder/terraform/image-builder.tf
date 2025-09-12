# IAM Role for EC2 Image Builder Instance Profile
resource "aws_iam_role" "image_builder_instance_role" {
  name = "${var.project_name}-image-builder-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-image-builder-instance-role"
    Environment = var.environment
    Purpose     = "ISMS-Compliant-AMI-Building"
  }
}

resource "aws_iam_role_policy_attachment" "image_builder_instance_role_policy" {
  role       = aws_iam_role.image_builder_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.image_builder_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 Access Policy for Image Builder Logs
resource "aws_iam_role_policy" "image_builder_s3_logs_policy" {
  name = "${var.project_name}-image-builder-s3-logs-policy"
  role = aws_iam_role.image_builder_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.image_builder_logs.arn,
          "${aws_s3_bucket.image_builder_logs.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "image_builder_instance_profile" {
  name = "${var.project_name}-image-builder-instance-profile"
  role = aws_iam_role.image_builder_instance_role.name
}

# Security Group for Image Builder
resource "aws_security_group" "image_builder_sg" {
  name_prefix = "${var.project_name}-image-builder-"
  vpc_id      = var.vpc_id

  # Only allow outbound traffic for package updates and downloads
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound for package repositories"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for package repositories"
  }

  # NTP for time sync (ISMS requirement)
  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NTP for time synchronization"
  }

  # No inbound rules - managed via SSM Session Manager
  
  tags = {
    Name        = "${var.project_name}-image-builder-sg"
    Environment = var.environment
    Purpose     = "ISMS-Compliant-AMI-Building"
  }
}

# Component for ISMS Security Hardening
resource "aws_imagebuilder_component" "isms_security_hardening" {
  name     = "${var.project_name}-isms-security-hardening"
  platform = "Linux"
  version  = "1.0.0"
  
  data = yamlencode({
    name = "${var.project_name}-isms-security-hardening"
    description = "ISMS compliance security hardening for Golden AMI"
    schemaVersion = "1.0"
    
    phases = [{
      name = "build"
      steps = [{
        name = "ISMSSecurityHardening"
        action = "ExecuteBash"
        inputs = {
          commands = [
            file("${path.module}/../scripts/isms-security-hardening.sh")
          ]
        }
      }]
    }]
  })

  tags = {
    Name        = "${var.project_name}-isms-security-hardening"
    Environment = var.environment
    Purpose     = "ISMS-Compliance"
  }
}

# Component for CloudWatch Agent Configuration
resource "aws_imagebuilder_component" "cloudwatch_agent_config" {
  name     = "${var.project_name}-cloudwatch-agent-config"
  platform = "Linux"
  version  = "1.0.0"
  
  data = yamlencode({
    name = "${var.project_name}-cloudwatch-agent-config"
    description = "Configure CloudWatch Agent for ISMS monitoring requirements"
    schemaVersion = "1.0"
    
    phases = [{
      name = "build"
      steps = [{
        name = "ConfigureCloudWatchAgent"
        action = "ExecuteBash"
        inputs = {
          commands = [
            file("${path.module}/../scripts/cloudwatch-agent-config.sh")
          ]
        }
      }]
    }]
  })

  tags = {
    Name        = "${var.project_name}-cloudwatch-agent-config"
    Environment = var.environment
    Purpose     = "ISMS-Monitoring"
  }
}

# Image Recipe
resource "aws_imagebuilder_image_recipe" "isms_golden_ami_recipe" {
  name         = "${var.project_name}-recipe"
  parent_image = "arn:aws:imagebuilder:${local.region}:aws:image/amazon-linux-2023-x86/x.x.x"
  version      = "1.0.0"

  component {
    component_arn = "arn:aws:imagebuilder:${local.region}:aws:component/update-linux/x.x.x"
  }

  component {
    component_arn = aws_imagebuilder_component.isms_security_hardening.arn
  }

  component {
    component_arn = aws_imagebuilder_component.cloudwatch_agent_config.arn
  }

  block_device_mapping {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_id != "" ? var.kms_key_id : null
    }
  }

  tags = {
    Name        = "${var.project_name}-recipe"
    Environment = var.environment
    Purpose     = "ISMS-Golden-AMI"
  }
}

# Infrastructure Configuration
resource "aws_imagebuilder_infrastructure_configuration" "isms_infra_config" {
  name                          = "${var.project_name}-infrastructure-config"
  instance_profile_name         = aws_iam_instance_profile.image_builder_instance_profile.name
  instance_types                = var.instance_types
  security_group_ids            = [aws_security_group.image_builder_sg.id]
  subnet_id                     = var.subnet_id
  terminate_instance_on_failure = true

  logging {
    s3_logs {
      s3_bucket_name = aws_s3_bucket.image_builder_logs.bucket
      s3_key_prefix  = "build-logs/"
    }
  }


  tags = {
    Name        = "${var.project_name}-infrastructure-config"
    Environment = var.environment
    Purpose     = "ISMS-Golden-AMI-Infrastructure"
  }
}

# Distribution Configuration
resource "aws_imagebuilder_distribution_configuration" "isms_distribution_config" {
  name = "${var.project_name}-distribution-config"

  distribution {
    ami_distribution_configuration {
      name               = "${var.project_name}-{{ imagebuilder:buildDate }}"
      description        = "ISMS compliant Golden AMI built on {{ imagebuilder:buildDate }}"
      target_account_ids = length(var.allowed_principals) > 0 ? var.allowed_principals : null

      ami_tags = {
        Name         = "${var.project_name}-golden-ami"
        Environment  = var.environment
        BuildDate    = "{{ imagebuilder:buildDate }}"
        Purpose      = "ISMS-Compliant-Golden-AMI"
        Compliance   = "ISMS-K-21.1"
        BaseImage    = "Amazon Linux 2023"
        Hardened     = "true"
      }
    }

    region = local.region
  }

  tags = {
    Name        = "${var.project_name}-distribution-config"
    Environment = var.environment
    Purpose     = "ISMS-Golden-AMI-Distribution"
  }
}

# Image Pipeline
resource "aws_imagebuilder_image_pipeline" "isms_golden_ami_pipeline" {
  name                             = "${var.project_name}-pipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.isms_golden_ami_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.isms_infra_config.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.isms_distribution_config.arn
  
  status = "ENABLED"


  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 720
  }

  tags = {
    Name        = "${var.project_name}-pipeline"
    Environment = var.environment
    Purpose     = "ISMS-Golden-AMI-Pipeline"
  }
}

# S3 Bucket for logs
resource "aws_s3_bucket" "image_builder_logs" {
  bucket        = "${var.project_name}-image-builder-logs-${local.account_id}-${local.region}"
  force_destroy = false

  tags = {
    Name        = "${var.project_name}-image-builder-logs"
    Environment = var.environment
    Purpose     = "ISMS-Image-Builder-Logs"
  }
}

resource "aws_s3_bucket_versioning" "image_builder_logs" {
  bucket = aws_s3_bucket.image_builder_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "image_builder_logs" {
  bucket = aws_s3_bucket.image_builder_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id != "" ? var.kms_key_id : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "image_builder_logs" {
  bucket = aws_s3_bucket.image_builder_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}