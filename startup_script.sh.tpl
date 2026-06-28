#!/usr/bin/env bash
# Terraform templatefile() variables:
#   ${gcs_bucket}, ${gcs_installer_path}, ${ps_install_dir}
#   ${ps_port}, ${sfg_engine_ip}, ${sfg_engine_port}
# Bash variables use $$ to prevent Terraform from interpolating them.
set -euo pipefail

GCS_BUCKET="${gcs_bucket}"
GCS_INSTALLER_PATH="${gcs_installer_path}"
PS_INSTALL_DIR="${ps_install_dir}"
PS_PORT="${ps_port}"
SFG_ENGINE_IP="${sfg_engine_ip}"
SFG_ENGINE_PORT="${sfg_engine_port}"
METADATA_BASE="http://metadata.google.internal/computeMetadata/v1"
METADATA_HEADER="Metadata-Flavor: Google"

log() { echo "[sfg-ps] $$1" | tee -a /var/log/sfg-ps-startup.log; }

log "=== SFG Perimeter Server startup begin ==="

# ── Install Java 11 ───────────────────────────────────────────────────────────
log "Installing Java 11 and Cloud SDK..."
if [ -f /etc/debian_version ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y -q
  apt-get install -y -q openjdk-11-jdk-headless google-cloud-cli unzip
elif [ -f /etc/redhat-release ]; then
  yum update -y -q
  yum install -y -q java-11-openjdk-headless google-cloud-sdk unzip
else
  log "ERROR: Unsupported OS"; exit 1
fi

# ── Fetch instance metadata ───────────────────────────────────────────────────
INSTANCE_NAME=$$(curl -sf -H "$$METADATA_HEADER" "$$METADATA_BASE/instance/name")
PRIVATE_IP=$$(curl -sf -H "$$METADATA_HEADER" "$$METADATA_BASE/instance/network-interfaces/0/ip")
log "Instance=$$INSTANCE_NAME  IP=$$PRIVATE_IP"

# ── Download and install perimeter server ─────────────────────────────────────
log "Downloading installer from gs://$$GCS_BUCKET/$$GCS_INSTALLER_PATH ..."
mkdir -p /tmp/sfg-ps-install
gcloud storage cp "gs://$$GCS_BUCKET/$$GCS_INSTALLER_PATH" /tmp/sfg-ps-install/ps-installer.zip
unzip -q /tmp/sfg-ps-install/ps-installer.zip -d /tmp/sfg-ps-install/

mkdir -p "$$PS_INSTALL_DIR"
INSTALLER=$$(find /tmp/sfg-ps-install -maxdepth 3 \( -name "install.sh" -o -name "InstallPerimeterServer.jar" \) | head -1)
if [ -z "$$INSTALLER" ]; then
  log "ERROR: installer not found in archive"; exit 1
fi

case "$$INSTALLER" in
  *.jar) java -jar "$$INSTALLER" -DUSER_INSTALL_DIR="$$PS_INSTALL_DIR" -i silent 2>&1 | tee -a /var/log/sfg-ps-install.log ;;
  *.sh)  bash "$$INSTALLER" -DUSER_INSTALL_DIR="$$PS_INSTALL_DIR" -i silent 2>&1 | tee -a /var/log/sfg-ps-install.log ;;
esac
log "Install complete."

# ── Write configuration ───────────────────────────────────────────────────────
mkdir -p "$$PS_INSTALL_DIR/properties"
cat > "$$PS_INSTALL_DIR/properties/perimeter_server.properties" <<PSCFG
localAddress=$$PRIVATE_IP
localPort=$$PS_PORT
remoteAddress=$$SFG_ENGINE_IP
remotePort=$$SFG_ENGINE_PORT
instanceName=$$INSTANCE_NAME
PSCFG
log "Configuration written."

# ── Start perimeter server ────────────────────────────────────────────────────
cat > /etc/systemd/system/sfg-perimeter.service <<SVCUNIT
[Unit]
Description=IBM Sterling SFG Perimeter Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$$PS_INSTALL_DIR
ExecStart=/usr/bin/java -jar $$PS_INSTALL_DIR/bin/perimeter_server.jar \
  -localAddress $$PRIVATE_IP -localPort $$PS_PORT \
  -remoteAddress $$SFG_ENGINE_IP -remotePort $$SFG_ENGINE_PORT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCUNIT

systemctl daemon-reload
systemctl enable sfg-perimeter
systemctl start sfg-perimeter

log "=== SFG Perimeter Server startup complete ==="
