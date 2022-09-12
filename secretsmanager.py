import json
import logging

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
  
def get_secret_values(aws_region, secret_name):
    try:
        client = boto3.client(
            "secretsmanager",
            region_name=aws_region,
        )
        resp = client.get_secret_value(SecretId=secret_name)
        secret_values = json.loads(resp["SecretString"])
    except ClientError:
        logger.exception(
            f"[Secrets Manager botocore.exceptions.ClientError] secret_name={secret_name}"
        )
        raise
    except KeyError:
        logger.exception(
            f"[Secrets Manager KeyError] incorrect response format. secret_name={secret_name}"
        )
        raise
    except json.JSONDecodeError:
        logger.exception(
            f"[Secrets Manager ValueError] JSON decoding fails secret_name={secret_name}"
        )
        raise
    else:
        return secret_values

def get_secret_value(secret_key, secret_values):
    try:
        secret = secret_values[secret_key]
    except KeyError:
        logger.exception(
            f"[Secrets Manager KeyError] secret_key does not exists. secret_key={secret_key}"
        )
        raise
    else:
        return secret