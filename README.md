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

### 2. Publishing Changes to GitHub

After uploading or updating any package, push the repository live:

```bash
git add .
git commit -m "feat: rolled out <package-name> v<version>"
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
│   └── registry.json    # Central repository metadata
├── install.sh           # One-line curl installer for systems
├── upload.sh            # Maintainer package upload & rollout manager
└── README.md            # Repository documentation
```
