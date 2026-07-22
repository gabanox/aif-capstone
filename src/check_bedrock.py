"""Verifica conectividad con Amazon Bedrock usando la Converse API."""
import os
import sys

import boto3
from botocore.exceptions import ClientError

MODEL_ID = "us.anthropic.claude-sonnet-4-6"

def main():
    token = os.environ.get("AWS_BEARER_TOKEN_BEDROCK")
    if not token:
        print("Error: falta la variable de entorno AWS_BEARER_TOKEN_BEDROCK", file=sys.stderr)
        sys.exit(1)

    client = boto3.client("bedrock-runtime", region_name="us-east-1")

    try:
        response = client.converse(
            modelId=MODEL_ID,
            messages=[{"role": "user", "content": [{"text": "Responde solo 'OK' para confirmar conectividad."}]}],
            inferenceConfig={"maxTokens": 16, "temperature": 0.0},
        )
        text = response["output"]["message"]["content"][0]["text"]
        print(f"Bedrock OK — modelo: {MODEL_ID}")
        print(f"Respuesta: {text}")
    except ClientError as e:
        print(f"Error al invocar Bedrock: {e.response['Error']['Code']} — {e.response['Error']['Message']}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
