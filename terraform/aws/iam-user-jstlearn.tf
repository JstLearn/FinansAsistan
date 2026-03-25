# ════════════════════════════════════════════════════════════
# FinansAsistan - JstLearn IAM User
# ════════════════════════════════════════════════════════════

# JstLearn IAM User
resource "aws_iam_user" "jstlearn" {
  name = "JstLearn"
  
  tags = {
    Name        = "JstLearn"
    Project     = "FinansAsistan"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# JstLearn Policy (from JSON file)
resource "aws_iam_user_policy" "jstlearn" {
  name = "JstLearnPolicy"
  user = aws_iam_user.jstlearn.name
  
  policy = file("${path.module}/policies/JstLearnPolicy.json")
}

# Outputs
output "jstlearn_user_name" {
  description = "JstLearn IAM user name"
  value       = aws_iam_user.jstlearn.name
}

output "jstlearn_user_arn" {
  description = "JstLearn IAM user ARN"
  value       = aws_iam_user.jstlearn.arn
}

