# Personal APT repository from GitHub releases

Every 6 hours a GitHub Action downloads the latest `.deb` files of the programs
listed in `packages.txt`, builds a signed APT repository and publishes it on
GitHub Pages. Every machine then gets the updates through Update Manager.

## Files

| File | Purpose |
|---|---|
| `packages.txt` | The list of programs (usually the only thing you edit) |
| `scripts/build-repo.sh` | Downloads, builds the indexes, signs |
| `.github/workflows/update-repo.yml` | The scheduled workflow |
| `setup-client.sh` | Adds the repository to each machine |

## Setup (one time)

### 1. GPG key

On your own PC, create a **dedicated** key used only for this repository:

```bash
gpg --batch --passphrase '' --quick-gen-key "My APT Repo <apt@localhost>" rsa4096 sign never
gpg --armor --export-secret-keys "My APT Repo" > private.key
```

### 2. GitHub repository

1. Create a new **public** repository (e.g. `my-apt-repo`) and upload these files.
2. **Settings → Secrets and variables → Actions → New repository secret**:
   name `GPG_PRIVATE_KEY`, value the entire contents of `private.key`.
3. **Settings → Pages → Build and deployment → Source: GitHub Actions**.
4. Delete `private.key` from your PC (`shred -u private.key`) or keep it
   offline. Without it you cannot set up the secret again.
5. **Actions → Update APT repo → Run workflow** for the first run.

The repository will be available at `https://USERNAME.github.io/my-apt-repo`.

### 3. On each machine

```bash
sudo bash setup-client.sh https://USERNAME.github.io/my-apt-repo
sudo apt install photocraft wordcraft vectorcraft deckcraft filmcraft
```

From then on, new versions show up in Update Manager.

## Adding a program

Open the project's **Releases** page, check the name of the `.deb` file and
add a line to `packages.txt`:

```
owner/repo    name_*_amd64.deb
```

The pattern must match **exactly one** file. As soon as you commit, the
workflow runs.

## How it behaves

- If **any** download fails, the workflow fails and publishes nothing. The
  previous version of the repository stays online, so no package is ever lost.
  GitHub emails you about the failure.
- The repository keeps only the latest version of each program.
- Packages with architecture `all` appear under every architecture.

## Caveats

- **Trust:** packages are installed as root. Only list projects you trust,
  and keep the secret safe.
- **60 days of inactivity:** GitHub disables scheduled workflows in public
  repositories with no activity for 60 days. It will email you; one click on
  **Enable workflow** or any commit brings it back.
- **Size:** GitHub Pages sites are limited to 1 GB. That is plenty for a
  handful of tools.
- **Package names:** if a program also exists in the official Mint
  repositories under the same name, apt picks the higher version.
