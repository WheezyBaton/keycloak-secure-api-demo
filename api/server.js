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

// Funkcja do pobierania klucza
function getKey(header, callback) {
      client.getSigningKey(header.kid, (err, key) => {
            if (err) {
                  console.error("Błąd pobierania klucza:", err);
                  return callback(err);
            }
            callback(null, key.getPublicKey());
      });
}

// Middleware z pełną weryfikacją tokena
const authenticateToken = async (req, res, next) => {
      try {
            console.log("Rozpoczęcie autoryzacji");
            const authHeader = req.headers["authorization"];
            const token = authHeader?.split(" ")[1];

            if (!token) {
                  console.log("Brak tokena");
                  return res.status(401).json({ error: "Brak tokena" });
            }

            // Weryfikacja podpisu tokena
            const decoded = jwt.decode(token, { complete: true });
            if (!decoded) {
                  console.log("Nieprawidłowy token");
                  return res.status(403).json({ error: "Nieprawidłowy token" });
            }

            const key = await new Promise((resolve, reject) => {
                  getKey(decoded.header, (err, key) => {
                        if (err) reject(err);
                        else resolve(key);
                  });
            });

            jwt.verify(token, key, { algorithms: ["RS256"] }, async (err, user) => {
                  if (err) {
                        console.error("Błąd weryfikacji JWT:", err);
                        return res.status(403).json({ error: "Nieprawidłowy token" });
                  }

                  // PROSTE SPRAWDZENIE UNIEWAŻNIENIA (bez introspect)
                  const currentTime = Math.floor(Date.now() / 1000);
                  if (user.exp < currentTime) {
                        console.log("Token wygasł");
                        return res.status(403).json({ error: "Token wygasł" });
                  }

                  const now = Math.floor(Date.now() / 1000);
                  if (user.exp < now) {
                        console.log(`Token wygasł (exp: ${user.exp}, now: ${now})`);
                        return res.status(403).json({ error: "Token wygasł" });
                  }

                  req.user = user;
                  next();
            });
      } catch (error) {
            console.error("Błąd autoryzacji:", error);
            res.status(500).json({ error: "Błąd serwera" });
      }
};

// Endpoint z pełną obsługą błędów
app.get("/secure", authenticateToken, (req, res) => {
      try {
            const user = req.user;
            if (!user || !user.preferred_username || !user.realm_access?.roles) {
                  return res.status(403).json({ error: "Niekompletne dane użytkownika" });
            }

            const roles = user.realm_access.roles;

            if (roles.includes("admin")) {
                  return res.json({
                        message: "Dostęp administracyjny!",
                        user: user.preferred_username,
                        roles,
                  });
            }

            if (roles.includes("user")) {
                  return res.json({
                        message: "Dostęp użytkownika",
                        user: user.preferred_username,
                        roles,
                  });
            }

            res.status(403).json({ error: "Brak wymaganych uprawnień" });
      } catch (error) {
            console.error("Błąd endpointa /secure:", error);
            res.status(500).json({ error: "Błąd serwera" });
      }
});
