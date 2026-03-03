#!/bin/bash

# Test 1: Public endpoint
echo "======================================"
echo "Test 1: Public endpoint (unauthorized)"
echo "======================================"
curl -s http://localhost:3000/public | jq
echo ""

# Test 2: Secure endpoint without token
echo "======================================"
echo "Test 2: Secure endpoint without token"
echo "======================================"
status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/secure)
echo "Status: $status"
if [ "$status" -ne 401 ]; then
  echo "ERROR: Expected 401, received $status"
else
  echo "SUCCESS: Unauthorized"
fi
echo ""

# Test 3: Logging in as admin
echo "======================================"
echo "Test 3: Logging in as admin"
echo "======================================"
AUTH_RESPONSE=$(curl -s -X POST \
  http://localhost:8080/auth/realms/secure-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=secure-api-client" \
  -d "username=admin" \
  -d "password=admin123" \
  -d "grant_type=password")

ACCESS_TOKEN=$(echo $AUTH_RESPONSE | jq -r '.access_token')
REFRESH_TOKEN=$(echo $AUTH_RESPONSE | jq -r '.refresh_token')
echo "Access token: $ACCESS_TOKEN"
echo "Refresh token: $REFRESH_TOKEN"
echo ""

# Test 4: Secure endpoint as admin
echo "======================================"
echo "Test 4: Secure endpoint as admin"
echo "======================================"
response=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:3000/secure)
if [ -z "$response" ]; then
  echo "ERROR: No response"
else
  echo $response | jq
fi
echo ""

# Test 5: Logging in as user1
echo "======================================"
echo "Test 5: Logging in as user1"
echo "======================================"
AUTH_RESPONSE_USER=$(curl -s -X POST \
  http://localhost:8080/auth/realms/secure-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=secure-api-client" \
  -d "username=user1" \
  -d "password=user123" \
  -d "grant_type=password")

ACCESS_TOKEN_USER=$(echo $AUTH_RESPONSE_USER | jq -r '.access_token')
echo "Access token: $ACCESS_TOKEN_USER"
echo ""

# Test 6: Secure endpoint as user
echo "======================================"
echo "Test 6: Secure endpoint as user"
echo "======================================"
response=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN_USER" http://localhost:3000/secure)
if [ -z "$response" ]; then
  echo "ERROR: No response"
else
  echo $response | jq
fi
echo ""

# Test 7: Token refresh
echo "======================================"
echo "Test 7: Token refresh"
echo "======================================"
REFRESH_RESPONSE=$(curl -s -X POST \
  http://localhost:8080/auth/realms/secure-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=secure-api-client" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=$REFRESH_TOKEN")

NEW_ACCESS_TOKEN=$(echo $REFRESH_RESPONSE | jq -r '.access_token')
echo "New access token: $NEW_ACCESS_TOKEN"
echo ""

# Test 8: Secure endpoint with refreshed token
echo "======================================"
echo "Test 8: Secure endpoint with refreshed token"
echo "======================================"
response=$(curl -s -H "Authorization: Bearer $NEW_ACCESS_TOKEN" http://localhost:3000/secure)
if [ -z "$response" ]; then
  echo "ERROR: No response"
else
  echo $response | jq
fi
echo ""

# Test 9: Secure endpoint with invalid token
echo "======================================"
echo "Test 9: Secure endpoint with invalid token"
echo "======================================"
status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer invalid_token" http://localhost:3000/secure)
echo "Status: $status"
if [ "$status" -ne 403 ]; then
  echo "ERROR: Expected 403, received $status"
else
  echo "SUCCESS: Invalid token rejected"
fi
echo ""

# Test 10: Keycloak realm data
echo "======================================"
echo "Test 10: Keycloak realm data"
echo "======================================"
curl -s http://localhost:8080/auth/realms/secure-realm | jq
echo ""

# Test 11: OpenID Configuration
echo "======================================"
echo "Test 11: OpenID Configuration"
echo "======================================"
curl -s http://localhost:8080/auth/realms/secure-realm/.well-known/openid-configuration | jq
echo ""

# Test 12: PKCE Flow
echo "======================================"
echo "Test 12: PKCE Flow"
echo "======================================"

# Generating PKCE parameters
CODE_VERIFIER=$(openssl rand -hex 32)
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | base64 | tr -d '=' | tr '/+' '_-')

echo "Code verifier: $CODE_VERIFIER"
echo "Code challenge: $CODE_CHALLENGE"
echo ""

# Simulating authorization code acquisition
echo "Open in a browser, log in, and copy the code:"
echo "http://localhost:8080/auth/realms/secure-realm/protocol/openid-connect/auth?client_id=secure-api-client&response_type=code&redirect_uri=http://localhost:3000/public&code_challenge=$CODE_CHALLENGE&code_challenge_method=S256"
echo ""

read -p "Paste authorization code from URL: " AUTH_CODE

# Exchanging code for token
echo "Exchanging code for token:"
PKCE_RESPONSE=$(curl -s -X POST \
  http://localhost:8080/auth/realms/secure-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=secure-api-client" \
  -d "grant_type=authorization_code" \
  -d "code=$AUTH_CODE" \
  -d "redirect_uri=http://localhost:3000/public" \
  -d "code_verifier=$CODE_VERIFIER")

PKCE_ACCESS_TOKEN=$(echo $PKCE_RESPONSE | jq -r '.access_token')
echo "PKCE Access token: $PKCE_ACCESS_TOKEN"
echo ""

# Test 13: Secure endpoint with PKCE token
echo "======================================"
echo "Test 13: Secure endpoint with PKCE token"
echo "======================================"
response=$(curl -s -H "Authorization: Bearer $PKCE_ACCESS_TOKEN" http://localhost:3000/secure)
if [ -z "$response" ]; then
  echo "ERROR: No response"
else
  echo $response | jq
fi
echo ""

# Test 14: User data from token
echo "======================================"
echo "Test 14: User data from token"
echo "======================================"
echo "Admin token:"

# Get the token payload part
payload=$(echo $ACCESS_TOKEN | cut -d '.' -f2)

# Add missing Base64 paddings
while [ $((${#payload} % 4)) -ne 0 ]; do
  payload="${payload}="
done

# Replace Base64URL characters with standard Base64 and decode
echo "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq || echo "Token decoding error"
echo ""

# Test 15: Logout (revoke token)
echo "======================================"
echo "Test 15: Logout (revoke token)"
echo "======================================"
curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=secure-api-client" \
  -d "token=$REFRESH_TOKEN" \
  -d "token_type_hint=refresh_token" \
  http://localhost:8080/auth/realms/secure-realm/protocol/openid-connect/revoke

echo -e "\nLogged out. Token has been invalidated."
echo ""

# Test 16: Attempt to use expired token
echo "======================================"
echo "Test 16: Attempt to use expired token"
echo "======================================"

# Use the old token which should be expired
echo "Waiting 6 minutes for token expiration..."
for i in {1..6}; do
  echo "$i minutes passed..."
  sleep 60
done

status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:3000/secure)
echo "Status: $status"
if [ "$status" -ne 403 ]; then
  echo "ERROR: Expected 403, received $status"
else
  echo "SUCCESS: Token expired, access denied"
fi
echo ""

echo "======================================"
echo "ALL TESTS COMPLETED"
echo "======================================"
