# ════════════════════════════════════════════════════════════
# FinansAsistan - IAM Module
# ════════════════════════════════════════════════════════════

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "s3_backup_bucket" {
  description = "S3 backup bucket name"
  type        = string
}

# Worker Node IAM Role
resource "aws_iam_role" "worker" {
  name = "finans-asistan-worker-role-${var.environment}"
  
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
    Name = "finans-asistan-worker-role-${var.environment}"
  }
}

# S3 Access Policy
resource "aws_iam_role_policy" "s3_access" {
  name = "finans-asistan-s3-access-${var.environment}"
  role = aws_iam_role.worker.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_backup_bucket}",
          "arn:aws:s3:::${var.s3_backup_bucket}/*"
        ]
      }
    ]
  })
}

# EC2 Auto Scaling Policy (Cluster Autoscaler için)
resource "aws_iam_role_policy" "autoscaling" {
  name = "finans-asistan-autoscaling-${var.environment}"
  role = aws_iam_role.worker.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeImages",
          "ec2:GetInstanceTypesFromInstanceRequirements"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Logs Policy
resource "aws_iam_role_policy" "cloudwatch" {
  name = "finans-asistan-cloudwatch-${var.environment}"
  role = aws_iam_role.worker.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECR Access Policy (for pulling images)
resource "aws_iam_role_policy" "ecr_access" {
  name = "finans-asistan-ecr-access-${var.environment}"
  role = aws_iam_role.worker.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "worker" {
  name = "finans-asistan-worker-profile-${var.environment}"
  role = aws_iam_role.worker.name
  
  tags = {
    Name = "finans-asistan-worker-profile-${var.environment}"
  }
}

# Outputs
output "worker_instance_profile_name" {
  value = aws_iam_instance_profile.worker.name
}

output "worker_role_arn" {
  value = aws_iam_role.worker.arn
}

