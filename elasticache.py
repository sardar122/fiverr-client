import json
import logging
import time
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
  
def get_connection(aws_region):
    print('Getting Elasticache boto3 connection...')
    try:
        client = boto3.client(
            "elasticache",
            region_name=aws_region,
        )
    except ClientError:
        logger.exception(
            f"[ElastiCache botocore.exceptions.ClientError] Could not load client."
        )
        raise
    else:
        return client

def is_replication_group_ready(conn, replication_group_id):
    time.sleep(10)
    print("Checking replication group status...")
    replication_group = get_replication_group(conn, replication_group_id)

    return sharding_complete(replication_group)

def sharding_complete(replication_group):
    try:
        overall_status = replication_group['Status']
        isSharding = ('PendingModifiedValues' in replication_group and 
                     'Resharding' in replication_group['PendingModifiedValues'] and
                     'SlotMigration' in replication_group['PendingModifiedValues']['Resharding'] and
                     'ProgressPercentage' in replication_group['PendingModifiedValues']['Resharding']['SlotMigration'] and
                     replication_group['PendingModifiedValues']['Resharding']['SlotMigration']['ProgressPercentage'] < 100)

        if overall_status == 'available' and not isSharding:
            return True
        else:
            print("Sharding still in process.")
            return False
    except:
        raise


def wait_for_complete(conn, replication_group_id, retries, seconds):
    while retries > 0:
        ready = is_replication_group_ready(conn, replication_group_id) 
        if not ready:
            retries = retries-1
            time.sleep(seconds)
            continue
        else:
            return

def get_replication_group(conn, replication_group_id):
    print(f'Getting replication group {replication_group_id}...')
    try:
        resp = conn.describe_replication_groups(ReplicationGroupId=replication_group_id)
        replication_groups = resp["ReplicationGroups"]
        replication_group = replication_groups[0]
    except KeyError:
        logger.exception(
            f"[ElastiCache KeyError] incorrect response format. replication_group_id={replication_group_id}"
        )
        raise
    except json.JSONDecodeError:
        logger.exception(
            f"[ElastiCache ValueError] JSON decoding fails replication_group_id={replication_group_id}"
        )
        raise
    except IndexError:
        logger.exception(
            f"[ElastiCache IndexError] There was no replication group returned. replication_group_id={replication_group_id}"
        )
        raise
    except Exception:
        logger.exception(
            f"[Exception] A generic exception occurred."
        )
        raise
    else:
        print(f'Found replication group {replication_group_id}!')
        print(replication_group)
        return replication_group

def get_replication_group_shard_count(replication_group):
    try:
        shard_count = len(replication_group['NodeGroups'])
    except TypeError:
        logger.exception(
            f"[ElastiCache TypeError] There was no NodeGroup present."
        )
        raise
    else:
        return shard_count

def modify_shard_config(conn, replication_group_id, newCount, oldCount):
    print('Modifying shard count...')
    try:
        resharding_config = []
        node_groups_to_remove = []

        if newCount > oldCount:
            for x in range(newCount):
                node_group_id = x + 1 #starts at 0001 
                #NodeGroupId is a four digit number string padded with zeroes. We don't define it so AWS increments by default
                resharding_config.append({
                    'NodeGroupId': '{num:0{width}}'.format(num=node_group_id, width=4), 
                    'PreferredAvailabilityZones': ['us-east-2a', 'us-east-2c']
                })
        elif newCount < oldCount:
            change = oldCount - newCount
            
            #always remove the highest id'd nodes so that add/remove always leaves us with 1...max without any gaps
            for x in range(change):
                node_group_id = oldCount - x
                node_groups_to_remove.append('{num:0{width}}'.format(num=node_group_id, width=4))


        response = conn.modify_replication_group_shard_configuration(
            ReplicationGroupId=replication_group_id,
            NodeGroupCount=newCount,
            ApplyImmediately=True,
            ReshardingConfiguration=resharding_config,
            NodeGroupsToRemove=node_groups_to_remove
        )
    except conn.exceptions.ReplicationGroupNotFoundFault:
        logger.exception(
            f"[ElastiCache ReplicationGroupNotFoundFault] There was no replication group with the included it."
        )
        raise
    except conn.exceptions.InvalidReplicationGroupStateFault:
        logger.exception(
            f"[ElastiCache InvalidReplicationGroupStateFault] The replication group was in an invalid state and could not be updated."
        )
        raise
    except conn.exceptions.InvalidCacheClusterStateFault:
        logger.exception(
            f"[ElastiCache InvalidCacheClusterStateFault] The cache cluster was in an invalid state and could not be updated."
        )
        raise
    except conn.exceptions.InvalidVPCNetworkStateFault:
        logger.exception(
            f"[ElastiCache InvalidVPCNetworkStateFault] The VPC Network was in an invalid state and the replication group could not be updated."
        )
        raise
    except conn.exceptions.InsufficientCacheClusterCapacityFault:
        logger.exception(
            f"[ElastiCache InsufficientCacheClusterCapacityFault] There is not enough capacity to add requested changes. Submit a ticket to AWS for a rate increase or change requested amount."
        )
        raise
    except conn.exceptions.NodeGroupsPerReplicationGroupQuotaExceededFault:
        logger.exception(
            f"[ElastiCache NodeGroupsPerReplicationGroupQuotaExceededFault] The requested shard count exceeds the maximum replication group node count."
        )
        raise
    except conn.exceptions.NodeQuotaForCustomerExceededFault:
        logger.exception(
            f"[ElastiCache NodeQuotaForCustomerExceededFault] The requested shard count would exceed the account's maximum node count Submit a ticket to AWS for a rate increase or change requested amount."
        )
        raise
    except conn.exceptions.InvalidKMSKeyFault:
        logger.exception(
            f"[ElastiCache InvalidKMSKeyFault] Something went wrong with KMS Key."
        )
        raise
    except conn.exceptions.InvalidParameterValueException:
        logger.exception(
            f"[ElastiCache InvalidParameterValueException] An included parameter was invalid. Review logs."
        )
        raise
    except conn.exceptions.InvalidParameterCombinationException:
        logger.exception(
            f"[ElastiCache InvalidParameterCombinationException] An internal error occurred while generating AWS boto3 request parameters. Review code for fault."
        )
        raise
    except Exception:
        logger.exception(
            f"[Exception] A generic exception occurred."
        )
        raise
    else:
        return response