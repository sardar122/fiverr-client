import boto3
import sys
import time

#shamelessly copy/pasted from https://bitbucket.org/ntsttech/ecs/src/master/aws/ebstalk.py with all unused functions removed. reference that file to see if a function already
#exists for any new features and add functions as necessary.

def get_ebstalk_connection(region):
    conn = boto3.client('elasticbeanstalk', region_name=region)
    return conn

def is_ebstalk_ready(conn, envname):
    time.sleep(10)
    status = conn.describe_environments(EnvironmentNames=[envname,])
    try:
        if status['Environments'][0]['Status'] == 'Ready':
            return True
        else:
            return False
    except:
        return False

def get_env_info(conn, envname):
    """ This method returns the full description of the target EBS environment"""
    description = conn.describe_environments(EnvironmentNames = [envname,])
    
    return description
    
def is_ebs_env_green(conn, envname):
    """ This method returns a boolean: ( True => Health==Green )"""
    env_description = get_env_info(conn, envname)
    
    return ( env_description['Environments'][0]['Health'] == 'Green' )

def get_ebs_env_backstack(conn, appname):
    """ This method returns the envname of the backstack given an existing elbstalk object and application name"""

    envs = conn.describe_environments(ApplicationName=appname)
    for env in envs['Environments']:
        if '-back-' in env['CNAME']:
            return env['EnvironmentName']
        
def get_ebs_env_frontstack(conn, appname):
    """ This method returns the envname of the backstack given an existing elbstalk object and application name"""

    envs = conn.describe_environments(ApplicationName=appname)
    for env in envs['Environments']:
        if '-front-' in env['CNAME']:
            return env['EnvironmentName']

def wait_ebs_env_ready(conn, envname, retries, seconds):
    while retries > 0:
        ready = is_ebstalk_ready(conn, envname) 
        if not ready:
            retries = retries-1
            time.sleep(seconds)
            continue
        else:
            return
            
def wait_ebs_env_healthy(conn, envname, retries, seconds):
    while retries > 0:
        if retries == 1:
            return False

        healthy = is_ebs_env_green(conn, envname) 
        if not healthy:
            retries = retries-1
            time.sleep(seconds)
            continue           
        else:
            return True
