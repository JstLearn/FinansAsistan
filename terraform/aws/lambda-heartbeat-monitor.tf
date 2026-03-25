# ════════════════════════════════════════════════════════════
# FinansAsistan - Lambda Heartbeat Monitor
# Fiziksel makine heartbeat kontrolü ve EC2 auto-start tetikleme
# ════════════════════════════════════════════════════════════

# Lambda IAM Role
resource "aws_iam_role" "lambda_heartbeat_monitor" {
  name = "finans-lambda-heartbeat-monitor"

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
resource "aws_iam_role_policy" "lambda_heartbeat_monitor" {
  name = "finans-lambda-heartbeat-monitor-policy"
  role = aws_iam_role.lambda_heartbeat_monitor.id

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
          "s3:GetObject"
        ]
        Resource = "${local.s3_bucket_arn}/current-leader.json"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.ec2_auto_start.arn
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
data "archive_file" "lambda_heartbeat_monitor" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/heartbeat-monitor"
  output_path = "${path.module}/lambda-heartbeat-monitor.zip"
}

resource "aws_lambda_function" "heartbeat_monitor" {
  filename         = data.archive_file.lambda_heartbeat_monitor.output_path
  function_name    = "finans-heartbeat-monitor"
  role            = aws_iam_role.lambda_heartbeat_monitor.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.11"
  timeout         = 60  # 1 dakika
  memory_size     = 128

  source_code_hash = data.archive_file.lambda_heartbeat_monitor.output_base64sha256

  environment {
    variables = {
      S3_BUCKET              = local.s3_bucket_name
      SNS_TOPIC_ARN          = aws_sns_topic.ec2_auto_start_alerts.arn
      EC2_AUTO_START_FUNCTION = aws_lambda_function.ec2_auto_start.function_name
    }
  }

  tags = {
    Name = "FinansAsistan Heartbeat Monitor"
  }
}

# EventBridge Rule (Her 1 dakikada bir çalışır)
resource "aws_cloudwatch_event_rule" "heartbeat_monitor_schedule" {
  name                = "finans-heartbeat-monitor-schedule"
  description         = "Monitor leader heartbeat and trigger EC2 auto-start if timeout"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "heartbeat_monitor_target" {
  rule      = aws_cloudwatch_event_rule.heartbeat_monitor_schedule.name
  target_id = "FinansHeartbeatMonitorTarget"
  arn       = aws_lambda_function.heartbeat_monitor.arn
}

resource "aws_lambda_permission" "heartbeat_monitor_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.heartbeat_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.heartbeat_monitor_schedule.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_heartbeat_monitor" {
  name              = "/aws/lambda/${aws_lambda_function.heartbeat_monitor.function_name}"
  retention_in_days = 7
}

# Outputs
output "lambda_heartbeat_monitor_arn" {
  value       = aws_lambda_function.heartbeat_monitor.arn
  description = "ARN of Heartbeat Monitor Lambda function"
}

