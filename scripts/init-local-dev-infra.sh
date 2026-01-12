#!/usr/bin/env bash
set -e

echo "Starting local dev infrastructure..."

# -----------------------------
# Config
# -----------------------------
POSTGRES_SERVICE="postgres"
VAULT_SERVICE="vault"

DB_HOST="localhost"
DB_NAME="merkato"
DB_ADMIN="admin"
APP_DB_USER="app_user"
APP_DB_PASS="app_password"

VAULT_ADDR="http://127.0.0.1:8200"
VAULT_TOKEN="root"

# -----------------------------
# Start containers
# -----------------------------
docker compose up -d

# -----------------------------
# Resolve container IDs
# -----------------------------
POSTGRES_CONTAINER=$(docker compose ps -q "$POSTGRES_SERVICE")
VAULT_CONTAINER=$(docker compose ps -q "$VAULT_SERVICE")

# -----------------------------
# Wait for Postgres
# -----------------------------
echo "Waiting for Postgres..."
until docker exec "$POSTGRES_CONTAINER" pg_isready -U "$DB_ADMIN" >/dev/null 2>&1; do
  sleep 2
done

# -----------------------------
# Ensure database exists
# -----------------------------
echo "Ensuring database exists..."

DB_EXISTS=$(docker exec "$POSTGRES_CONTAINER" psql \
  -U "$DB_ADMIN" \
  -d postgres \
  -Atc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" | tr -d '[:space:]')

if [ "$DB_EXISTS" != "1" ]; then
  echo "Creating database $DB_NAME..."
  docker exec "$POSTGRES_CONTAINER" psql \
    -U "$DB_ADMIN" \
    -d postgres \
    -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_ADMIN};"
fi

# -----------------------------
# Ensure app user exists
# -----------------------------
echo "Ensuring application DB user exists..."

USER_EXISTS=$(docker exec "$POSTGRES_CONTAINER" psql \
  -U "$DB_ADMIN" \
  -d postgres \
  -Atc "SELECT 1 FROM pg_roles WHERE rolname='${APP_DB_USER}';" | tr -d '[:space:]')

if [ "$USER_EXISTS" != "1" ]; then
  echo "Creating user $APP_DB_USER..."
  docker exec "$POSTGRES_CONTAINER" psql \
    -U "$DB_ADMIN" \
    -d postgres \
    -c "CREATE ROLE ${APP_DB_USER} LOGIN PASSWORD '${APP_DB_PASS}';"
fi

# -----------------------------
# Ensure schema permissions
# -----------------------------
echo "Ensuring schema permissions..."

docker exec "$POSTGRES_CONTAINER" psql \
  -U "$DB_ADMIN" \
  -d "$DB_NAME" \
  -c "
    GRANT USAGE, CREATE ON SCHEMA public TO ${APP_DB_USER};

    ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_DB_USER};

    ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO ${APP_DB_USER};
  "

# -----------------------------
# Wait for Vault
# -----------------------------
echo "Waiting for Vault..."
until docker exec "$VAULT_CONTAINER" wget -qO- http://127.0.0.1:8200/v1/sys/health >/dev/null 2>&1; do
  sleep 2
done

# -----------------------------
# Vault setup (dev mode)
# -----------------------------
echo "Configuring Vault..."

docker exec "$VAULT_CONTAINER" sh -c "
export VAULT_ADDR=${VAULT_ADDR}
export VAULT_TOKEN=${VAULT_TOKEN}

vault secrets enable -path=secret kv-v2 2>/dev/null

vault kv put secret/databases/merkato \
  DB_HOST=${DB_HOST} \
  DB_PORT=5432 \
  DB_NAME=${DB_NAME} \
  DB_USERNAME=${APP_DB_USER} \
  DB_PASSWORD=${APP_DB_PASS}
"

# -----------------------------
# Done
# -----------------------------
echo ""
echo "Local dev infrastructure is ready!"
echo ""
echo "Postgres:"
echo "  DB:       ${DB_NAME}"
echo "  User:     ${APP_DB_USER}"
echo ""
echo "Vault:"
echo "  Path:     secret/databases/merkato"
echo ""
