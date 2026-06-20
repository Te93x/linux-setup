# Linux Setup Scripts

One-command setup for ZSH on Ubuntu/Debian.

## Quick Install

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Te93x/linux-setup/refs/heads/main/zsh-setup.sh)
```

## Install Docker
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Te93x/linux-setup/refs/heads/main/docker-setup.sh)
```

## Install Camofox Browser
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Te93x/linux-setup/refs/heads/main/camofox-browser-setup.sh)
```

## Install TPM2 LUKS
```bash
curl -sSL https://raw.githubusercontent.com/Te93x/linux-setup/refs/heads/main/tpm2-luks-setup.sh -o /tmp/tpm2-luks-setup.sh && \
sudo bash /tmp/tpm2-luks-setup.sh && \
rm -f /tmp/tpm2-luks-setup.sh
```

## Install Github Runner Dependencies
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Te93x/linux-setup/refs/heads/main/github-runner-setup.sh)
```

## Fix Github Runner Time Sync
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Te93x/linux-setup/refs/heads/main/fix-time-sync.sh)
```

## Boot Time Sync
```bash
curl -fsSL https://raw.githubusercontent.com/Te93x/linux-setup/main/vm-chrony-boot-sync.sh -o vm-chrony-boot-sync.sh
chmod +x vm-chrony-boot-sync.sh
sudo ./vm-chrony-boot-sync.sh
rm ./vm-chrony-boot-sync.sh
```
