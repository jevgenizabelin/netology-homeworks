import hvac
import os

url = os.environ['VAULT_URL']
token = os.environ['VAULT_TOKEN']

client = hvac.Client(
    url, token
)
client.is_authenticated()

# пишем секрет
client.secrets.kv.v2.create_or_update_secret(
    path = os.environ['VAULT_PATCH'],
    secret=dict(os.environ['VAULT_KEY']=os.environ['VAULT_VALUE']),
)
