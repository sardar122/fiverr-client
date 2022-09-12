import boto3
import sys
import argparse
#import json

parser = argparse.ArgumentParser(description="Returns the host id of a EC2 dedicated host that has the required capacity for the request instance type.")
parser.add_argument("region", type=str, help="The AWS region in which the dedicate host resides.")
parser.add_argument("availability_zone", type=str, help="The desired availability zone.")
parser.add_argument("instance_type", type=str, help="The desired instance type.")
args=parser.parse_args()

def main():
    r5_vcpu_dict = { #Do we want other instance types here?
        "r5.large":"2",
        "r5.xlarge":"4",
        "r5.2xlarge":"8",
        "r5.4xlarge":"16",
        "r5.8xlarge":"32",
        "r5.12xlarge":"48",
        "r5.16xlarge":"64",
        "r5.24xlarge":"96",
        "r5d.large":"2",
        "r5d.xlarge":"4",
        "r5d.2xlarge":"8",
        "r5d.4xlarge":"16",
        "r5d.8xlarge":"32",
        "r5d.12xlarge":"48",
        "r5d.16xlarge":"64",
        "r5d.24xlarge":"96"
    }
    required_vcpus = r5_vcpu_dict[args.instance_type]

    ec2_client = boto3.client('ec2', region_name=args.region)
    response = ec2_client.describe_hosts(
        Filters=[
            {
                'Name': 'availability-zone',
                'Values': [
                    args.availability_zone,
                ]
            },
        ]
    )

    for reserved_host in response['Hosts']:
        if reserved_host["AvailableCapacity"]["AvailableVCpus"] >= int(required_vcpus):
            print(reserved_host["HostId"])
            return reserved_host["HostId"]
    
    print("No host found")
    return("No host found")

if __name__ == '__main__':
        main()