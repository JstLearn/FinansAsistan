# ════════════════════════════════════════════════════════════
# FinansAsistan - ECR Repositories
# Docker image registry
# ════════════════════════════════════════════════════════════

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

# ECR Repository for Backend
resource "aws_ecr_repository" "backend" {
  name                 = "finans-asistan-backend-${var.environment}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = {
    Name = "finans-asistan-backend-${var.environment}"
    Type = "container-registry"
  }
}

# ECR Repository for Frontend
resource "aws_ecr_repository" "frontend" {
  name                 = "finans-asistan-frontend-${var.environment}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = {
    Name = "finans-asistan-frontend-${var.environment}"
    Type = "container-registry"
  }
}

# ECR Repository for Event Processor
resource "aws_ecr_repository" "event_processor" {
  name                 = "finans-asistan-event-processor-${var.environment}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = {
    Name = "finans-asistan-event-processor-${var.environment}"
    Type = "container-registry"
  }
}

# Lifecycle Policy - Keep last 10 images
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "event_processor" {
  repository = aws_ecr_repository.event_processor.name
  
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Outputs
output "backend_repository_url" {
  value       = aws_ecr_repository.backend.repository_url
  description = "ECR repository URL for backend"
}

output "frontend_repository_url" {
  value       = aws_ecr_repository.frontend.repository_url
  description = "ECR repository URL for frontend"
}

output "event_processor_repository_url" {
  value       = aws_ecr_repository.event_processor.repository_url
  description = "ECR repository URL for event-processor"
}

data "aws_caller_identity" "current" {}

output "ecr_registry_url" {
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  description = "ECR registry URL"
}

