# 🚀 SujitKumarBharti Universal Linux Repository

[![Linux](https://img.shields.io/badge/Linux-Ubuntu%20%7C%20Kali%20%7C%20Debian%20%7C%20Fedora%20%7C%20Arch-black?logo=linux&style=for-the-badge)](https://github.com/SujitKumarBharti/repo)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![Repo](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)](https://sujitkumarbharti.github.io/repo)

A native package repository for Linux distributions. Supports **Debian**, **Ubuntu**, **Kali Linux**, **Fedora**, and **Arch Linux** using your system's native package manager (`apt`, `dnf`, `pacman`).

---

## ⚡ Quick Setup (Add Repository)

To add this repository to your Linux system, run this one-line command:

```bash
curl -fsSL https://sujitkumarbharti.github.io/repo/install.sh | sudo bash
```

This automatically detects your distribution and configures your system's package manager:
- **Debian / Ubuntu / Kali Linux**: Configures APT (`/etc/apt/sources.list.d/skb-repo.list`).
- **Fedora / RHEL / CentOS**: Configures DNF/YUM (`/etc/yum.repos.d/skb-repo.repo`).
- **Arch Linux / Manjaro**: Configures Pacman (`/etc/pacman.conf`).

---

## 🗑️ Remove / Uninstall Repository

To completely remove this repository and its verification keys from your system:

```bash
curl -fsSL https://sujitkumarbharti.github.io/repo/uninstall.sh | sudo bash
```

This automatically detects your distribution, cleans up all configurations, and refreshes your package manager:
- **Debian / Ubuntu / Kali Linux**: Removes `/etc/apt/sources.list.d/skb-repo.list`, `/etc/apt/keyrings/skb-repo.gpg`, and refreshes APT cache.
- **Fedora / RHEL / CentOS**: Removes `/etc/yum.repos.d/skb-repo.repo` and clears DNF/YUM cache.
- **Arch Linux / Manjaro**: Removes `[skb-repo]` entry from `/etc/pacman.conf` and resyncs databases.

---

## 💻 Installing Packages (Native Commands)

Once added, simply use your system's default package manager:

### On Debian / Ubuntu / Kali Linux / Linux Mint:
```bash
sudo apt update
sudo apt search omengaminghub
sudo apt install omengaminghub
```

### On Fedora / RHEL / CentOS:
```bash
sudo dnf search <package>
sudo dnf install <package>
```

### On Arch Linux / Manjaro:
```bash
sudo pacman -Ss <package>
sudo pacman -S <package>
```

---

## 📦 Maintainer Guide (How to Upload & Roll Out Packages)

### 1. Interactive Upload Wizard
To upload a package and roll out updates, run:

```bash
./upload.sh -u
```
*(or simply `./upload.sh`)*

1. **📁 File location**: Path to the package (e.g. `~/Downloads/package.deb`).
2. **📦 Package name**: Unique package identifier (e.g. `omengaminghub`).
3. **🔖 Version**: Version number (e.g. `0.1.1`).
4. **🐧 Target OS**: Choose target system:
   - `1) Ubuntu / Kali / Debian / Mint (.deb)`
   - `2) Fedora / RHEL / CentOS (.rpm)`
   - `3) Arch Linux / Manjaro (.pkg.tar.zst)`
   - `4) Universal / Other`
5. **📝 Description**: Short description of the package.

#### 🔄 Automatic Rollouts:
If a package with the same name already exists in that category:
- `upload.sh` detects the existing version.
- Prompts for confirmation to roll out the update.
- Deletes the obsolete file from disk.
- Places the new package file, regenerates the native repository indexes (`Packages`, `Packages.gz`, `Release`), and updates `database/registry.json`.

---

### 2. Interactive Delete Manager (`delete.sh`)
To safely remove a package from the repository:

```bash
./delete.sh
```

- Shows a clean numbered list of all packages in the repository.
- Type the number (e.g. `1`) or the package name to delete.
- Asks for confirmation before deleting.
- Automatically cleans up the physical file, updates `registry.json`, and regenerates the repository indexes (`Packages`, `Packages.gz`, `Release`).

Or delete directly via command:
```bash
./delete.sh omengaminghub
```

---

### 3. Free Up Local Disk Space (`clean_local.sh`)
To keep your local PC disk clean while keeping all packages safely hosted on GitHub:

```bash
./clean_local.sh
```

- Cleans heavy package binaries (`.deb`, `.rpm`, `.pkg.tar.zst`) from your local disk using Git Sparse-Checkout.
- Saves 100% of your disk space (packages remain hosted on GitHub for end-users).
- Future git commits will **NEVER** accidentally delete packages from GitHub.
- Check local disk vs GitHub repository status anytime:
  ```bash
  ./clean_local.sh -s
  ```

---

### 4. Fresh Setup on a New PC (Lightweight Clone)
When cloning the repository on a new machine or after a clean PC reset, you do **not** need to download gigabytes of past packages:

```bash
git clone --filter=blob:none https://github.com/SujitKumarBharti/repo.git
cd repo
./clean_local.sh
```
This clones only the scripts, metadata, and database registry in seconds without downloading heavy package binaries!

---

### 5. Publishing Changes to GitHub

After uploading, updating, or deleting any package, push the repository live:

```bash
git add database/
git commit -m "update repository packages"
git push
```

---

## 📂 Directory Structure

```
repo/
├── database/
│   ├── debian/          # Debian, Ubuntu, Kali (.deb + Packages.gz + Release)
│   ├── fedora/          # Fedora, RHEL, CentOS (.rpm)
│   ├── arch/            # Arch, Manjaro (.pkg.tar.zst)
│   ├── universal/       # Standalone binaries / scripts
│   └── registry.json    # Central repository metadata & package database
├── clean_local.sh       # Free local disk space using sparse-checkout
├── install.sh           # One-line curl installer for systems
├── uninstall.sh         # One-line curl uninstaller / cleaner
├── upload.sh            # Maintainer package upload & rollout manager
├── delete.sh            # Maintainer interactive package deletion manager
└── README.md            # Repository documentation
```
