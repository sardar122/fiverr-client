#!/usr/bin/python
import sys
import argparse
sys.path.insert(1,'.')
import boto3

parser = argparse.ArgumentParser(description="This script is used to get ARN of a Secrets Manager secret.")
parser.add_argument("secret_name", type=str, help="The name of the Secrets Manager secret to find the ARN for.")
parser.add_argument("region", type=str, help="The region in which the secret lives.")
args=parser.parse_args()

def main():
    client = boto3.client('secretsmanager', region_name=args.region)
    response = client.describe_secret(
        SecretId=args.secret_name
    )
    print (response["ARN"])
        
if __name__ == "__main__":
    main()
