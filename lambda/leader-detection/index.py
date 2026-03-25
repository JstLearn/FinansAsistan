# ════════════════════════════════════════════════════════════
# FinansAsistan - Leader Detection Lambda
# Detects current leader and manages leadership transitions
# ════════════════════════════════════════════════════════════

import boto3
import json
import os
from datetime import datetime, timezone

s3 = boto3.client('s3')
sns = boto3.client('sns')

BUCKET = os.environ.get('S3_BUCKET', 'finans-asistan-backups')
LEADER_KEY = 'current-leader.json'
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')

def lambda_handler(event, context):
    """
    Lambda handler - detects current leader and manages transitions
    """
    try:
        action = event.get('action', 'detect')
        
        if action == 'detect':
            leader_info = detect_leader()
            return {
                'statusCode': 200,
                'body': json.dumps(leader_info or {'message': 'No leader found'})
            }
        
        elif action == 'register':
            leader_id = event.get('leader_id')
            leader_type = event.get('leader_type', 'physical')
            result = register_leader(leader_id, leader_type)
            return {
                'statusCode': 200,
                'body': json.dumps(result)
            }
        
        elif action == 'update_heartbeat':
            leader_id = event.get('leader_id')
            result = update_heartbeat(leader_id)
            return {
                'statusCode': 200,
                'body': json.dumps(result)
            }
        
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Unknown action: {action}'})
            }
        
    except Exception as e:
        error_msg = f"Leader detection error: {str(e)}"
        print(error_msg)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_msg})
        }

def detect_leader():
    """
    Detect current leader from S3
    """
    try:
        leader_info = get_leader_info()
        return leader_info
    except Exception as e:
        print(f"Error detecting leader: {str(e)}")
        return None

def register_leader(leader_id, leader_type):
    """
    Register a new leader
    """
    try:
        leader_info = {
            'leader_id': leader_id,
            'leader_type': leader_type,
            'registered_at': datetime.now(timezone.utc).isoformat(),
            'last_heartbeat': datetime.now(timezone.utc).isoformat()
        }
        
        s3.put_object(
            Bucket=BUCKET,
            Key=LEADER_KEY,
            Body=json.dumps(leader_info, indent=2),
            ContentType='application/json'
        )
        
        send_alert(f"New leader registered: {leader_id} ({leader_type})")
        
        return {
            'message': 'Leader registered successfully',
            'leader_id': leader_id,
            'leader_type': leader_type
        }
        
    except Exception as e:
        print(f"Error registering leader: {str(e)}")
        raise

def update_heartbeat(leader_id):
    """
    Update heartbeat timestamp for current leader
    """
    try:
        leader_info = get_leader_info()
        
        if not leader_info:
            return {'error': 'No leader found'}
        
        if leader_info.get('leader_id') != leader_id:
            return {'error': 'Leader ID mismatch'}
        
        # Update heartbeat
        leader_info['last_heartbeat'] = datetime.now(timezone.utc).isoformat()
        
        s3.put_object(
            Bucket=BUCKET,
            Key=LEADER_KEY,
            Body=json.dumps(leader_info, indent=2),
            ContentType='application/json'
        )
        
        return {
            'message': 'Heartbeat updated',
            'leader_id': leader_id,
            'last_heartbeat': leader_info['last_heartbeat']
        }
        
    except Exception as e:
        print(f"Error updating heartbeat: {str(e)}")
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
            Subject='FinansAsistan Leader Detection',
            Message=message
        )
    except Exception as e:
        print(f"Error sending SNS alert: {str(e)}")

