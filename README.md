# Projekt zabezpieczenia API z OAuth 2.0 i PKCE w Kubernetes

Ten projekt demonstruje implementację zabezpieczeń API przy użyciu standardu OAuth 2.0 z PKCE (Proof Key for Code Exchange). System składa się z Keycloak jako dostawcy tożsamości (IdP) oraz prostego API napisanego w Express.js, wszystko uruchomione w klastrze Kubernetes.

## Cel projektu

Zabezpieczenie API przy użyciu standardu OAuth 2.0 z uwzględnieniem następujących kryteriów:

- API i IdP działają poprawnie
- Projekt działa w Kubernetes
- API jest niezależnie zabezpieczone
- API zwraca różne wartości w zależności od roli użytkownika
- Zaimplementowano mechanizm PKCE

## Wymagania wstępne

- Docker Desktop z włączonym Kubernetes
- kubectl (zazwyczaj wbudowany w Docker Desktop)
- Git
- Node.js (opcjonalnie, do modyfikacji API)

# Uruchomienie projektu krok po kroku

## 1. Sklonuj repozytorium

## 2. Zbuduj i opublikuj obraz Dockera dla API

cd api

docker build -t twoj-dockerhub-uzytkownik/secure-api:1.0.0 .

docker push twoj-dockerhub-uzytkownik/secure-api:1.0.0

cd ..

## 3. Wdróż aplikację w Kubernetes

kubectl apply -f k8s/

## 4. Sprawdź status wdrożenia

kubectl get pods --watch

Czekaj aż wszystkie pody będą w stanie Running (może to zająć 1-2 minuty).

## 5. Może być konieczne załadowanie realma do keycloaka

W tym celu należy stworzyć nowy realm i załadować plik keycloak/realm-config.json

## 6. Przekieruj porty

Terminal 1 - Keycloak

kubectl port-forward svc/keycloak 8080:8080

Terminal 2 - API

kubectl port-forward svc/api 3000:80

## Testowanie aplikacji

Dane testowe

### Użytkownik - admin

Hasło - admin123

Rola - admin

### Użytkownik - user1

Hasło - user123

Rola - user

### Strona keycloak

http://localhost:8080/auth/admin

### Użytkownik - admin

Hasło - admin

### Skrypt testujący api znajduje się w pliku skrypttest.sh

chmod +x ./skrypttest.sh

./skrypttest.sh
