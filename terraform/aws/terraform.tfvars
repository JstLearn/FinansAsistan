# AWS Configuration
aws_region = "eu-central-1"
environment = "production"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# EC2 Instance Configuration
worker_instance_type = "t4g.small"  # ARM-based, 2 vCPU, 2GB RAM, minimum cost
worker_min_size = 0                 # Baslangicta 0 node
worker_max_size = 50                # Maksimum 50 node
worker_desired_capacity = 0         # Baslangicta 0 node

# k3s Configuration (Initial node'dan alinacak)
# NOT: Bu degerleri initial node'dan aldiktan sonra guncelleyin!
k3s_token = ""
k3s_server_url = ""
