import json
import boto3

def lambda_handler(event, context):
    """
    Custom AWS Config Rule Lambda handler to verify that API Gateway 
    methods enforce authentication (Cognito User Pools).
    """
    invoking_event = json.loads(event['invokingEvent'])
    rule_parameters = json.loads(event.get('ruleParameters', '{}'))
    
    configuration_item = invoking_event['configurationItem']
    resource_type = configuration_item['resourceType']
    resource_id = configuration_item['resourceId']
    
    compliance = 'COMPLIANT'
    
    # We only check API Gateway REST APIs
    if resource_type == 'AWS::ApiGateway::RestApi':
        configuration = configuration_item.get('configuration', {})
        # Scan methods inside API resources
        resources = configuration.get('resources', {})
        for res_id, resource in resources.items():
            resource_methods = resource.get('resourceMethods', {})
            for method_name, method in resource_methods.items():
                # Ignore OPTIONS methods (CORS preflight)
                if method_name == 'OPTIONS':
                    continue
                
                # Verify that authorizationType is COGNITO_USER_POOLS
                auth_type = method.get('authorizationType', 'NONE')
                if auth_type != 'COGNITO_USER_POOLS':
                    compliance = 'NON_COMPLIANT'
                    break
            if compliance == 'NON_COMPLIANT':
                break
                
    config_client = boto3.client('config')
    config_client.put_evaluations(
        Evaluations=[
            {
                'ComplianceResourceType': resource_type,
                'ComplianceResourceId': resource_id,
                'ComplianceType': compliance,
                'OrderingTimestamp': configuration_item['configurationItemCaptureTime']
            },
        ],
        ResultToken=event['resultToken']
    )
