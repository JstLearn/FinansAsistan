# ════════════════════════════════════════════════════════════
# FinansAsistan - Heartbeat Monitor Lambda
# Monitors physical machine heartbeat and triggers EC2 auto-start
# ════════════════════════════════════════════════════════════

import boto3
import json
import os
from datetime import datetime, timezone, timedelta

s3 = boto3.client('s3')
sns = boto3.client('sns')
lambda_client = boto3.client('lambda')

BUCKET = os.environ.get('S3_BUCKET', 'finans-asistan-backups')
LEADER_KEY = 'current-leader.json'
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
EC2_AUTO_START_FUNCTION = os.environ.get('EC2_AUTO_START_FUNCTION', 'ec2-auto-start')

def lambda_handler(event, context):
    """
    Lambda handler - checks heartbeat and triggers EC2 auto-start if needed
    """
    try:
        # Get leader info from S3
        leader_info = get_leader_info()
        
        if not leader_info:
            # Initial setup, no leader yet
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No leader found (initial setup)'})
            }
        
        leader_type = leader_info.get('leader_type')
        leader_id = leader_info.get('leader_id')
        last_heartbeat_str = leader_info.get('last_heartbeat')
        
        if not last_heartbeat_str:
            send_alert(f"Leader {leader_id} has no heartbeat timestamp")
            return {'statusCode': 200, 'body': json.dumps({'message': 'No heartbeat timestamp'})}
        
        # Parse heartbeat timestamp
        last_heartbeat = datetime.fromisoformat(last_heartbeat_str.replace('Z', '+00:00'))
        now = datetime.now(timezone.utc)
        
        # Heartbeat timeout check (300 seconds - 5 minutes)
        timeout = timedelta(seconds=300)
        time_since_heartbeat = now - last_heartbeat
        
        if time_since_heartbeat > timeout:
            # Heartbeat timeout!
            # Skip auto-start for development machines (leader_id contains "dev" or leader_type is "development")
            if 'dev' in leader_id.lower() or leader_type == 'development':
                # Development machine - do not trigger auto-start
                send_alert(f"Development leader heartbeat timeout (ignored): {leader_id} (last heartbeat: {last_heartbeat_str})")
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'Development leader heartbeat timeout (auto-start skipped)',
                        'leader_id': leader_id,
                        'time_since_heartbeat': str(time_since_heartbeat)
                    })
                }
            
            if leader_type == 'physical':
                # Physical machine down, trigger EC2 auto-start
                send_alert(f"Physical leader heartbeat timeout: {leader_id} (last heartbeat: {last_heartbeat_str})")
                trigger_ec2_auto_start()
            else:
                # EC2 leader timeout (may be terminated)
                send_alert(f"EC2 leader heartbeat timeout: {leader_id} (last heartbeat: {last_heartbeat_str})")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Heartbeat timeout detected',
                    'leader_id': leader_id,
                    'time_since_heartbeat': str(time_since_heartbeat)
                })
            }
        
        # Heartbeat OK
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Heartbeat OK',
                'leader_id': leader_id,
                'time_since_heartbeat': str(time_since_heartbeat)
            })
        }
        
    except Exception as e:
        error_msg = f"Heartbeat monitor error: {str(e)}"
        print(error_msg)
        send_alert(error_msg)
        raise

def get_leader_info():
    """
    Get current leader info from S3
    """
    try:
        response = s3.get_object(Bucket=BUCKET, Key=LEADER_KEY)
        return json.loads(response['Body'].read().decode('utf-8'))
    except s3.exceptions.NoSuchKey:
        return None
    except Exception as e:
        print(f"Error reading leader info: {str(e)}")
        return None

def trigger_ec2_auto_start():
    """
    Trigger EC2 auto-start Lambda function
    """
    try:
        lambda_client.invoke(
            FunctionName=EC2_AUTO_START_FUNCTION,
            InvocationType='Event',
            Payload=json.dumps({
                'trigger': 'heartbeat-timeout',
                'timestamp': datetime.now(timezone.utc).isoformat()
            })
        )
        print(f"Triggered EC2 auto-start function: {EC2_AUTO_START_FUNCTION}")
    except Exception as e:
        print(f"Error triggering EC2 auto-start: {str(e)}")
        raise

def send_alert(message):
    """
    Send alert via SNS
    """
    if not SNS_TOPIC_ARN:
        print(f"Alert (SNS not configured): {message}")
        return
    
    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject='FinansAsistan Heartbeat Alert',
            Message=message
        )
    except Exception as e:
        print(f"Error sending SNS alert: {str(e)}")

