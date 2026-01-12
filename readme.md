# Backend Core

## 📦 Tech Stack

- Backend: Spring Boot 4.0.1 · Java 25 (Temurin)
- Database: PostgreSQL
- Secrets Management: HashiCorp Vault
- Containerization: Docker · Docker Compose
- Automation: PowerShell / Bash scripts

---

## 🚀 Getting Started

### Prerequisites

Make sure you have the following installed:

- Docker Desktop
    - Docker Engine
    - Docker Compose v2
- PowerShell (Windows) or bash (Linux / macOS)
- JDK 25 (Temurin)

---

## 🏗️ Local Environment Setup

The project provides a single bootstrap script to prepare the local environment.

What it does:

- Starts required containers
- Ensures database and users exist
- Makes secrets available via Vault

### Windows

    .\scripts\init-local-dev-infra.ps1

### Linux / macOS

    chmod +x scripts/init-local-dev-infra.sh
    ./scripts/init-local-dev-infra.sh

The script is idempotent and safe to run multiple times.

---

## 🔐 Secrets Management (Vault)

The project uses HashiCorp Vault as a secrets provider.

### Local Usage

- Vault runs in development mode
- Secrets are exposed via HTTP
- A static root token is used locally

Vault UI:

    http://localhost:8200

Login token:

    root

---

### Accessing Secrets (CLI)

    docker exec \
      -e VAULT_ADDR=http://127.0.0.1:8200 \
      -e VAULT_TOKEN=root \
      backend-core-vault-1 \
      vault kv get secret/merkato/db
