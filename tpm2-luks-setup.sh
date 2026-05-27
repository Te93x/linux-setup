#!/bin/bash
# =============================================================================
# TPM2 LUKS Auto-Unlock Setup Script
# For your system: /dev/vda3
# =============================================================================

set -euo pipefail

echo "=== TPM2 LUKS Auto-Unlock Setup Script Latest ==="
echo "This will bind /dev/vda3 to TPM2 for automatic unlocking."
echo "You will be prompted for your current LUKS passphrase."
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run with sudo"
   echo "   Example: curl -sSL https://... | sudo bash"
   exit 1
fi

# Check TPM device
if [[ ! -e /dev/tpm0 && ! -e /dev/tpmrm0 ]]; then
    echo "❌ TPM device not found. Ensure TPM 2.0 is enabled in BIOS."
    exit 1
fi
echo "✅ TPM detected."

# Check LUKS partition
if [[ ! -b /dev/vda3 ]]; then
    echo "❌ /dev/vda3 not found!"
    exit 1
fi

if ! cryptsetup isLuks /dev/vda3 2>/dev/null; then
    echo "❌ /dev/vda3 is not a LUKS device!"
    exit 1
fi
echo "✅ /dev/vda3 is valid LUKS partition."

# Install required packages (without dracut)
echo
echo "Installing required packages..."
apt update
apt install -y \
    clevis \
    clevis-tpm2 \
    clevis-luks \
    clevis-initramfs \
    tpm2-tools \
    initramfs-tools


echo "Enter your current LUKS passphrase:"
read -s -r passphrase

if clevis luks list -d /dev/vda3 | grep -q tpm2; then
    echo "⚠️ TPM2 binding already exists."
else
    echo -n "$passphrase" | clevis luks bind -d /dev/vda3 tpm2 '{"pcr_ids":"7"}' -
    echo "✅ Successfully bound to TPM2 (PCR 7)."
fi
unset passphrase

# # Bind to TPM2
# echo
# echo "Binding LUKS to TPM2..."
# if clevis luks list -d /dev/vda3 | grep -q tpm2; then
#     echo "⚠️  TPM2 binding already exists. Skipping bind."
# else
#     clevis luks bind -d /dev/vda3 tpm2 '{"pcr_ids":"7"}'
#     echo "✅ Successfully bound to TPM2 (PCR 7)."
# fi

# Update initramfs
echo
echo "Updating initramfs..."
update-initramfs -u -k all
echo "✅ initramfs updated."

echo
echo "🎉 Setup completed successfully!"
echo
echo "Next step: Reboot and test"
echo "   sudo reboot"
echo
echo "Useful commands:"
echo "   sudo clevis luks list -d /dev/vda3"
