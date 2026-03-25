# ════════════════════════════════════════════════════════════
# FinansAsistan - k3s Snapshot Lambda
# Automatically creates k3s/etcd snapshots and uploads to S3
# ════════════════════════════════════════════════════════════

# IAM Role for Lambda
resource "aws_iam_role" "lambda_k3s_snapshot" {
  name = "finans-lambda-k3s-snapshot-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_k3s_snapshot" {
  name = "finans-lambda-k3s-snapshot-policy-${var.environment}"
  role = aws_iam_role.lambda_k3s_snapshot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${local.s3_bucket_arn}",
          "${local.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.ec2_auto_start_alerts.arn
      }
    ]
  })
}

# Archive Lambda function
data "archive_file" "lambda_k3s_snapshot" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/k3s-snapshot"
  output_path = "${path.module}/lambda-k3s-snapshot.zip"
}

resource "aws_lambda_function" "k3s_snapshot" {
  filename         = data.archive_file.lambda_k3s_snapshot.output_path
  function_name    = "finans-k3s-snapshot"
  role            = aws_iam_role.lambda_k3s_snapshot.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300  # 5 dakika
  memory_size     = 256

  source_code_hash = data.archive_file.lambda_k3s_snapshot.output_base64sha256

  environment {
    variables = {
      S3_BUCKET     = local.s3_bucket_name
      SNS_TOPIC_ARN = aws_sns_topic.ec2_auto_start_alerts.arn
    }
  }

  tags = {
    Name = "FinansAsistan k3s Snapshot"
  }
}

# EventBridge Rule (Her 6 saatte bir çalışır)
# DISABLED: Snapshot'lar artık leader node'da cron job ile alınıyor
# resource "aws_cloudwatch_event_rule" "k3s_snapshot_schedule" {
#   name                = "finans-k3s-snapshot-schedule"
#   description         = "Create k3s snapshot every 6 hours"
#   schedule_expression = "rate(6 hours)"
# }

# DISABLED: Snapshot'lar artık leader node'da cron job ile alınıyor
# resource "aws_cloudwatch_event_target" "k3s_snapshot_target" {
#   rule      = aws_cloudwatch_event_rule.k3s_snapshot_schedule.name
#   target_id = "FinansK3sSnapshotTarget"
#   arn       = aws_lambda_function.k3s_snapshot.arn
# }
# 
# resource "aws_lambda_permission" "k3s_snapshot_eventbridge" {
#   statement_id  = "AllowExecutionFromEventBridge"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.k3s_snapshot.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.k3s_snapshot_schedule.arn
# }

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_k3s_snapshot" {
  name              = "/aws/lambda/${aws_lambda_function.k3s_snapshot.function_name}"
  retention_in_days = 7
}

# Outputs
output "lambda_k3s_snapshot_arn" {
  value       = aws_lambda_function.k3s_snapshot.arn
  description = "ARN of k3s Snapshot Lambda function"
}

