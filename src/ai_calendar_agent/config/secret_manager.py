import boto3
import json
import logging
from typing import Dict, Any
from botocore.exceptions import ClientError

class SecretsManager:
    def __init__(self, region_name: str = "us-east-1"):
        self.client = boto3.client('secretsmanager', region_name=region_name)
        self.logger = logging.getLogger(__name__)
        self._cache = {}

    def get_secret(self, secret_name: str) -> Dict[str, Any]:
        """Get secret from AWS Secrets Manager with caching"""
        if secret_name in self._cache:
            return self._cache[secret_name]

        try:
            response = self.client.get_secret_value(SecretId=secret_name)
            secret_data = json.loads(response['SecretString'])
            self._cache[secret_name] = secret_data
            return secret_data
        except ClientError as e:
            self.logger.error(f"Error retrieving secret {secret_name}: {e}")
            raise

    def get_database_credentials(self) -> Dict[str, str]:
        """Get database connection credentials"""
        return self.get_secret("ai-calendar/database-credentials")

    def get_microsoft_oauth_config(self) -> Dict[str, str]:
        """Get Microsoft OAuth configuration"""
        return self.get_secret("ai-calendar/microsoft-oauth")

    def get_gmail_oauth_config(self) -> Dict[str, str]:
        """Get Gmail OAuth configuration"""
        return self.get_secret("ai-calendar/gmail-oauth")

# Usage in application
secrets = SecretsManager()
microsoft_config = secrets.get_microsoft_oauth_config()
