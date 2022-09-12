#!/usr/bin/python
import argparse
import sys
import os
import inspect
import os.path
import time
from aws import elasticache

os.environ['COLUMNS'] = "200"  # effectively turn off wrapping
filename = inspect.getframeinfo(inspect.currentframe()).filename
path = os.path.dirname(os.path.abspath(filename))

# Start by parsing and defining the help/parameters for this script
description_str = "This script %s scales the Redis cluster count either up or down." % filename

epilog_str = '''example:

 %s us-east-2 mubo-dev-replication-group-clustered 1
 ''' % (filename)

parser = argparse.ArgumentParser(prog=filename, description=description_str, epilog=epilog_str)
parser.add_argument("aws_region", type=str, help="[aws region]")
parser.add_argument("cluster_name", type=str,help="[ElastiCache Replication Group Name]")
parser.add_argument("shard_change_count", type=int,help="[Number of shards to add or remove from the cluster (1, -1, 5, etc...)]")
args = parser.parse_args()

if __name__ == "__main__":

    appname = "No Application"

    if args.shard_change_count == 0:
        print('ERROR: You must specify a non-zero change count.')
        sys.exit(1)

    try:
        connection = elasticache.get_connection(args.aws_region)
        replication_group = elasticache.get_replication_group(connection, args.cluster_name)
        current_shard_count = elasticache.get_replication_group_shard_count(replication_group)
        new_shard_count = current_shard_count + args.shard_change_count

        if new_shard_count < 2:
            print("Error: The shard count after updating would be below 2. Redis cluster with clustered mode on requires at least 2 shards.")
            sys.exit(1)

        modify_shard = elasticache.modify_shard_config(connection, args.cluster_name, new_shard_count, current_shard_count)

        print('Elasticache updated. Please allow up to a half hour for update to complete. Clusters remain available but CPU utilization may be increased for the duration.')
    except Exception as e:
        print('ERROR: Error occurred while updating shard count for Redis Cluster.')
        sys.exit(e)
        
    print('Waiting for %s cluster to finish resharding' % (args.cluster_name))
    elasticache.wait_for_complete(connection, args.cluster_name, 60, 60)   
    print('Sucessfully scaled %s cluster by %s shards.' % (args.cluster_name, args.shard_change_count))
    sys.exit(0)
