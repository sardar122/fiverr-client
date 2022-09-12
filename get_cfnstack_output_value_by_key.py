#!/usr/bin/python
import boto3
import argparse

parser = argparse.ArgumentParser(description="This script is used to obtain the output value of a CloudFormation stack key using the export name")
parser.add_argument("region", type=str, help="The region we want to create the param store in")
parser.add_argument("stackName", type=str, help="The name of the CloudFormation stack to inspect")
parser.add_argument("outputKey", type=str, help="The output key in the CloudFormation stack to obtain the value of")

args=parser.parse_args()

def main():
    cfn_client = boto3.client("cloudformation", region_name=args.region)
    outputs = cfn_client.describe_stacks(
        StackName=args.stackName
    )

    for output in outputs["Stacks"][0]["Outputs"]:
        keyName = output["OutputKey"]
        if keyName == args.outputKey:
            print(output["OutputValue"])
            return output["OutputValue"]

if __name__ == '__main__':
        main()