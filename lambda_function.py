import json
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("VisitorCount")  # Change to your DynamoDB table name

def lambda_handler(event, context):
    # Get current count from DynamoDB
    response = table.get_item(Key={'id': 'visitor_count'})

    if 'Item' in response:
        count = response['Item']['count'] + 1
    else:
        # If record doesn't exist, start at 1
        count = 1

    # Update the count in DynamoDB
    table.put_item(Item={'id': 'visitor_count', 'count': count})

    return {
        'statusCode': 200,
        'headers': {
            "Access-Control-Allow-Origin": "*"  # Allows cross-origin access from your frontend
        },
        'body': json.dumps({"visitor_count": count})
    }
