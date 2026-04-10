#!/bin/bash
# Simple ZSH Setup Script for Ubuntu/Debian (apt only)

set -e  # Exit on error

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
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions 2>/dev/null || echo "⚠️  Already installed or clone failed."

# Create simple .zshrc with your custom prompt
echo "✍️  Creating .zshrc with custom prompt..."
cat > ~/.zshrc << 'EOF'
# Simple ZSH Configuration

# Custom prompt: username@hostname current_dir #
PROMPT='%n@%m %1~ %# '

# Load zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# Basic options
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY

# Useful aliases
alias ll='ls -lah --color=auto'
alias update='sudo apt-get update && sudo apt-get upgrade -y'

echo "✅ ZSH loaded successfully!"
EOF

echo ""
echo "🎉 Setup completed!"
echo ""
echo "✅ zsh and git installed"
echo "✅ Default shell changed to zsh"
echo "✅ zsh-autosuggestions installed"
echo "✅ .zshrc updated with simple prompt"
echo ""
echo "Please restart your terminal or run this command now:"
echo "    exec zsh"
echo ""
echo "After that, start typing commands you've used before to see autosuggestions."
