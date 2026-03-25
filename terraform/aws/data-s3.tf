# ════════════════════════════════════════════════════════════
# Local values for Lambda environment variables
# S3 bucket bilgileri hardcoded (bucket zaten var, ACL okuma yetkisi yok)
# ════════════════════════════════════════════════════════════

data "aws_caller_identity" "current" {}

locals {
  s3_bucket_name      = "finans-asistan-backups-${var.environment}"
  s3_bucket_arn       = "arn:aws:s3:::finans-asistan-backups-${var.environment}"
  worker_asg_name     = "finans-asistan-worker-pool-${var.environment}"
  leader_asg_name     = "finans-asistan-leader-pool-${var.environment}"
}

