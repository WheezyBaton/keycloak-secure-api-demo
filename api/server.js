require("dotenv").config();
const express = require("express");
const jwt = require("jsonwebtoken");
const jwksClient = require("jwks-rsa");
const axios = require("axios");

const app = express();
const port = process.env.PORT || 3000;

const client = jwksClient({
      jwksUri: `${process.env.KEYCLOAK_URL}/realms/${process.env.KEYCLOAK_REALM}/protocol/openid-connect/certs`,
});

// Function to fetch the key
function getKey(header, callback) {
      client.getSigningKey(header.kid, (err, key) => {
            if (err) {
                  console.error("Error fetching key:", err);
                  return callback(err);
            }
            callback(null, key.getPublicKey());
      });
}

// Middleware with full token verification
const authenticateToken = async (req, res, next) => {
      try {
            console.log("Starting authorization");
            const authHeader = req.headers["authorization"];
            const token = authHeader?.split(" ")[1];

            if (!token) {
                  console.log("Missing token");
                  return res.status(401).json({ error: "Missing token" });
            }

            // Token signature verification
            const decoded = jwt.decode(token, { complete: true });
            if (!decoded) {
                  console.log("Invalid token");
                  return res.status(403).json({ error: "Invalid token" });
            }

            const key = await new Promise((resolve, reject) => {
                  getKey(decoded.header, (err, key) => {
                        if (err) reject(err);
                        else resolve(key);
                  });
            });

            jwt.verify(token, key, { algorithms: ["RS256"] }, async (err, user) => {
                  if (err) {
                        console.error("JWT verification error:", err);
                        return res.status(403).json({ error: "Invalid token" });
                  }

                  // SIMPLE REVOCATION CHECK (without introspect)
                  const currentTime = Math.floor(Date.now() / 1000);
                  if (user.exp < currentTime) {
                        console.log("Token expired");
                        return res.status(403).json({ error: "Token expired" });
                  }

                  const now = Math.floor(Date.now() / 1000);
                  if (user.exp < now) {
                        console.log(`Token expired (exp: ${user.exp}, now: ${now})`);
                        return res.status(403).json({ error: "Token expired" });
                  }

                  req.user = user;
                  next();
            });
      } catch (error) {
            console.error("Authorization error:", error);
            res.status(500).json({ error: "Server error" });
      }
};

// Endpoint with full error handling
app.get("/secure", authenticateToken, (req, res) => {
      try {
            const user = req.user;
            if (!user || !user.preferred_username || !user.realm_access?.roles) {
                  return res.status(403).json({ error: "Incomplete user data" });
            }

            const roles = user.realm_access.roles;

            if (roles.includes("admin")) {
                  return res.json({
                        message: "Administrative access!",
                        user: user.preferred_username,
                        roles,
                  });
            }

            if (roles.includes("user")) {
                  return res.json({
                        message: "User access",
                        user: user.preferred_username,
                        roles,
                  });
            }

            res.status(403).json({ error: "Missing required permissions" });
      } catch (error) {
            console.error("Error in /secure endpoint:", error);
            res.status(500).json({ error: "Server error" });
      }
});
