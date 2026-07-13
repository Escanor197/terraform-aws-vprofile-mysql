#!/usr/bin/env bash

set -Eeuo pipefail

trap 'echo "ERROR: Script failed at line $LINENO."' ERR

if [[ $EUID -ne 0 ]]; then
    echo "Run this script using:"
    echo "sudo env DB_PASSWORD='...' MQ_PASSWORD='...' bash tomcat.sh"
    exit 1
fi

: "${DB_PASSWORD:?Set DB_PASSWORD to the RDS MySQL password.}"
: "${MQ_PASSWORD:?Set MQ_PASSWORD to the Amazon MQ RabbitMQ password.}"

TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.120}"
TOMCAT_HOME="/usr/local/tomcat"
APP_DIR="/opt/sourcecodeseniorwr"
APP_PROPERTIES="src/main/resources/application.properties"
APP_REPOSITORY="${APP_REPOSITORY:-https://github.com/abdelrahmanonline4/sourcecodeseniorwr.git}"
APP_BRANCH="${APP_BRANCH:-Master}"

DB_HOST="${DB_HOST:-db01.vprofile}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-accounts}"
DB_USER="${DB_USER:-root}"
MEMCACHED_HOST="${MEMCACHED_HOST:-mc01.vprofile}"
MQ_DNS_NAME="${MQ_DNS_NAME:-rmq01.vprofile}"
MQ_USERNAME="${MQ_USERNAME:-rabbitadmin}"

echo "========================================"
echo "Installing required packages"
echo "========================================"

dnf clean all
dnf makecache

dnf install -y \
    java-11-amazon-corretto-devel \
    git \
    maven \
    wget \
    tar \
    gzip \
    curl \
    bind-utils \
    stunnel \
    ca-certificates

JAVA11_JAVAC="$(rpm -ql java-11-amazon-corretto-devel | grep '/bin/javac$' | head -n 1)"
if [[ -z "${JAVA11_JAVAC}" ]]; then
    echo "Unable to locate the Amazon Corretto 11 JDK." >&2
    exit 1
fi

JAVA_HOME="${JAVA11_JAVAC%/bin/javac}"
export JAVA_HOME
export PATH="${JAVA_HOME}/bin:${PATH}"

echo "JAVA_HOME=${JAVA_HOME}"
"${JAVA_HOME}/bin/java" -version
"${JAVA_HOME}/bin/javac" -version
git --version
mvn -version

echo "========================================"
echo "Stopping any previous Tomcat installation"
echo "========================================"

systemctl stop tomcat 2>/dev/null || true
systemctl stop vprofile-rabbitmq-tunnel 2>/dev/null || true

echo "========================================"
echo "Creating the Tomcat user"
echo "========================================"

if ! id tomcat >/dev/null 2>&1; then
    useradd \
        --system \
        --home-dir "${TOMCAT_HOME}" \
        --shell /sbin/nologin \
        tomcat
else
    echo "Tomcat user already exists."
fi

echo "========================================"
echo "Downloading Apache Tomcat"
echo "========================================"

cd /tmp
TOMCAT_ARCHIVE="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/${TOMCAT_ARCHIVE}"

rm -f "${TOMCAT_ARCHIVE}" "${TOMCAT_ARCHIVE}.sha512"
wget -q "${TOMCAT_URL}" -O "${TOMCAT_ARCHIVE}"
wget -q "${TOMCAT_URL}.sha512" -O "${TOMCAT_ARCHIVE}.sha512"

EXPECTED_SHA512="$(awk '{print $1}' "${TOMCAT_ARCHIVE}.sha512")"
echo "${EXPECTED_SHA512}  ${TOMCAT_ARCHIVE}" | sha512sum -c -

echo "========================================"
echo "Installing Apache Tomcat"
echo "========================================"

rm -rf "${TOMCAT_HOME}"
mkdir -p "${TOMCAT_HOME}"

tar \
    -xzf "${TOMCAT_ARCHIVE}" \
    --strip-components=1 \
    -C "${TOMCAT_HOME}"

chown -R tomcat:tomcat "${TOMCAT_HOME}"
chmod +x "${TOMCAT_HOME}"/bin/*.sh

echo "========================================"
echo "Configuring the Amazon MQ TLS tunnel"
echo "========================================"

MQ_TLS_HOST="${MQ_TLS_HOST:-$(dig +short CNAME "${MQ_DNS_NAME}" | sed 's/\.$//' | head -n 1)}"

if [[ -z "${MQ_TLS_HOST}" ]]; then
    echo "Unable to discover the Amazon MQ broker hostname from ${MQ_DNS_NAME}." >&2
    echo "Set MQ_TLS_HOST manually to the Terraform rabbitmq_hostname output." >&2
    exit 1
fi

mkdir -p /etc/stunnel
cat > /etc/stunnel/vprofile-rabbitmq.conf <<EOF_STUNNEL
client = yes
foreground = yes

[rabbitmq]
accept = 127.0.0.1:5672
connect = ${MQ_DNS_NAME}:5671
CAfile = /etc/pki/tls/certs/ca-bundle.crt
verifyChain = yes
checkHost = ${MQ_TLS_HOST}
sni = ${MQ_TLS_HOST}
TIMEOUTclose = 0
EOF_STUNNEL

cat > /etc/systemd/system/vprofile-rabbitmq-tunnel.service <<'EOF_TUNNEL_SERVICE'
[Unit]
Description=TLS tunnel for Amazon MQ RabbitMQ
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/stunnel /etc/stunnel/vprofile-rabbitmq.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF_TUNNEL_SERVICE

echo "========================================"
echo "Creating the Tomcat systemd service"
echo "========================================"

cat > /etc/systemd/system/tomcat.service <<EOF_TOMCAT_SERVICE
[Unit]
Description=Apache Tomcat Web Application Container
After=network-online.target vprofile-rabbitmq-tunnel.service
Wants=network-online.target
Requires=vprofile-rabbitmq-tunnel.service

[Service]
Type=simple
User=tomcat
Group=tomcat
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="CATALINA_HOME=${TOMCAT_HOME}"
Environment="CATALINA_BASE=${TOMCAT_HOME}"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
ExecStart=${TOMCAT_HOME}/bin/catalina.sh run
Restart=on-failure
RestartSec=10
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF_TOMCAT_SERVICE

systemctl daemon-reload
systemctl enable --now vprofile-rabbitmq-tunnel.service
systemctl enable tomcat

echo "========================================"
echo "Cloning the application repository"
echo "========================================"

rm -rf "${APP_DIR}"

git clone \
    --branch "${APP_BRANCH}" \
    --single-branch \
    "${APP_REPOSITORY}" \
    "${APP_DIR}"

cd "${APP_DIR}"

if [[ ! -f "${APP_PROPERTIES}" ]]; then
    echo "ERROR: ${APP_PROPERTIES} was not found."
    exit 1
fi

echo "========================================"
echo "Updating MySQL configuration"
echo "========================================"

sed -i \
    's|^jdbc.driverClassName=.*|jdbc.driverClassName=com.mysql.cj.jdbc.Driver|' \
    "${APP_PROPERTIES}"

sed -i \
    "s|^jdbc.url=.*|jdbc.url=jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true\&characterEncoding=UTF-8\&zeroDateTimeBehavior=CONVERT_TO_NULL\&serverTimezone=UTC|" \
    "${APP_PROPERTIES}"

sed -i \
    "s|^jdbc.username=.*|jdbc.username=${DB_USER}|" \
    "${APP_PROPERTIES}"

sed -i \
    "s|^jdbc.password=.*|jdbc.password=${DB_PASSWORD}|" \
    "${APP_PROPERTIES}"

echo "========================================"
echo "Updating Memcached configuration"
echo "========================================"

sed -i \
    "s|^memcached.active.host=.*|memcached.active.host=${MEMCACHED_HOST}|" \
    "${APP_PROPERTIES}"

sed -i \
    "s|^memcached.standBy.host=.*|memcached.standBy.host=${MEMCACHED_HOST}|" \
    "${APP_PROPERTIES}"

echo "========================================"
echo "Updating RabbitMQ configuration"
echo "========================================"

sed -i \
    's|^rabbitmq.address=.*|rabbitmq.address=127.0.0.1|' \
    "${APP_PROPERTIES}"

sed -i \
    's|^rabbitmq.port=.*|rabbitmq.port=5672|' \
    "${APP_PROPERTIES}"

sed -i \
    "s|^rabbitmq.username=.*|rabbitmq.username=${MQ_USERNAME}|" \
    "${APP_PROPERTIES}"

sed -i \
    "s|^rabbitmq.password=.*|rabbitmq.password=${MQ_PASSWORD}|" \
    "${APP_PROPERTIES}"

echo "========================================"
echo "Showing non-secret updated properties"
echo "========================================"

grep -E \
    '^(jdbc\.driverClassName|jdbc\.url|jdbc\.username|memcached\.|rabbitmq\.address|rabbitmq\.port|rabbitmq\.username)' \
    "${APP_PROPERTIES}" || true

echo "========================================"
echo "Building the application without tests"
echo "========================================"

mvn clean package -Dmaven.test.skip=true

WAR_FILE="${APP_DIR}/target/vprofile-v2.war"

if [[ ! -f "${WAR_FILE}" ]]; then
    WAR_FILE="$(find "${APP_DIR}/target" -maxdepth 1 -type f -name '*.war' | head -n 1)"
fi

if [[ -z "${WAR_FILE}" || ! -f "${WAR_FILE}" ]]; then
    echo "ERROR: A WAR file was not created."
    exit 1
fi

echo "========================================"
echo "Deploying the application"
echo "========================================"

systemctl stop tomcat 2>/dev/null || true
rm -rf "${TOMCAT_HOME}/webapps/ROOT"
rm -f "${TOMCAT_HOME}/webapps/ROOT.war"

install \
    -o tomcat \
    -g tomcat \
    -m 0644 \
    "${WAR_FILE}" \
    "${TOMCAT_HOME}/webapps/ROOT.war"

chown -R tomcat:tomcat "${TOMCAT_HOME}"

echo "========================================"
echo "Starting Tomcat"
echo "========================================"

systemctl restart tomcat

echo "Waiting for the application to respond..."
for attempt in {1..60}; do
    if curl -fsS --connect-timeout 5 --max-time 10 \
        -o /dev/null http://127.0.0.1:8080/login; then
        echo "Tomcat application is responding on port 8080."
        systemctl --no-pager status tomcat || true
        echo "========================================"
        echo "Tomcat deployment completed"
        echo "========================================"
        exit 0
    fi

    sleep 5
done

echo "Tomcat is running, but the application did not become ready in time."
systemctl status tomcat --no-pager || true
journalctl -u tomcat --no-pager -n 200 || true
exit 1
