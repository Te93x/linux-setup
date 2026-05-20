#!/bin/bash
# Simple ZSH Setup Script for Ubuntu/Debian (apt only)
set -e # Exit on error

echo "🚀 Starting simple ZSH setup..."

# Update package list
echo "📦 Updating packages..."
sudo apt-get update

# Install zsh and git
echo "📥 Installing zsh and git..."
sudo apt-get install -y zsh git

# Change default shell to zsh
echo "🔄 Changing default shell to ZSH..."
chsh -s "$(which zsh)" "$USER"

# Install zsh-autosuggestions
echo "📥 Installing zsh-autosuggestions..."
mkdir -p ~/.zsh/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions 2>/dev/null || echo "⚠️ Already installed or clone failed."

# Create improved .zshrc
echo "✍️ Creating .zshrc with PATH fix and sudoh alias..."
cat > ~/.zshrc << 'EOF'
# ====================== PATH ======================
# Add user-local binaries (important for hermes, pipx, cargo, etc.)
export PATH="$HOME/.local/bin:$PATH"

# ====================== Prompt ======================
PROMPT='%n@%m %1~ %# '

# ====================== Plugins ======================
# Load zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# ====================== Aliases ======================
alias ll='ls -lah --color=auto'
alias update='sudo apt-get update && sudo apt-get upgrade -y'

# Special alias for commands installed in ~/.local/bin (like hermes)
# Usage: sudoh hermes gateway setup
alias sudoh='sudo env "PATH=$PATH"'

# Check running systemd services
alias rs='systemctl list-units --type=service --state=running'

# ====================== Options ======================
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY

echo "✅ ZSH loaded successfully!"
EOF

echo ""
echo "🎉 Setup completed!"
echo ""
echo "✅ zsh and git installed"
echo "✅ Default shell changed to zsh"
echo "✅ zsh-autosuggestions installed"
echo "✅ ~/.local/bin added to PATH"
echo "✅ 'sudoh' alias created for sudo + user PATH"
echo ""
echo "Please restart your terminal or run this command now:"
echo " exec zsh"
echo ""
echo "After that you can use:"
echo "   hermes gateway setup          → normal use"
echo "   sudoh hermes gateway install --system   → when you need sudo"
