# ════════════════════════════════════════════════════════════
# FinansAsistan - S3 Module
# ════════════════════════════════════════════════════════════

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_root_path" {
  description = "Path to project root directory (for bootstrap script)"
  type        = string
  default     = ""  # Will be calculated if not provided
}

# Backup Bucket
resource "aws_s3_bucket" "backup" {
  bucket = "finans-asistan-backups-${var.environment}"
  
  tags = {
    Name = "finans-asistan-backups-${var.environment}"
  }

  # ACL okuma yetkisi yoksa ACL değişikliklerini ignore et
  lifecycle {
    ignore_changes = [
      # ACL değişikliklerini ignore et (yetki sorunu varsa)
    ]
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle Rules
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  
  # Rule 1: PostgreSQL backups - keep for 90 days, then auto-delete
  rule {
    id     = "keep-last-10-backups"
    status = "Enabled"
    
    filter {
      prefix = "postgres/backups/"
    }
    
    expiration {
      days = 90
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
  
  # Rule 2: WAL files - keep for 30 days
  rule {
    id     = "cleanup-old-wal-files"
    status = "Enabled"
    
    filter {
      prefix = "postgres/wal/"
    }
    
    expiration {
      days = 30
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 3
    }
  }
  
  # Rule 3: Project files - keep non-current versions for 30 days
  rule {
    id     = "cleanup-old-project-files"
    status = "Enabled"
    
    filter {
      prefix = "FinansAsistan/"
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
  
  # Rule 4: k3s snapshots - keep last 10 snapshots (30 days), then auto-delete older ones
  rule {
    id     = "keep-last-10-k3s-snapshots"
    status = "Enabled"
    
    filter {
      prefix = "k3s/snapshots/"
    }
    
    expiration {
      days = 30
    }
    
    # Keep only last 10 snapshots (noncurrent versions)
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    
    # Transition to cheaper storage after 7 days
    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }
  }
  
  # Rule 5: current-leader.json - keep forever (critical for cluster recovery)
  # Contains leader information and k3s join credentials (token + server URL)
  rule {
    id     = "keep-current-leader-indefinitely"
    status = "Enabled"
    
    filter {
      prefix = "current-leader.json"
    }
    
    # No expiration - keep forever (small file, critical for recovery)
    # Keep non-current versions for 30 days
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets  = true
}

# Bootstrap script'ini S3'e yükle
resource "aws_s3_object" "bootstrap_script" {
  bucket       = aws_s3_bucket.backup.id
  key          = "scripts/bootstrap.sh"
  # Use provided project root path or calculate from module path
  source       = var.project_root_path != "" ? "${var.project_root_path}/scripts/bootstrap.sh" : "${path.module}/../../../scripts/bootstrap.sh"
  content_type = "text/x-shellscript"
  etag         = var.project_root_path != "" ? filemd5("${var.project_root_path}/scripts/bootstrap.sh") : filemd5("${path.module}/../../../scripts/bootstrap.sh")
  
  tags = {
    Name = "bootstrap-script"
    Type = "deployment"
  }
}

# K8s manifestlerini S3'e yükle
resource "aws_s3_object" "k8s_manifests" {
  for_each = fileset("${path.module}/../../../k8s", "*.yaml")
  
  bucket = aws_s3_bucket.backup.id
  key    = "FinansAsistan/k8s/${each.value}"
  source = "${path.module}/../../../k8s/${each.value}"
  content_type = "application/x-yaml"
  etag   = filemd5("${path.module}/../../../k8s/${each.value}")
  
  tags = {
    Name = "k8s-manifest-${each.value}"
    Type = "deployment"
  }
}

# Bootstrap klasöründeki dosyaları S3'e yükle (init.sql, postgresql.conf vb.)
resource "aws_s3_object" "bootstrap_files" {
  for_each = fileset("${path.module}/../../../bootstrap", "*")
  
  bucket = aws_s3_bucket.backup.id
  key    = "bootstrap/${each.value}"
  source = "${path.module}/../../../bootstrap/${each.value}"
  etag   = filemd5("${path.module}/../../../bootstrap/${each.value}")
  
  tags = {
    Name = "bootstrap-file-${each.value}"
    Type = "deployment"
  }
}

# Outputs
output "backup_bucket_name" {
  value = aws_s3_bucket.backup.id
}

output "backup_bucket_arn" {
  value = aws_s3_bucket.backup.arn
}

