#!/usr/bin/env bash
# Adds the personal APT repository to a Linux Mint / Ubuntu / Debian machine.
# Usage:  sudo bash setup-client.sh https://USERNAME.github.io/REPO
set -euo pipefail

URL="${1:?Give the repository URL, e.g. https://USERNAME.github.io/my-apt-repo}"
URL="${URL%/}"
NAME="myrepo"

install -d -m 0755 /etc/apt/keyrings
curl -fsSL "$URL/myrepo.gpg" -o "/etc/apt/keyrings/$NAME.gpg"
chmod 644 "/etc/apt/keyrings/$NAME.gpg"

cat > "/etc/apt/sources.list.d/$NAME.sources" <<EOF
Types: deb
URIs: $URL
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/$NAME.gpg
EOF

apt-get update
echo
echo "Done. Install packages with:  sudo apt install <package>"
echo "Updates will appear in Update Manager along with everything else."
