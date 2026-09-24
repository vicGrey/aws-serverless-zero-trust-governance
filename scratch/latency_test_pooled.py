import time
import json
import urllib3
import boto3

# Configuration (from Terraform outputs)
USER_POOL_ID = "us-east-1_Fk56OQIcr"
CLIENT_ID = "3p3radj3fvbovnvc7bvbaq1k65"
API_ENDPOINT = "https://dm947rj7k0.execute-api.us-east-1.amazonaws.com/dev/transactions"
REGION = "us-east-1"

# Test User Credentials
TEST_USERNAME = "fyp-latency-tester-pooled"
TEST_PASSWORD = "Password123!"
TEST_EMAIL = "fyp-tester-pooled@example.com"

def main():
    cognito = boto3.client("cognito-idp", region_name=REGION)
    
    print("=== Step 1: Creating Cognito Test User ===")
    try:
        # Create user admin-side
        cognito.admin_create_user(
            UserPoolId=USER_POOL_ID,
            Username=TEST_USERNAME,
            UserAttributes=[
                {"Name": "email", "Value": TEST_EMAIL},
                {"Name": "email_verified", "Value": "true"}
            ],
            MessageAction="SUPPRESS"
        )
        print(f"Created user: {TEST_USERNAME}")
        
        # Set permanent password
        cognito.admin_set_user_password(
            UserPoolId=USER_POOL_ID,
            Username=TEST_USERNAME,
            Password=TEST_PASSWORD,
            Permanent=True
        )
        print("Password configured successfully.")
    except Exception as e:
        print(f"Error creating user: {e}")
    
    print("\n=== Step 2: Authenticating User to get JWT ===")
    try:
        auth_response = cognito.initiate_auth(
            ClientId=CLIENT_ID,
            AuthFlow="USER_PASSWORD_AUTH",
            AuthParameters={
                "USERNAME": TEST_USERNAME,
                "PASSWORD": TEST_PASSWORD
            }
        )
        id_token = auth_response["AuthenticationResult"]["IdToken"]
        print("Successfully obtained ID Token.")
    except Exception as e:
        print(f"Authentication failed: {e}")
        cleanup(cognito)
        return

    print("\n=== Step 3: Running Pooled Latency Test (50 Requests) ===")
    latencies = []
    success_count = 0
    
    payload = json.dumps({
        "amount": 100.00,
        "currency": "USD",
        "recipient_account": "9876543210",
        "description": "Automated FYP Pooled Latency Test"
    })
    
    headers = {
        "Authorization": id_token,
        "Content-Type": "application/json"
    }

    # Initialize urllib3 PoolManager for connection reuse
    http = urllib3.PoolManager()

    for i in range(1, 51):
        start_time = time.time()
        try:
            # http.request reuses TCP connections internally
            response = http.request(
                "POST",
                API_ENDPOINT,
                body=payload,
                headers=headers
            )
            response.data
            end_time = time.time()
            
            if response.status == 201:
                latency = (end_time - start_time) * 1000 # ms
                latencies.append(latency)
                success_count += 1
                print(f"Request #{i}: Success | Latency: {latency:.2f} ms")
            else:
                print(f"Request #{i}: Failed with status code {response.status}")
        except Exception as e:
            print(f"Request #{i}: Error: {e}")
        
        time.sleep(0.1)

    print("\n=== Step 4: Compiling Results ===")
    if latencies:
        latencies.sort()
        avg_latency = sum(latencies) / len(latencies)
        p95_index = int(len(latencies) * 0.95) - 1
        p95_latency = latencies[p95_index]
        
        print(f"Total Requests: 50")
        print(f"Successful Requests: {success_count} / 50")
        print(f"Average Latency: {avg_latency:.2f} ms")
        print(f"95th Percentile (p95) Latency: {p95_latency:.2f} ms")
        
        # Save metrics log for Chapter 4 evidence
        results = {
            "total_requests": 50,
            "success_rate": f"{(success_count / 50) * 100:.2f}%",
            "avg_latency_ms": round(avg_latency, 2),
            "p95_latency_ms": round(p95_latency, 2),
            "raw_latencies": latencies
        }
        with open("/home/viktor/aws-serverless-zero-trust-governance/scratch/latency_results_pooled.json", "w") as f:
            json.dump(results, f, indent=4)
        print("Saved raw data to scratch/latency_results_pooled.json")
    else:
        print("No latencies recorded.")

    cleanup(cognito)

def cleanup(cognito_client):
    print("\n=== Step 5: Cleaning Up Test User ===")
    try:
        cognito_client.admin_delete_user(
            UserPoolId=USER_POOL_ID,
            Username=TEST_USERNAME
        )
        print("Test user deleted successfully.")
    except Exception as e:
        print(f"Error cleaning up user: {e}")

if __name__ == "__main__":
    main()
