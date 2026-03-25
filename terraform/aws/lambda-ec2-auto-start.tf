# ════════════════════════════════════════════════════════════
# FinansAsistan - Lambda EC2 Auto-Start
# Otomatik EC2 başlatma (sistem kapalıyken)
# ════════════════════════════════════════════════════════════

# SNS Topic (Alert'ler için)
resource "aws_sns_topic" "ec2_auto_start_alerts" {
  name = "finans-ec2-auto-start-alerts"
  
  tags = {
    Name = "FinansAsistan EC2 Auto-Start Alerts"
  }
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_ec2_auto_start" {
  name = "finans-lambda-ec2-auto-start"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda IAM Policy
resource "aws_iam_role_policy" "lambda_ec2_auto_start" {
  name = "finans-lambda-ec2-auto-start-policy"
  role = aws_iam_role.lambda_ec2_auto_start.id

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
          "autoscaling:SetDesiredCapacity",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${local.s3_bucket_arn}/current-leader.json"
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

# Lambda Function
data "archive_file" "lambda_ec2_auto_start" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/ec2-auto-start"
  output_path = "${path.module}/lambda-ec2-auto-start.zip"
}

resource "aws_lambda_function" "ec2_auto_start" {
  filename         = data.archive_file.lambda_ec2_auto_start.output_path
  function_name    = "finans-ec2-auto-start"
  role            = aws_iam_role.lambda_ec2_auto_start.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300  # 5 dakika
  memory_size     = 256

  source_code_hash = data.archive_file.lambda_ec2_auto_start.output_base64sha256

  environment {
    variables = {
      ASG_NAME          = local.worker_asg_name
      LEADER_ASG_NAME   = local.leader_asg_name
      S3_BUCKET         = local.s3_bucket_name
      SNS_TOPIC_ARN     = aws_sns_topic.ec2_auto_start_alerts.arn
    }
  }

  tags = {
    Name = "FinansAsistan EC2 Auto-Start"
  }
}

# EventBridge Rule (Her 2 dakikada bir çalışır)
resource "aws_cloudwatch_event_rule" "ec2_auto_start_schedule" {
  name                = "finans-ec2-auto-start-schedule"
  description         = "Check if system is down and launch EC2 if needed"
  schedule_expression = "rate(2 minutes)"
}

resource "aws_cloudwatch_event_target" "ec2_auto_start_target" {
  rule      = aws_cloudwatch_event_rule.ec2_auto_start_schedule.name
  target_id = "FinansEC2AutoStartTarget"
  arn       = aws_lambda_function.ec2_auto_start.arn
}

resource "aws_lambda_permission" "ec2_auto_start_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_auto_start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_auto_start_schedule.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_ec2_auto_start" {
  name              = "/aws/lambda/${aws_lambda_function.ec2_auto_start.function_name}"
  retention_in_days = 7
}

# Outputs
output "lambda_ec2_auto_start_arn" {
  value       = aws_lambda_function.ec2_auto_start.arn
  description = "ARN of EC2 Auto-Start Lambda function"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.ec2_auto_start_alerts.arn
  description = "ARN of SNS topic for alerts"
}

