# 🚀 SujitKumarBharti Universal Linux Repository

[![Linux](https://img.shields.io/badge/Linux-Ubuntu%20%7C%20Kali%20%7C%20Debian%20%7C%20Fedora%20%7C%20Arch-black?logo=linux&style=for-the-badge)](https://github.com/SujitKumarBharti/repo)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![Repo](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)](https://sujitkumarbharti.github.io/repo)

A modern, universal package repository for Linux distributions. Supports **Debian**, **Ubuntu**, **Kali Linux**, **Fedora**, **Arch Linux**, and **Universal** standalone binaries and AppImages.

---

## ⚡ Quick Install (For Clients & Users)

To add this repository to any Linux machine, simply run:

```bash
curl -fsSL https://sujitkumarbharti.github.io/repo/install.sh | sudo bash
```

> **Note:** If GitHub Pages is still building or propagating, you can also use:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/SujitKumarBharti/repo/main/install.sh | sudo bash
> ```

---

## 🛠️ User Commands (`urepo` / `repo`)

Once installed, users can search and install packages using either `urepo` or `repo`:

| Command | Description |
| :--- | :--- |
| `urepo search <term>` | Search packages by keyword or application name |
| `sudo urepo install <name>` | Download and install package with automatic OS detection |
| `urepo list` | List all available packages compatible with your Linux distro |
| `urepo info <name>` | View package details, version, file, and SHA-256 checksum |
| `sudo urepo remove <name>` | Cleanly uninstall a package |
| `urepo update` | Fetch latest repository database catalog |

### Example:
```bash
# Search for HP Omen Gaming Hub
urepo search omen

# Install package
sudo urepo install omen-gaming-hub
```

---

## 📦 Maintainer Guide (How to Upload & Roll Out Updates)

### 1. Interactive Upload Wizard
Whenever you have a new package file, simply run:

```bash
./upload.sh -u
```
*(or just `./upload.sh`)*

The wizard will guide you step-by-step:
1. **📁 File location**: Enter the path to your package file (e.g. `~/Downloads/omen.deb` or `./app.AppImage`).
2. **📦 Package name**: Enter the unique package identifier (e.g. `omen-gaming-hub`).
3. **🔖 Version**: Enter the version number (e.g. `1.0.0` or `2.1.0`).
4. **🐧 Target OS**: Choose the Linux type:
   - `1) Ubuntu / Kali / Debian / Mint (.deb)`
   - `2) Fedora / RHEL / CentOS (.rpm)`
   - `3) Arch Linux / Manjaro (.pkg.tar.zst)`
   - `4) Universal (AppImage / Standalone Binary / Script - works on ALL distros)`
5. **📝 Description**: Enter a short description.

#### 🔄 Automatic Update Rollouts:
If a package with the same name already exists in that category, `upload.sh` automatically:
- Detects the previous version.
- Prompts you to confirm the update rollout.
- Deletes the obsolete file from disk.
- Copies the new version file, computes the new SHA-256 integrity checksum, and updates `database/registry.json`.

---

### 2. Quick Management Flags

| Command | Action |
| :--- | :--- |
| `./upload.sh -u` | Launch interactive upload wizard |
| `./upload.sh -l` | List all packages currently registered |
| `./upload.sh -s <query>` | Search packages in database |
| `./upload.sh --delete <name>` | Delete a package and remove its file from disk |
| `./upload.sh -f <file> -n <name> -v <ver> -o <os> -d <desc>` | Automated non-interactive upload |
| `./upload.sh -h` | Display full help screen |

---

### 3. Publishing to GitHub

Whenever you upload or update a package, publish it live to GitHub with:

```bash
git add .
git commit -m "feat: rolled out <package-name> v<version>"
git push
```

---

## 🌐 Enabling GitHub Pages (Important One-Time Step)

To enable `https://sujitkumarbharti.github.io/repo/install.sh`:

1. Open your repository in browser: [https://github.com/SujitKumarBharti/repo](https://github.com/SujitKumarBharti/repo)
2. Click on **⚙️ Settings** tab (top right).
3. In the left navigation menu, click **Pages**.
4. Under **Build and deployment**:
   - **Source**: Select `Deploy from a branch`
   - **Branch**: Select `main` and folder `/ (root)`
5. Click **Save**.
6. Wait 1-2 minutes. Your repository site will be live at `https://sujitkumarbharti.github.io/repo/`!

---

## 📂 Directory Structure

```
repo/
├── database/
│   ├── debian/          # Ubuntu, Kali, Debian, Mint (.deb)
│   ├── fedora/          # Fedora, RHEL, CentOS (.rpm)
│   ├── arch/            # Arch, Manjaro (.pkg.tar.zst)
│   ├── universal/       # AppImages, standalone binaries, scripts
│   └── registry.json    # Universal metadata database index
├── bin/
│   └── urepo            # Client package manager CLI
├── install.sh           # Client one-line curl installer
├── upload.sh            # Maintainer package upload & rollout tool
├── test_package.sh      # Sample package generator for testing
└── README.md            # Repository documentation
```
