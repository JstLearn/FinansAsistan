# ════════════════════════════════════════════════════════════
# FinansAsistan - Security Groups Module
# ════════════════════════════════════════════════════════════

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# Worker Nodes Security Group
resource "aws_security_group" "worker" {
  name        = "finans-asistan-worker-${var.environment}"
  description = "Security group for k3s worker nodes"
  vpc_id      = var.vpc_id
  
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # k3s API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id == "" ? "0.0.0.0/0" : data.aws_vpc.main.cidr_block]
  }
  
  # k3s node port range
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "finans-asistan-worker-sg-${var.environment}"
  }
}

# Data source
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Outputs
output "worker_sg_id" {
  value = aws_security_group.worker.id
}

