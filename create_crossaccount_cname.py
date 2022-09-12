#!/usr/bin/python
import argparse
import sys
import os
import inspect
from aws import route53

os.environ['COLUMNS'] = "200" # effectively turn off wrapping
filename = inspect.getframeinfo(inspect.currentframe()).filename
path     = os.path.dirname(os.path.abspath(filename))

# Start by parsing and defining the help/parameters for this script
description_str = "This script %s creates a Route 53 CNAME Resource Record Set by assuming an IAM role in another AWS account." % filename

epilog_str = '''example:

 %s arn:aws:iam::123456789012:role/Route53ChangeRecordSet Z8VLZEXAMPLE myunitynx00000.netsmartdev.com. 00000-stack-front.us-east-2.elasticbeanstalk.com. 300 us-east-2
 ''' % (filename)

parser = argparse.ArgumentParser(prog = filename, description = description_str, epilog = epilog_str)
parser.add_argument("role_arn", type=str, help="[IAM role located in the AWS account hosting Route 53 hosted zone(s)]")
parser.add_argument("hosted_zone_id", type=str, help="[Route 53 Hosted Zone ID to create the Resource Record Set in]")
parser.add_argument("record_name", type=str, help="[Name of the CNAME Resource Record Set]")
parser.add_argument("record_value", type=str, help="[Value of the CNAME Resource Record Set]")
parser.add_argument("time_to_live", type=str, help="[Time-to-live (TTL) for the Resource Record Set]")
parser.add_argument("region", type=str, help="[AWS Region]")
args=parser.parse_args()

if __name__ == "__main__":
    try:
        route53_conn = route53.get_route53_connection(args.region, args.role_arn)
        existing_record = route53.if_record_exists(route53_conn, args.hosted_zone_id, args.record_name)
        if existing_record == 0:
            response = route53.create_simple_resource_record_set(
                conn=route53_conn,
                hosted_zone_id=args.hosted_zone_id,
                record_set_name=args.record_name,
                record_set_type='CNAME',
                resource_records=[args.record_value],
                record_set_comment='',
                record_set_ttl=args.time_to_live
                )
        else:
            response = route53.update_simple_resource_record_set(
                conn=route53_conn,
                hosted_zone_id=args.hosted_zone_id,
                record_set_name=args.record_name,
                record_set_type='CNAME',
                resource_records=[args.record_value],
                record_set_comment='',
                record_set_ttl=args.time_to_live
                )
        if response['ResponseMetadata']['HTTPStatusCode'] == 200:
            print('Successsfully submitted request to create a simple CNAME resource record set with CNAME: %s and value: %s' % (args.record_name, args.record_value))
            sys.exit(0)
    except Exception as err:
        sys.exit(err)
