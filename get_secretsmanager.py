#!/usr/bin/python
import argparse
import sys
import os
import inspect
sys.path.insert(1,'.') # Adding root directory to path for import of AWS module
from aws import secretsmanager

# copied from https://bitbucket.org/ntsttech/ecs/src/master/pipeline/get_secretsmanager.py

os.environ['COLUMNS'] = "200" # effectively turn off wrapping
filename = inspect.getframeinfo(inspect.currentframe()).filename
path     = os.path.dirname(os.path.abspath(filename))

# Start by parsing and defining the help/parameters for this script
description_str = "This script %s pulls secret values from Secrets Manager." % filename

epilog_str = '''example:
 %s secret secret-key region

 ''' % (filename)

parser = argparse.ArgumentParser(prog = filename, description = description_str, epilog = epilog_str)
parser.add_argument("secret", type=str, help="[AWS Secrets Manager Secret to inspect]")
parser.add_argument("secretKey", type=str, help="[Specific Key in Secret to obtain value]")
parser.add_argument("region", type=str, help="[AWS Region]")
args=parser.parse_args()

def main():
    try:
        secrets = secretsmanager.get_secret_values(args.region, args.secret)
        key = secretsmanager.get_secret_value(args.secretKey, secrets)
        print(f'{key}')
    except Exception as err:
        sys.exit(err)

if __name__ == "__main__":
    main()