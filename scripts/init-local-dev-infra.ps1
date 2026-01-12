Write-Host "Starting local dev infrastructure..."

# -----------------------------
# Config
# -----------------------------
$POSTGRES_SERVICE = "postgres"
$VAULT_SERVICE    = "vault"

$DB_HOST     = "localhost"
$DB_NAME     = "merkato"
$DB_ADMIN    = "admin"
$APP_DB_USER = "app_user"
$APP_DB_PASS = "app_password"

$VAULT_ADDR  = "http://127.0.0.1:8200"
$VAULT_TOKEN = "root"

# -----------------------------
# Start containers
# -----------------------------
docker compose up -d

# -----------------------------
# Resolve container IDs
# -----------------------------
$POSTGRES_CONTAINER = docker compose ps -q $POSTGRES_SERVICE
$VAULT_CONTAINER    = docker compose ps -q $VAULT_SERVICE

# -----------------------------
# Wait for Postgres
# -----------------------------
Write-Host "Waiting for Postgres..."
do {
    Start-Sleep -Seconds 2
    $pgReady = docker exec $POSTGRES_CONTAINER pg_isready -U $DB_ADMIN 2>$null
} while ($pgReady -notmatch "accepting connections")

# -----------------------------
# Ensure database exists
# -----------------------------
Write-Host "Ensuring database exists..."

$DB_EXISTS = docker exec $POSTGRES_CONTAINER psql `
    -U $DB_ADMIN `
    -d postgres `
    -Atc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';"

$DB_EXISTS = $DB_EXISTS.Trim()

if ($DB_EXISTS -ne "1") {
    Write-Host "Creating database $DB_NAME..."
    docker exec $POSTGRES_CONTAINER psql `
        -U $DB_ADMIN `
        -d postgres `
        -c "CREATE DATABASE $DB_NAME OWNER $DB_ADMIN;"
}

# -----------------------------
# Ensure app user exists
# -----------------------------
Write-Host "Ensuring application DB user exists..."

$USER_EXISTS = docker exec $POSTGRES_CONTAINER psql `
    -U $DB_ADMIN `
    -d postgres `
    -Atc "SELECT 1 FROM pg_roles WHERE rolname='$APP_DB_USER';"

$USER_EXISTS = $USER_EXISTS.Trim()

if ($USER_EXISTS -ne "1") {
    Write-Host "Creating user $APP_DB_USER..."
    docker exec $POSTGRES_CONTAINER psql `
        -U $DB_ADMIN `
        -d postgres `
        -c "CREATE ROLE $APP_DB_USER LOGIN PASSWORD '$APP_DB_PASS';"
}

# -----------------------------
# Ensure schema permissions
# -----------------------------
Write-Host "Ensuring schema permissions..."

docker exec $POSTGRES_CONTAINER psql `
    -U $DB_ADMIN `
    -d $DB_NAME `
    -c "
    GRANT USAGE, CREATE ON SCHEMA public TO $APP_DB_USER;

    ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $APP_DB_USER;

    ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO $APP_DB_USER;
    "

# -----------------------------
# Wait for Vault
# -----------------------------
Write-Host "Waiting for Vault..."
do {
    Start-Sleep -Seconds 2
    $vaultUp = docker exec $VAULT_CONTAINER wget -qO- http://127.0.0.1:8200/v1/sys/health
} while (-not $vaultUp)

# -----------------------------
# Vault setup (dev mode)
# -----------------------------
Write-Host "Configuring Vault..."

docker exec $VAULT_CONTAINER sh -c "
export VAULT_ADDR=$VAULT_ADDR
export VAULT_TOKEN=$VAULT_TOKEN

vault secrets enable -path=secret kv-v2 2>/dev/null

vault kv put secret/databases/merkato \
  DB_HOST=$DB_HOST \
  DB_PORT=5432 \
  DB_NAME=$DB_NAME \
  DB_USERNAME=$APP_DB_USER \
  DB_PASSWORD=$APP_DB_PASS
"

# -----------------------------
# Done
# -----------------------------
Write-Host ""
Write-Host "Local dev infrastructure is ready!"
Write-Host ""
Write-Host "Postgres:"
Write-Host "  DB:       $DB_NAME"
Write-Host "  User:     $APP_DB_USER"
Write-Host ""
Write-Host "Vault:"
Write-Host "  Path:     secret/databases/merkato"
Write-Host ""
