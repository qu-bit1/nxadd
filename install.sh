#!/usr/bin/env bash
# Installs nxadd into ~/.local/bin (or the folder given as the first argument).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dest="${1:-$HOME/.local/bin}"

mkdir -p "$dest"
cp "$here/nxadd" "$dest/nxadd"
chmod +x "$dest/nxadd"
echo "Installed nxadd $("$dest/nxadd" --version | awk '{print $2}') to $dest/nxadd"

case ":$PATH:" in
  *":$dest:"*) echo "Run it with: nxadd" ;;
  *) echo "$dest is not on your PATH. Add this line to ~/.zshrc, then open a new Terminal window:"
     echo "  export PATH=\"$dest:\$PATH\"" ;;
esac
command -v 7z > /dev/null || echo "Optional: brew install p7zip, to let nxadd unpack .7z, .zip and .rar downloads."
