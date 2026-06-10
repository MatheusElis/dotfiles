#!/usr/bin/env bash
# Bootstrap script for Fedora/RHEL-based systems
# Usage: curl -fsSL <url> | bash  OR  bash bootstrap-fedora.sh
set -euo pipefail

echo "╔══════════════════════════════════════════╗"
echo "║   comuvim bootstrap — Fedora/RHEL        ║"
echo "╚══════════════════════════════════════════╝"

# --- 1. System dependencies ---
echo ""
echo "📦 Installing system dependencies..."
sudo dnf install -y \
  git \
  curl \
  wget \
  unzip \
  zip \
  tar \
  gcc \
  gcc-c++ \
  make \
  ripgrep \
  fd-find \
  fzf \
  tmux \
  stow \
  xclip \
  wl-clipboard \
  python3-devel

# --- 2. Install mise ---
echo ""
echo "🔧 Installing mise..."
if ! command -v mise &>/dev/null; then
  curl https://mise.run | sh
  echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
  export PATH="$HOME/.local/bin:$PATH"
  eval "$(~/.local/bin/mise activate bash)"
else
  echo "  mise already installed: $(mise --version)"
fi

# --- 3. Configure mise global tools ---
echo ""
echo "⚙️  Configuring mise tools..."
mkdir -p ~/.config/mise

cat > ~/.config/mise/config.toml << 'EOF'
[tools]
python = "3.13"
node = "latest"
go = "latest"
java = "adoptopenjdk-21"
neovim = "latest"
zig = "latest"
EOF

# --- 4. Install all tools ---
echo ""
echo "📥 Installing tools via mise (Python, Node, Go, Java, Neovim, Zig)..."
mise install

# --- 5. Verify installations ---
echo ""
echo "✅ Verifying installations..."
echo "  Python:  $(mise exec -- python --version)"
echo "  Node:    $(mise exec -- node --version)"
echo "  Go:      $(mise exec -- go version)"
echo "  Java:    $(mise exec -- java --version 2>&1 | head -1)"
echo "  Neovim:  $(mise exec -- nvim --version | head -1)"
echo "  Zig:     $(mise exec -- zig version)"

# --- 6. Setup dotfiles (optional) ---
echo ""
DOTFILES_DIR="$HOME/.dotfiles"
if [ -d "$DOTFILES_DIR" ]; then
  echo "📂 Dotfiles found at $DOTFILES_DIR"
  echo "  Linking nvim config..."
  mkdir -p ~/.config
  ln -sfn "$DOTFILES_DIR/nvim/.config/nvim" ~/.config/nvim
else
  echo "⚠️  No dotfiles found at $DOTFILES_DIR"
  echo "  Clone your dotfiles and re-run, or manually link ~/.config/nvim"
fi

# --- 7. Install Neovim plugins ---
echo ""
echo "🔌 Installing Neovim plugins..."
mise exec -- nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

# --- 8. Install Mason tools (LSPs, formatters) ---
echo ""
echo "🛠️  Installing Mason tools..."
mise exec -- nvim --headless "+MasonToolsInstallSync" +qa 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ✅ Bootstrap complete!                  ║"
echo "║   Restart your terminal or run:           ║"
echo "║   source ~/.bashrc                        ║"
echo "╚══════════════════════════════════════════╝"
