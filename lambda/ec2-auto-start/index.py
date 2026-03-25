# ════════════════════════════════════════════════════════════
# FinansAsistan - EC2 Auto-Start Lambda
# Automatically launches EC2 instance when system is down
# ════════════════════════════════════════════════════════════

import boto3
import json
import os
from datetime import datetime, timezone

ec2 = boto3.client('ec2')
autoscaling = boto3.client('autoscaling')
s3 = boto3.client('s3')
sns = boto3.client('sns')

ASG_NAME = os.environ.get('ASG_NAME', 'finans-worker-pool')
LEADER_ASG_NAME = os.environ.get('LEADER_ASG_NAME', 'finans-leader-pool')
BUCKET = os.environ.get('S3_BUCKET', 'finans-asistan-backups')
LEADER_KEY = 'current-leader.json'
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')

def lambda_handler(event, context):
    """
    Lambda handler - launches EC2 instance and registers as leader
    """
    try:
        # Check if system is already running
        if is_system_running():
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'System already running'})
            }
        
        # Check if physical leader exists
        leader_info = get_leader_info()
        physical_leader_exists = False
        if leader_info:
            leader_type = leader_info.get('leader_type', '')
            if leader_type == 'physical':
                # Physical leader exists, check if it's alive
                last_heartbeat_str = leader_info.get('last_heartbeat')
                if last_heartbeat_str:
                    last_heartbeat = datetime.fromisoformat(last_heartbeat_str.replace('Z', '+00:00'))
                    now = datetime.now(timezone.utc)
                    time_since_heartbeat = now - last_heartbeat
                    # Alive if heartbeat < 300 seconds (5 minutes)
                    if time_since_heartbeat.total_seconds() < 300:
                        physical_leader_exists = True
        
        # If physical leader exists, don't start EC2 leader
        if physical_leader_exists:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Physical leader exists, not starting EC2 leader'})
            }
        
        # Launch R6G Medium leader instance via ASG
        instance_id = launch_leader_instance()
        
        # Register as leader in S3
        register_leader(instance_id, 'ec2')
        
        # Send notification
        send_alert(f"R6G Medium EC2 instance launched as temporary leader (no physical node): {instance_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'EC2 instance launched',
                'instance_id': instance_id,
                'status': 'bootstrap_in_progress'
            })
        }
        
    except Exception as e:
        error_msg = f"EC2 auto-start failed: {str(e)}"
        print(error_msg)
        send_alert(error_msg)
        raise

def is_system_running():
    """
    Check if system is already running (has active leader with recent heartbeat AND running EC2 instances)
    """
    try:
        # Check if any EC2 instances are running in the leader ASG
        leader_instances = get_asg_instances(LEADER_ASG_NAME)
        if leader_instances:
            # Check if instances are actually running (not just in ASG)
            running_instances = []
            for instance_id in leader_instances:
                try:
                    response = ec2.describe_instances(
                        InstanceIds=[instance_id],
                        Filters=[
                            {'Name': 'instance-state-name', 'Values': ['running']}
                        ]
                    )
                    if response['Reservations']:
                        running_instances.append(instance_id)
                except Exception as e:
                    print(f"Error checking instance {instance_id}: {str(e)}")
            
            if running_instances:
                print(f"Found {len(running_instances)} running leader instance(s): {running_instances}")
                # If instances are running, check heartbeat
                leader_info = get_leader_info()
                if leader_info:
                    last_heartbeat_str = leader_info.get('last_heartbeat')
                    if last_heartbeat_str:
                        last_heartbeat = datetime.fromisoformat(last_heartbeat_str.replace('Z', '+00:00'))
                        now = datetime.now(timezone.utc)
                        time_since_heartbeat = now - last_heartbeat
                        # If heartbeat is less than 300 seconds (5 minutes) old, system is running
                        if time_since_heartbeat.total_seconds() < 300:
                            return True
                        else:
                            print(f"Leader instances running but heartbeat is stale ({time_since_heartbeat.total_seconds()}s old)")
                            return False
                else:
                    print("Leader instances running but no leader info in S3")
                    return False
            else:
                print("Leader instances in ASG but not running")
                return False
        
        # Check leader info from S3
        leader_info = get_leader_info()
        if not leader_info:
            return False
        
        last_heartbeat_str = leader_info.get('last_heartbeat')
        if not last_heartbeat_str:
            return False
        
        last_heartbeat = datetime.fromisoformat(last_heartbeat_str.replace('Z', '+00:00'))
        now = datetime.now(timezone.utc)
        time_since_heartbeat = now - last_heartbeat
        
        # If heartbeat is less than 300 seconds (5 minutes) old, system is running
        return time_since_heartbeat.total_seconds() < 300
        
    except Exception as e:
        print(f"Error checking system status: {str(e)}")
        return False

def launch_ec2_instance():
    """
    Launch EC2 worker instance via Auto Scaling Group
    """
    try:
        # Set desired capacity to 1 (launch one instance)
        autoscaling.set_desired_capacity(
            AutoScalingGroupName=ASG_NAME,
            DesiredCapacity=1,
            HonorCooldown=False
        )
        
        # Wait for instance to launch
        import time
        max_wait = 300  # 5 minutes
        wait_interval = 10  # 10 seconds
        
        for _ in range(max_wait // wait_interval):
            instances = get_asg_instances(ASG_NAME)
            if instances:
                instance_id = instances[0]
                print(f"EC2 worker instance launched: {instance_id}")
                return instance_id
            time.sleep(wait_interval)
        
        raise Exception("Timeout waiting for EC2 instance to launch")
        
    except Exception as e:
        print(f"Error launching EC2 instance: {str(e)}")
        raise

def launch_leader_instance():
    """
    Launch R6G Medium leader instance via Auto Scaling Group
    """
    try:
        # Set desired capacity to 1 (launch one leader instance)
        autoscaling.set_desired_capacity(
            AutoScalingGroupName=LEADER_ASG_NAME,
            DesiredCapacity=1,
            HonorCooldown=False
        )
        
        # Wait for instance to launch
        import time
        max_wait = 300  # 5 minutes
        wait_interval = 10  # 10 seconds
        
        for _ in range(max_wait // wait_interval):
            instances = get_asg_instances(LEADER_ASG_NAME)
            if instances:
                instance_id = instances[0]
                print(f"R6G Medium leader instance launched: {instance_id}")
                return instance_id
            time.sleep(wait_interval)
        
        raise Exception("Timeout waiting for R6G Medium leader instance to launch")
        
    except Exception as e:
        print(f"Error launching R6G Medium leader instance: {str(e)}")
        raise

def get_asg_instances(asg_name):
    """
    Get running instances from ASG
    """
    try:
        response = autoscaling.describe_auto_scaling_groups(
            AutoScalingGroupNames=[asg_name]
        )
        
        if not response['AutoScalingGroups']:
            return []
        
        asg = response['AutoScalingGroups'][0]
        instances = [
            inst['InstanceId'] 
            for inst in asg['Instances'] 
            if inst['LifecycleState'] == 'InService'
        ]
        
        return instances
        
    except Exception as e:
        print(f"Error getting ASG instances: {str(e)}")
        return []

def register_leader(instance_id, leader_type):
    """
    Register instance as leader in S3
    """
    try:
        leader_info = {
            'leader_id': instance_id,
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
        
        print(f"Registered leader: {instance_id} ({leader_type})")
        
    except Exception as e:
        print(f"Error registering leader: {str(e)}")
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
            Subject='FinansAsistan EC2 Auto-Start',
            Message=message
        )
    except Exception as e:
        print(f"Error sending SNS alert: {str(e)}")

