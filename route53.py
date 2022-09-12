import boto3
import sys

def boto3_session(region, role_arn=None, session_name='boto3_session', source_session=None):
    '''
    Creates a Boto3 Session object assumes a role
    given a role_arn otherwise uses the current IAM user/role.

    Returns: Boto3 Session object
    '''
    if role_arn:
        if source_session:
            client = source_session.client('sts')
        else:
            client = boto3.client('sts')

        response = client.assume_role(RoleArn=role_arn, RoleSessionName=session_name)
        session = boto3.Session(
            aws_access_key_id=response['Credentials']['AccessKeyId'],
            aws_secret_access_key=response['Credentials']['SecretAccessKey'],
            aws_session_token=response['Credentials']['SessionToken'],
            region_name = region)
        return session
    return boto3.Session()

def get_route53_connection(region, role_arn=None):
    '''
    Creates Boto3 low-level service client instance
    given a region and role_arn (optional).

    Returns: Route 53 service client instance
    '''
    session = boto3_session(region=region, role_arn=role_arn)
    conn = session.client('route53', region_name=region)
    return conn

def change_resource_record_sets(conn,
    changes,
    hosted_zone_id,
    record_set_comment):
    '''
    Creates, changes, or deletes a resource record set using a change batch.

    Returns: API response (dict)
    '''
    response = conn.change_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        ChangeBatch={
            'Comment': record_set_comment,
            'Changes': changes
        }
    )
    return response

def create_record_list(resource_records):
    '''
    Creates a list of key-value pairs representing resource records.

    Returns: Record list (list)
    '''
    record_list = []
    for record in resource_records:
        record_list.append({'Value': record})
    return record_list

def create_simple_record_set_change(action, record_set_name, record_set_type, record_set_ttl, record_list):
    '''
    Creates a single item list of a dictionary representing a resource record set change.

    Returns: Change list (list)
    '''
    changes = [
        {
            'Action': action,
            'ResourceRecordSet': {
                'Name': record_set_name,
                'Type': record_set_type,
                'TTL': int(record_set_ttl),
                'ResourceRecords': record_list
            }
        }
    ]
    return changes

def create_simple_resource_record_set(conn,
    hosted_zone_id,
    record_set_name,
    record_set_type,
    resource_records,
    record_set_comment,
    record_set_ttl):
    '''
    Creates a resource record set using a simple change batch.

    Returns: API response (dict)
    '''
    record_list = create_record_list(resource_records)
    changes = create_simple_record_set_change('CREATE', record_set_name, record_set_type, record_set_ttl, record_list)

    response = change_resource_record_sets(
        conn=conn,
        changes=changes,
        hosted_zone_id=hosted_zone_id,
        record_set_comment=record_set_comment)

    return response

def update_simple_resource_record_set(conn,
    hosted_zone_id,
    record_set_name,
    record_set_type,
    resource_records,
    record_set_comment,
    record_set_ttl):
    '''
    Creates a resource record set using a simple change batch.

    Returns: API response (dict)
    '''
    record_list = create_record_list(resource_records)
    changes = create_simple_record_set_change('UPSERT', record_set_name, record_set_type, record_set_ttl, record_list)

    response = change_resource_record_sets(
        conn=conn,
        changes=changes,
        hosted_zone_id=hosted_zone_id,
        record_set_comment=record_set_comment)

    return response

def delete_simple_resource_record_set(conn,
    hosted_zone_id,
    record_set_name,
    record_set_type,
    resource_records,
    record_set_comment,
    record_set_ttl):
    '''
    Deletes a resource record set using a simple change batch.

    Returns: API response (dict)
    '''
    paginator = conn.get_paginator('list_resource_record_sets')
    source_zone_records = paginator.paginate(HostedZoneId=hosted_zone_id)
    matching_records = []
    for record_set in source_zone_records:
        for record in record_set['ResourceRecordSets']:
            if record['Name'] == (record_set_name+"."):
                print('Matching record found')
                matching_records.append(record)
    
    print('Matching records:')
    print(matching_records)
    print('Validating only one record found...')
    if(len(matching_records) != 1):
        sys.exit("0 or more than 1 record is found. Exiting...")
    print('Only one record found... Validating record type is CNAME')
    if(matching_records[0]['Type'] != 'CNAME'):
        sys.exit("Record type does not match type CNAME. Exiting...")
    print('Record type matches CNAME. Validating record value found matches value passed in')
    if(matching_records[0]['ResourceRecords'][0]['Value'] != resource_records[0]):
        sys.exit('Record value in Route53 does not match expected value. Exiting...')
    print('Record value matches value passed in. Continuing to delete...')
        
    record_list = create_record_list(resource_records)
    changes = create_simple_record_set_change('DELETE', record_set_name, record_set_type, record_set_ttl, record_list)

    response = change_resource_record_sets(
        conn=conn,
        changes=changes,
        hosted_zone_id=hosted_zone_id,
        record_set_comment=record_set_comment)

    return response
def if_record_exists(conn,  
    hosted_zone_id,
    record_set_name):
    
    paginator = conn.get_paginator('list_resource_record_sets')
    source_zone_records = paginator.paginate(HostedZoneId=hosted_zone_id)
    for record_set in source_zone_records:
        for record in record_set['ResourceRecordSets']:
            if record['Name'] == (record_set_name+"."):
                return 1          
    return 0

