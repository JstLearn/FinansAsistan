# ════════════════════════════════════════════════════════════
# FinansAsistan - Terraform Main Configuration
# AWS Infrastructure as Code
# ════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend configuration - State files stored in S3
  backend "s3" {
    bucket = "finans-asistan-backups"
    key    = "terraform/terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "FinansAsistan"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "r6g.large"  # Memory-optimized for all nodes (16GB RAM, 2 vCPU) - Cost optimized
}

variable "worker_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 0
}

variable "worker_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 50
}

variable "worker_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 0
}

variable "k3s_token" {
  description = "k3s join token (from initial node). Optional - worker nodes will read from S3 current-leader.json if empty"
  type        = string
  sensitive   = true
  default     = ""
}

variable "k3s_server_url" {
  description = "k3s server URL (e.g., https://IP:6443). Optional - worker nodes will read from S3 current-leader.json if empty"
  type        = string
  default     = ""
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "worker_asg_name" {
  description = "Auto Scaling Group name for worker nodes"
  value       = module.autoscaling.worker_asg_name
}

output "leader_asg_name" {
  description = "Auto Scaling Group name for leader node (R6G Large)"
  value       = module.leader_autoscaling.worker_asg_name
}

output "s3_backup_bucket" {
  description = "S3 bucket name for backups"
  value       = module.s3.backup_bucket_name
}

output "worker_security_group_id" {
  description = "Security group ID for worker nodes"
  value       = module.security_groups.worker_sg_id
}

output "ecr_backend_repository_url" {
  description = "ECR repository URL for backend"
  value       = module.ecr.backend_repository_url
}

output "ecr_frontend_repository_url" {
  description = "ECR repository URL for frontend"
  value       = module.ecr.frontend_repository_url
}

output "ecr_event_processor_repository_url" {
  description = "ECR repository URL for event-processor"
  value       = module.ecr.event_processor_repository_url
}

output "ecr_registry_url" {
  description = "ECR registry URL"
  value       = module.ecr.ecr_registry_url
}

# Modules
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr = var.vpc_cidr
  environment = var.environment
}

module "security_groups" {
  source = "./modules/security-groups"
  
  vpc_id = module.vpc.vpc_id
  environment = var.environment
}

module "iam" {
  source = "./modules/iam"
  
  environment = var.environment
  s3_backup_bucket = module.s3.backup_bucket_name
}

module "s3" {
  source = "./modules/s3"
  
  environment = var.environment
}

module "ecr" {
  source = "./modules/ecr"
  
  environment = var.environment
  aws_region = var.aws_region
}

module "autoscaling" {
  source = "./modules/autoscaling"
  
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.worker_sg_id]
  iam_instance_profile_name = module.iam.worker_instance_profile_name
  
  instance_type = var.worker_instance_type
  min_size = var.worker_min_size
  max_size = var.worker_max_size
  desired_capacity = var.worker_desired_capacity
  
  k3s_token = var.k3s_token
  k3s_server_url = var.k3s_server_url
  s3_bucket = module.s3.backup_bucket_name
  aws_region = var.aws_region
  
  environment = var.environment
}

# Leader Node ASG (R6G Large) - Auto-started by Lambda when no physical node
module "leader_autoscaling" {
  source = "./modules/autoscaling"
  
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.worker_sg_id]
  iam_instance_profile_name = module.iam.worker_instance_profile_name
  
  instance_type = "r6g.large"  # Memory-optimized for leader node (16GB RAM, 2 vCPU) - Cost optimized
  min_size = 0  # Only start when needed (Lambda will set to 1)
  max_size = 1  # Only one leader node
  desired_capacity = 0  # Start with 0, Lambda will start when needed
  
  is_leader = true  # This ASG is for leader nodes (uses k3s server)
  
  # Not needed for leader (uses k3s server, not agent)
  k3s_token = var.k3s_token
  k3s_server_url = var.k3s_server_url
  s3_bucket = module.s3.backup_bucket_name
  aws_region = var.aws_region
  
  environment = var.environment
}

