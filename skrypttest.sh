#!/bin/bash

# Test 1: Public endpoint
echo "======================================"
echo "Test 1: Public endpoint (bez autoryzacji)"
echo "======================================"
curl -s http://localhost:3000/public | jq
echo ""

# Test 2: Secure endpoint bez tokena
echo "======================================"
echo "Test 2: Secure endpoint bez tokena"
echo "======================================"
status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/secure)
echo "Status: $status"
if [ "$status" -ne 401 ]; then
  echo "BŁĄD: Oczekiwano 401, otrzymano $status"
else
  echo "SUKCES: Brak autoryzacji"
fi
echo ""

# Test 3: Logowanie jako admin
echo "======================================"
echo "Test 3: Logowanie jako admin"
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

# Test 4: Secure endpoint jako admin
echo "======================================"
echo "Test 4: Secure endpoint jako admin"
echo "======================================"
response=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:3000/secure)
if [ -z "$response" ]; then
  echo "BŁĄD: Brak odpowiedzi"
else
  echo $response | jq
fi
echo ""

# Test 5: Logowanie jako user1
echo "======================================"
echo "Test 5: Logowanie jako user1"
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

# Test 6: Secure endpoint jako user
echo "======================================"
echo "Test 6: Secure endpoint jako user"
echo "======================================"
response=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN_USER" http://localhost:3000/secure)
if [ -z "$response" ]; then
  echo "BŁĄD: Brak odpowiedzi"
else
  echo $response | jq
fi
echo ""

# Test 7: Odświeżanie tokena
echo "======================================"
echo "Test 7: Odświeżanie tokena"
echo "======================================"
REFRESH_RESPONSE=$(curl -s -X POST \
  http://localhost:8080/auth/realms/secure-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=secure-api-client" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=$REFRESH_TOKEN")

NEW_ACCESS_TOKEN=$(echo $REFRESH_RESPONSE | jq -r '.access_token')
echo "Nowy access token: $NEW_ACCESS_TOKEN"
echo ""

# Test 8: Secure endpoint z odświeżonym tokenem
echo "======================================"
echo "Test 8: Secure endpoint z odświeżonym tokenem"
echo "======================================"
response=$(curl -s -H "Authorization: Bearer $NEW_ACCESS_TOKEN" http://localhost:3000/secure)
if [ -z "$response" ]; then
  echo "BŁĄD: Brak odpowiedzi"
else
  echo $response | jq
fi
echo ""

# Test 9: Secure endpoint z nieprawidłowym tokenem
echo "======================================"
echo "Test 9: Secure endpoint z nieprawidłowym tokenem"
echo "======================================"
status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer nieprawidlowy_token" http://localhost:3000/secure)
echo "Status: $status"
if [ "$status" -ne 403 ]; then
  echo "BŁĄD: Oczekiwano 403, otrzymano $status"
else
  echo "SUKCES: Nieprawidłowy token odrzucony"
fi
echo ""

# Test 10: Dane realm Keycloak
echo "======================================"
echo "Test 10: Dane realm Keycloak"
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

# Generowanie parametrów PKCE
CODE_VERIFIER=$(openssl rand -hex 32)
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | base64 | tr -d '=' | tr '/+' '_-')

echo "Code verifier: $CODE_VERIFIER"
echo "Code challenge: $CODE_CHALLENGE"
echo ""

# Symulacja uzyskania kodu autoryzacyjnego
echo "Otwórz w przeglądarce, zaloguj się i skopiuj kod:"
echo "http://localhost:8080/auth/realms/secure-realm/protocol/openid-connect/auth?client_id=secure-api-client&response_type=code&redirect_uri=http://localhost:3000/public&code_challenge=$CODE_CHALLENGE&code_challenge_method=S256"
echo ""

read -p "Wklej kod autoryzacyjny z URL: " AUTH_CODE

# Wymiana kodu na token
echo "Wymiana kodu na token:"
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

# Test 13: Secure endpoint z tokenem PKCE
echo "======================================"
echo "Test 13: Secure endpoint z tokenem PKCE"
echo "======================================"
response=$(curl -s -H "Authorization: Bearer $PKCE_ACCESS_TOKEN" http://localhost:3000/secure)
if [ -z "$response" ]; then
  echo "BŁĄD: Brak odpowiedzi"
else
  echo $response | jq
fi
echo ""

# Test 14: Dane użytkownika z tokena
echo "======================================"
echo "Test 14: Dane użytkownika z tokena"
echo "======================================"
echo "Token admina:"

# Pobierz część payloadu tokena
payload=$(echo $ACCESS_TOKEN | cut -d '.' -f2)
 
# Dodaj brakujące paddingi Base64
while [ $((${#payload} % 4)) -ne 0 ]; do
  payload="${payload}="
done

# Zamień znaki Base64URL na standardowe Base64 i dekoduj
echo "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq || echo "Błąd dekodowania tokena"
echo ""

# Test 15: Wylogowanie (revoke token)
echo "======================================"
echo "Test 15: Wylogowanie (revoke token)"
echo "======================================"
curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=secure-api-client" \
  -d "token=$REFRESH_TOKEN" \
  -d "token_type_hint=refresh_token" \
  http://localhost:8080/auth/realms/secure-realm/protocol/openid-connect/revoke

echo -e "\nWylogowano. Token został unieważniony."
echo ""

# Test 16: Próba użycia wygasłego tokena
echo "======================================"
echo "Test 16: Próba użycia wygasłego tokena"
echo "======================================"

# Użyj starego tokena, który powinien być wygasły
echo "Oczekiwanie 6 minut na wygaśnięcie tokena..."
for i in {1..6}; do
  echo "Minęło $i minut..."
  sleep 60
done

status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:3000/secure)
echo "Status: $status"
if [ "$status" -ne 403 ]; then
  echo "BŁĄD: Oczekiwano 403, otrzymano $status"
else
  echo "SUKCES: Token wygasł, dostęp zabroniony"
fi
echo ""

echo "======================================"
echo "WSZYSTKIE TESTY ZAKOŃCZONE"
echo "======================================"