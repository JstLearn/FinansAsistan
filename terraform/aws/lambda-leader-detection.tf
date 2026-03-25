# ════════════════════════════════════════════════════════════
# FinansAsistan - Lambda Leader Detection
# Liderlik durumunu kontrol eder ve gerekirse düzeltir
# ════════════════════════════════════════════════════════════

# Lambda IAM Role
resource "aws_iam_role" "lambda_leader_detection" {
  name = "finans-lambda-leader-detection"

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
resource "aws_iam_role_policy" "lambda_leader_detection" {
  name = "finans-lambda-leader-detection-policy"
  role = aws_iam_role.lambda_leader_detection.id

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
          "s3:PutObject"
        ]
        Resource = "${local.s3_bucket_arn}/current-leader.json"
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
          "sns:Publish"
        ]
        Resource = aws_sns_topic.ec2_auto_start_alerts.arn
      }
    ]
  })
}

# Lambda Function
data "archive_file" "lambda_leader_detection" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/leader-detection"
  output_path = "${path.module}/lambda-leader-detection.zip"
}

resource "aws_lambda_function" "leader_detection" {
  filename         = data.archive_file.lambda_leader_detection.output_path
  function_name    = "finans-leader-detection"
  role            = aws_iam_role.lambda_leader_detection.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.11"
  timeout         = 60  # 1 dakika
  memory_size     = 128

  source_code_hash = data.archive_file.lambda_leader_detection.output_base64sha256

  environment {
    variables = {
      S3_BUCKET     = local.s3_bucket_name
      SNS_TOPIC_ARN = aws_sns_topic.ec2_auto_start_alerts.arn
    }
  }

  tags = {
    Name = "FinansAsistan Leader Detection"
  }
}

# EventBridge Rule (Her 1 dakikada bir çalışır - minimum rate)
resource "aws_cloudwatch_event_rule" "leader_detection_schedule" {
  name                = "finans-leader-detection-schedule"
  description         = "Detect and correct leadership status"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "leader_detection_target" {
  rule      = aws_cloudwatch_event_rule.leader_detection_schedule.name
  target_id = "FinansLeaderDetectionTarget"
  arn       = aws_lambda_function.leader_detection.arn
}

resource "aws_lambda_permission" "leader_detection_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.leader_detection.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.leader_detection_schedule.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_leader_detection" {
  name              = "/aws/lambda/${aws_lambda_function.leader_detection.function_name}"
  retention_in_days = 7
}

# Outputs
output "lambda_leader_detection_arn" {
  value       = aws_lambda_function.leader_detection.arn
  description = "ARN of Leader Detection Lambda function"
}

