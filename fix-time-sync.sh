#!/bin/bash
#
# fix-time-sync.sh (improved version)
# Run with: sudo ./fix-time-sync.sh
#

set -euo pipefail

echo "=== GitHub Runner Time Sync Fix (Improved) ==="
echo

if [[ $EUID -ne 0 ]]; then
   echo "Run as root or with sudo"
   exit 1
fi

# 1. Install packages
echo "[1/5] Installing chrony + ntpdate..."
apt-get update -qq
apt-get install -y chrony ntpdate

# 2. Update chrony.conf
CHRONY_CONF="/etc/chrony.conf"
cp "$CHRONY_CONF" "${CHRONY_CONF}.bak.$(date +%F_%T)"
sed -i 's/^makestep.*/makestep 1 -1/' "$CHRONY_CONF" || echo "makestep 1 -1" >> "$CHRONY_CONF"
echo "   makestep set to: $(grep '^makestep' $CHRONY_CONF)"

# 3. Create helper script (avoids quoting issues)
HELPER="/usr/local/bin/force-ntp-sync.sh"
cat > "$HELPER" << 'EOF'
#!/bin/bash
echo "[force-ntp-sync] Starting early time sync..."
/usr/bin/ntpdate -u pool.ntp.org || true
/usr/bin/chronyc makestep || true
sleep 2
echo "[force-ntp-sync] Done."
EOF
chmod +x "$HELPER"
echo "[2/5] Helper script created at $HELPER"

# 4. Create systemd service (clean version)
SERVICE_FILE="/etc/systemd/system/time-sync-fix.service"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Force early NTP time sync before GitHub runner starts
DefaultDependencies=no
Before=network.target
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$HELPER
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "[3/5] Service created"

# 5. Enable + apply
systemctl daemon-reload
systemctl enable time-sync-fix.service

# Add dependency to runner services
RUNNER_SERVICES=$(systemctl list-unit-files --type=service | grep -E 'actions\.runner' | awk '{print $1}' || true)
for SERVICE in $RUNNER_SERVICES; do
    OVERRIDE_DIR="/etc/systemd/system/${SERVICE}.d"
    mkdir -p "$OVERRIDE_DIR"
    cat > "${OVERRIDE_DIR}/time-sync-dependency.conf" << EOF
[Unit]
After=time-sync-fix.service
Wants=time-sync-fix.service
EOF
    echo "   Added dependency to $SERVICE"
done

systemctl daemon-reload
systemctl restart chrony
systemctl start time-sync-fix.service

# Final sync
echo "[4/5] Forcing sync now..."
$HELPER

echo
echo "✅ All done!"
echo
echo "Reboot and verify with:"
echo "  timedatectl"
echo "  chronyc tracking"
echo "  systemctl status time-sync-fix"
