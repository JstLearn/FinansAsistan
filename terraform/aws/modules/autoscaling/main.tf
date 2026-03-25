# ════════════════════════════════════════════════════════════
# FinansAsistan - Auto Scaling Module
# ════════════════════════════════════════════════════════════

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "r6g.large"  # Memory-optimized for all nodes (16GB RAM, 2 vCPU) - Cost optimized
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 50
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 0
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "k3s_token" {
  description = "k3s join token. Optional - worker nodes will read from S3 current-leader.json if empty"
  type        = string
  sensitive   = true
  default     = ""
}

variable "k3s_server_url" {
  description = "k3s server URL (e.g., https://IP:6443). Optional - worker nodes will read from S3 current-leader.json if empty"
  type        = string
  default     = ""
}

variable "s3_bucket" {
  description = "S3 bucket name for backups and leadership"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "is_leader" {
  description = "Whether this ASG is for leader nodes (uses k3s server instead of agent)"
  type        = bool
  default     = false
}

# Launch Template
resource "aws_launch_template" "worker" {
  name_prefix   = "finans-asistan-worker-${var.environment}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  vpc_security_group_ids = var.security_group_ids
  
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }
  
  # Use leader user data script if this is a leader ASG, otherwise use worker script
  user_data = base64encode(templatefile(
    var.is_leader ? "${path.module}/user-data-leader.sh" : "${path.module}/user-data.sh",
    var.is_leader ? {
      s3_bucket  = var.s3_bucket
      AWS_REGION = var.aws_region
    } : {
    k3s_token     = var.k3s_token
    k3s_server_url = var.k3s_server_url
    s3_bucket     = var.s3_bucket
    AWS_REGION    = var.aws_region
    }
  ))
  
  # Spot instance için instance market options - Linux Spot Minimum Cost
  # Garanti yok: AWS kapasiteye ihtiyaç duyduğunda instance sonlandırılabilir (2 dakika uyarı)
  # Fiyat: On Demand'ın %70-90'ı kadar daha ucuz; fiyat değişken
  instance_market_options {
    market_type = "spot"
    spot_options {
      # Minimum cost optimization: max_price düşük tutularak AWS otomatik en düşük spot fiyatını seçer
      # R6G Large için yaklaşık $0.025-0.035/saat (On Demand'ın ~%30'u) - Cost optimized
      max_price                      = contains(["r8gd.large", "r6g.large", "r6g.medium"], var.instance_type) ? "0.05" : "0.005"
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"  # Spot interruption olduğunda terminate (2 dakika uyarı)
    }
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = contains(["r8gd.large", "r6g.medium", "r6g.large"], var.instance_type) && var.min_size == 0 && var.max_size == 1 ? "finans-asistan-leader-${var.environment}" : "finans-asistan-worker-${var.environment}"
      "k8s.io/cluster-autoscaler/enabled"        = "true"  # Enable autoscaler for all nodes (R6G Large for all)
      "k8s.io/cluster-autoscaler/finans-asistan" = "owned"
      k3s-role                                    = contains(["r8gd.large", "r6g.medium", "r6g.large"], var.instance_type) && var.min_size == 0 && var.max_size == 1 ? "leader" : "worker"
    }
  }
  
  tags = {
    Name = "finans-asistan-worker-lt-${var.environment}"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "worker" {
  name = contains(["r8gd.large", "r6g.medium", "r6g.large"], var.instance_type) && var.min_size == 0 && var.max_size == 1 ? "finans-asistan-leader-pool-${var.environment}" : "finans-asistan-worker-pool-${var.environment}"
  vpc_zone_identifier  = var.subnet_ids
  target_group_arns    = []
  health_check_type    = "EC2"
  health_check_grace_period = 300
  
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  
  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }
  
  # Spot instance için capacity rebalancing - Linux Spot Minimum Cost optimization
  # Spot interruption olduğunda (2 dakika uyarı) otomatik olarak yeni spot instance başlatır
  # Bu sayede kesintiye dayanıklılık artar (esnek iş yükleri için ideal)
  capacity_rebalance = true
  
  tag {
    key                 = "Name"
    value               = contains(["r8gd.large", "r6g.medium", "r6g.large"], var.instance_type) && var.min_size == 0 && var.max_size == 1 ? "finans-asistan-leader-${var.environment}" : "finans-asistan-worker-${var.environment}"
    propagate_at_launch = true
  }
  
  # Only enable cluster autoscaler for worker nodes (T4G Small), not leader nodes (R6G Medium)
  dynamic "tag" {
    for_each = [1]  # Enable for all nodes (R6G Large for all)
    content {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
    }
  }
  
  dynamic "tag" {
    for_each = [1]  # Enable for all nodes (R6G Large for all)
    content {
    key                 = "k8s.io/cluster-autoscaler/finans-asistan"
    value               = "owned"
    propagate_at_launch = true
    }
  }
}

# Data source for Ubuntu AMI (ARM64 for t4g instances)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# Outputs
output "worker_asg_name" {
  value = aws_autoscaling_group.worker.name
}

output "worker_asg_arn" {
  value = aws_autoscaling_group.worker.arn
}

