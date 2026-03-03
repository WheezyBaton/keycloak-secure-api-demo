# Keycloak Secure API Demo (OAuth 2.0 + PKCE in Kubernetes)

This project demonstrates a production-grade implementation of API security using the **OAuth 2.0** standard with **PKCE** (Proof Key for Code Exchange). The system consists of **Keycloak** acting as the Identity Provider (IdP) and a **Node.js Express API**, both running within a **Kubernetes** cluster.

## Project Goals

* Implement a secure, containerized environment using **Kubernetes**.
* Secure the API independently using **JWT** (JSON Web Tokens) verification.
* Implement **Role-Based Access Control (RBAC)** where the API returns different data based on the user's role (`admin` vs `user`).
* Enforce the **PKCE** flow to protect against authorization code injection attacks.

## Architecture & Flow

1. **Identity Provider:** Keycloak (v22.0.0) handles user authentication and token issuance.
2. **API Security:** The Node.js backend uses a custom `authenticateToken` middleware.
3. **Token Validation:** Instead of manually checking tokens, the API fetches public keys from Keycloak's **JWKS** (JSON Web Key Set) endpoint to verify the JWT signature.
4. **Security Flow:** * The client initiates the **Authorization Code Flow with PKCE**.
* After successful login, Keycloak issues a JWT containing user roles.
* The API validates the token's signature, expiration, and roles before granting access to the `/secure` endpoint.



## Technologies Used

* **Backend:** Node.js, Express.js
* **Auth:** Keycloak, OAuth 2.0, PKCE, JWT
* **Infrastructure:** Kubernetes (Deployments, Services, ConfigMaps)
* **DevOps:** Docker

## Prerequisites

* **Docker Desktop** with Kubernetes enabled (or Minikube).
* **kubectl** CLI.
* **Node.js** (optional, for local development).
* **Git**.

---

## Setup Instructions

### 1. Build and Push the API Image

Since the API deployment uses a custom image, you must build it and push it to your Docker registry:

```bash
cd api
docker build -t your-dockerhub-username/secure-api:1.0.0 .
docker push your-dockerhub-username/secure-api:1.0.0
cd ..

```

### 2. Update Kubernetes Manifests

Open `k8s/4_api-deployment.yaml` and update the image field with your DockerHub username:

```yaml
containers:
  - name: api
    image: your-dockerhub-username/secure-api:1.0.0

```

### 3. Deploy to Kubernetes

Apply all manifests in the `k8s/` directory:

```bash
kubectl apply -f k8s/

```

### 4. Verify Deployment

Wait for all pods to be in the `Running` state:

```bash
kubectl get pods --watch

```

### 5. Port Forwarding

To access the services locally, forward the necessary ports in two separate terminals:

* **Terminal 1 (Keycloak):**
```bash
kubectl port-forward svc/keycloak 8080:8080

```


* **Terminal 2 (API):**
```bash
kubectl port-forward svc/api 3000:80

```



---

## Testing the Application

### Test Credentials

| User | Password | Role |
| --- | --- | --- |
| **admin** | `admin123` | admin |
| **user1** | `user123` | user |

*Keycloak Admin Console: [http://localhost:8080/auth/admin](https://www.google.com/search?q=http://localhost:8080/auth/admin) (Login: `admin` / `admin`)*

### Automated Test Script

The project includes a comprehensive test script (`skrypttest.sh`) that performs 16 different security tests, including:

* Unauthorized access attempts.
* Token issuance and refresh flow.
* **PKCE flow simulation**.
* Role validation (Admin vs User access).
* Token revocation and expiration tests.

To run the tests:

```bash
chmod +x ./skrypttest.sh
./skrypttest.sh

```
