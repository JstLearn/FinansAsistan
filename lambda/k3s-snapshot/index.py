# ════════════════════════════════════════════════════════════
# FinansAsistan - k3s Snapshot Lambda
# Automatically creates k3s/etcd snapshots and uploads to S3
# ════════════════════════════════════════════════════════════

import boto3
import json
import os
from datetime import datetime, timezone
import subprocess
import tempfile

s3 = boto3.client('s3')
sns = boto3.client('sns')
ec2 = boto3.client('ec2')

BUCKET = os.environ.get('S3_BUCKET', 'finans-asistan-backups')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
LEADER_KEY = 'current-leader.json'
SNAPSHOT_PREFIX = 'k3s/snapshots/'

def lambda_handler(event, context):
    """
    Lambda handler - creates k3s snapshot and uploads to S3
    """
    try:
        # Get current leader info
        leader_info = get_leader_info()
        if not leader_info:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No leader found, skipping snapshot'})
            }
        
        leader_id = leader_info.get('leader_id')
        leader_type = leader_info.get('leader_type', 'unknown')
        
        # Only create snapshot if leader is physical or EC2
        if leader_type not in ['physical', 'ec2']:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': f'Leader type {leader_type} not supported for snapshot'})
            }
        
        # If EC2 leader, get instance and create snapshot via SSH
        if leader_type == 'ec2':
            snapshot_key = create_ec2_snapshot(leader_id)
        else:
            # Physical leader - snapshot should be created manually or via cron
            # This Lambda can't access physical machines directly
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Physical leader - snapshot should be created manually'})
            }
        
        if snapshot_key:
            send_alert(f"k3s snapshot created and uploaded: {snapshot_key}")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Snapshot created successfully',
                    'snapshot_key': snapshot_key
                })
            }
        else:
            return {
                'statusCode': 500,
                'body': json.dumps({'message': 'Failed to create snapshot'})
            }
        
    except Exception as e:
        error_msg = f"k3s snapshot failed: {str(e)}"
        print(error_msg)
        send_alert(error_msg)
        raise

def create_ec2_snapshot(instance_id):
    """
    Create k3s snapshot on EC2 instance and upload to S3
    """
    try:
        # Get instance details
        response = ec2.describe_instances(InstanceIds=[instance_id])
        if not response['Reservations']:
            print(f"Instance {instance_id} not found")
            return None
        
        instance = response['Reservations'][0]['Instances'][0]
        
        # Note: This requires SSM Session Manager or SSH access
        # For now, we'll use a simpler approach: trigger snapshot creation via user-data script
        # or use SSM Run Command
        
        # Create snapshot filename
        timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%SZ')
        snapshot_key = f"{SNAPSHOT_PREFIX}etcd-snapshot-{timestamp}.db"
        
        # For EC2, we need to use SSM Run Command to execute k3s snapshot command
        # This requires SSM agent to be installed on the instance
        # For now, return None and log that manual snapshot is needed
        
        print(f"EC2 snapshot creation requires SSM Run Command or manual execution")
        print(f"Expected snapshot key: {snapshot_key}")
        
        # TODO: Implement SSM Run Command to execute:
        # sudo k3s etcd-snapshot save /tmp/etcd-snapshot.db
        # Then download and upload to S3
        
        return None
        
    except Exception as e:
        print(f"Error creating EC2 snapshot: {str(e)}")
        return None

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
            Subject='FinansAsistan k3s Snapshot',
            Message=message
        )
    except Exception as e:
        print(f"Error sending SNS alert: {str(e)}")

