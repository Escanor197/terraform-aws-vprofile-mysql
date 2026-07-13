#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "ERROR: MySQL initialization failed at line ${LINENO}." >&2' ERR

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

: "${DB_PASSWORD:?Set DB_PASSWORD to the RDS master password.}"

DB_HOST="${DB_HOST:-db01.vprofile}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-accounts}"
DB_USER="${DB_USER:-root}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SQL_FILE:-${SCRIPT_DIR}/../database/db_backup.sql}"

if [[ ! -f "${SQL_FILE}" ]]; then
  echo "SQL file not found: ${SQL_FILE}" >&2
  exit 1
fi

echo "Installing the MySQL-compatible client..."
dnf install -y mariadb105 || dnf install -y mariadb

echo "Checking DNS for ${DB_HOST}..."
getent hosts "${DB_HOST}"

echo "Waiting for MySQL at ${DB_HOST}:${DB_PORT}..."
for attempt in {1..60}; do
  if mariadb-admin ping \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --user="${DB_USER}" \
    --password="${DB_PASSWORD}" \
    --silent; then
    break
  fi

  if [[ ${attempt} -eq 60 ]]; then
    echo "MySQL did not become reachable in time." >&2
    exit 1
  fi

  sleep 10
done

echo "Importing ${SQL_FILE} into ${DB_NAME}..."
mariadb \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --user="${DB_USER}" \
  --password="${DB_PASSWORD}" \
  "${DB_NAME}" < "${SQL_FILE}"

echo "Validating imported tables and row counts..."
mariadb \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --user="${DB_USER}" \
  --password="${DB_PASSWORD}" \
  --database="${DB_NAME}" <<'SQL'
SHOW TABLES;
SELECT COUNT(*) AS role_count FROM role;
SELECT COUNT(*) AS user_count FROM `user`;
SELECT COUNT(*) AS user_role_count FROM user_role;
SQL

echo "MySQL schema and sample data were imported successfully."
