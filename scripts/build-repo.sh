#!/usr/bin/env bash
# Downloads the latest release of every program in packages.txt
# and builds a signed APT repository in the $SITE directory.
set -euo pipefail

: "${GPG_KEY_ID:?GPG_KEY_ID is not set}"
SITE="${SITE:-public}"
CODENAME="${CODENAME:-stable}"
ARCHS="${ARCHS:-amd64 arm64}"
ORIGIN="${ORIGIN:-MyAptRepo}"

rm -rf "$SITE"
mkdir -p "$SITE/pool/main"

# 1. Download
failed=()
while read -r repo pattern _; do
  [[ -z "${repo:-}" || "$repo" == \#* ]] && continue
  dest="$SITE/pool/main/${repo//\//_}"
  mkdir -p "$dest"
  echo "==> $repo  ($pattern)"
  if ! gh release download --repo "$repo" --pattern "$pattern" --dir "$dest" --clobber; then
    echo "::error::Download failed: $repo ($pattern)"
    failed+=("$repo")
  fi
done < packages.txt

# If any download fails, stop here: the previous version of the site stays
# online and no package is lost.
if ((${#failed[@]})); then
  echo "Failed: ${failed[*]}"
  exit 1
fi

# Make sure every file is a valid .deb and rename it to the standard Debian
# name (package_version_arch.deb). apt-ftparchive --arch selects packages by
# that file name, so upstream names like "app-1.0-linux-x86_64.deb" would
# otherwise be left out of the index.
find "$SITE/pool" -name '*.deb' -print0 | while IFS= read -r -d '' f; do
  pkg=$(dpkg-deb --field "$f" Package)
  ver=$(dpkg-deb --field "$f" Version)
  arch=$(dpkg-deb --field "$f" Architecture)
  target="$(dirname "$f")/${pkg}_${ver#*:}_${arch}.deb"
  [[ "$f" == "$target" ]] || mv -f "$f" "$target"
  echo "$pkg $ver $arch"
done

# 2. Indexes
cd "$SITE"
for arch in $ARCHS; do
  d="dists/$CODENAME/main/binary-$arch"
  mkdir -p "$d"
  apt-ftparchive --arch "$arch" packages pool > "$d/Packages"
  gzip -9kf "$d/Packages"
done

apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="$ORIGIN" \
  -o APT::FTPArchive::Release::Label="$ORIGIN" \
  -o APT::FTPArchive::Release::Suite="$CODENAME" \
  -o APT::FTPArchive::Release::Codename="$CODENAME" \
  -o APT::FTPArchive::Release::Architectures="$ARCHS" \
  -o APT::FTPArchive::Release::Components="main" \
  release "dists/$CODENAME" > /tmp/Release
mv /tmp/Release "dists/$CODENAME/Release"

# 3. Signing
gpg --batch --yes --local-user "$GPG_KEY_ID" --clearsign \
    -o "dists/$CODENAME/InRelease" "dists/$CODENAME/Release"
gpg --batch --yes --local-user "$GPG_KEY_ID" --armor --detach-sign \
    -o "dists/$CODENAME/Release.gpg" "dists/$CODENAME/Release"

# 4. Public key for the clients
gpg --export "$GPG_KEY_ID" > myrepo.gpg
gpg --armor --export "$GPG_KEY_ID" > myrepo.asc

echo "Done: $(find pool -name '*.deb' | wc -l) packages"
