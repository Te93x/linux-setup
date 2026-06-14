#!/bin/bash
#
# vm-chrony-boot-sync.sh
# Installs chrony + configures it for reliable time sync on boot in VMs.
# Especially useful when the host machine sleeps or shuts down (causing large
# guest time drift). Run once with sudo, then it will handle sync automatically
# on every boot.
#
# Usage: sudo ./vm-chrony-boot-sync.sh
#
set -euo pipefail

echo "=== VM Chrony Boot Time Sync Setup ==="
echo "This will install/configure chrony to handle large time drift on boot."
echo

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Run as root or with sudo"
   exit 1
fi

# 1. Install packages
echo "[1/5] Installing chrony and ntpdate..."
apt-get update -qq
apt-get install -y chrony ntpdate

# 2. Update chrony.conf (preserve existing config, enhance for VM drift)
CHRONY_CONF="/etc/chrony/chrony.conf"
BACKUP="${CHRONY_CONF}.bak.$(date +%F_%T)"
cp "$CHRONY_CONF" "$BACKUP"
echo "   Backed up original to $BACKUP"

# Remove any existing makestep line and add aggressive VM-friendly version
# makestep 1 -1 = step clock if offset >1s (even on first boot update)
sed -i '/^makestep/d' "$CHRONY_CONF"
echo "makestep 1 -1" >> "$CHRONY_CONF"

# Add extra reliable NTP pools (if not already present)
for POOL in "time.google.com" "time.cloudflare.com"; do
    if ! grep -q "$POOL" "$CHRONY_CONF"; then
        echo "pool $POOL iburst" >> "$CHRONY_CONF"
    fi
done

# Ensure rtcsync is present (keeps RTC in sync - very useful for VMs/suspend)
if ! grep -q '^rtcsync' "$CHRONY_CONF"; then
    echo "rtcsync" >> "$CHRONY_CONF"
fi

echo "   chrony.conf updated:"
echo "     - makestep 1 -1 (large drift tolerance on boot)"
echo "     - Added Google + Cloudflare NTP pools"
echo "     - rtcsync enabled"

# 3. Create force-sync helper script (robust, full paths)
HELPER="/usr/local/bin/force-vm-time-sync.sh"
cat > "$HELPER" << 'EOF'
#!/bin/bash
# Force early/late time sync for VMs that may have large drift
# (e.g. after host sleep/shutdown)
echo "[force-vm-time-sync] Starting forced time correction..."
/usr/bin/ntpdate -u pool.ntp.org || true
/usr/bin/chronyc makestep || true
sleep 2
echo "[force-vm-time-sync] Done. System time is now: $(date '+%Y-%m-%d %H:%M:%S %Z')"
EOF
chmod +x "$HELPER"
echo "[2/5] Helper script created at $HELPER"

# 4. Create systemd service (runs early after network is ready)
SERVICE_FILE="/etc/systemd/system/vm-time-sync.service"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Force early NTP time sync on boot (VM drift protection)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$HELPER
RemainAfterExit=yes
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF
echo "[3/5] Systemd service created at $SERVICE_FILE"

# 5. Enable + apply everything
echo "[4/5] Enabling services and applying config..."
systemctl daemon-reload
systemctl enable chrony
systemctl enable vm-time-sync.service
systemctl restart chrony
systemctl start vm-time-sync.service

# Final verification sync
echo "[5/5] Performing immediate sync..."
$HELPER

echo
echo "✅ Setup complete!"
echo
echo "What happens now:"
echo "  • chrony is installed and will run on boot"
echo "  • On every boot, vm-time-sync.service forces a makestep if drift >1s"
echo "  • Multiple NTP sources + rtcsync help minimize future drift"
echo
echo "After next reboot, verify with:"
echo "  timedatectl"
echo "  chronyc tracking"
echo "  chronyc sources -v"
echo "  systemctl status vm-time-sync.service chrony"
echo
echo "If you ever see large drift again, you can manually run:"
echo "  sudo $HELPER"
echo