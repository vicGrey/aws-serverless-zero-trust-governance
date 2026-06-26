import json
import boto3
import os
import uuid
from decimal import Decimal
from datetime import datetime

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TRANSACTIONS_TABLE'])

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Financial Transaction API Lambda Handler
    Supports: POST /transactions, GET /transactions/{id}
    """
    http_method = event['httpMethod']
    path = event['path']
    
    try:
        if http_method == 'POST' and path == '/transactions':
            return create_transaction(event)
        elif http_method == 'GET' and path.startswith('/transactions/'):
            transaction_id = path.split('/')[-1]
            return get_transaction(transaction_id)
        else:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid request'})
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

def create_transaction(event):
    """Create a new financial transaction"""
    body = json.loads(event.get('body', '{}'))
    
    # Validate required fields
    required_fields = ['amount', 'currency', 'recipient_account']
    for field in required_fields:
        if field not in body:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Missing required field: {field}'})
            }
    
    transaction = {
        'transaction_id': str(uuid.uuid4()),
        'amount': Decimal(str(body['amount'])),
        'currency': body['currency'],
        'recipient_account': body['recipient_account'],
        'sender_id': event['requestContext']['authorizer']['claims']['sub'],
        'status': 'PENDING',
        'timestamp': datetime.utcnow().isoformat(),
        'description': body.get('description', '')
    }
    
    table.put_item(Item=transaction)
    
    return {
        'statusCode': 201,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(transaction, cls=DecimalEncoder)
    }

def get_transaction(transaction_id):
    """Retrieve a transaction by ID"""
    response = table.get_item(Key={'transaction_id': transaction_id})
    
    if 'Item' not in response:
        return {
            'statusCode': 404,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Transaction not found'})
        }
    
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(response['Item'], cls=DecimalEncoder)
    }
