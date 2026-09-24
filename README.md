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

## 📦 Maintainer Guide (Step-by-Step with `omengaminghub` Example)

Suppose you have built or downloaded a package on your machine, for example:
```bash
~/Downloads/omengaminghub_0.1.1_amd64.deb
```

---

### 1️⃣ How to Upload or Roll Out an Update (`upload.sh`)

#### Option A: Interactive Wizard (Recommended)
Run the upload wizard from the repository root:
```bash
./upload.sh
```
Follow the 5 simple prompts:
1. **📁 File location**: `~/Downloads/omengaminghub_0.1.1_amd64.deb`
2. **📦 Package name**: `omengaminghub`
3. **🔖 Version**: `0.1.1` *(or `0.1.2` when rolling out a new update)*
4. **🐧 Target OS**: Choose `1) Ubuntu / Kali / Debian / Mint (.deb)`
5. **📝 Description**: `HP Omen Gaming Hub for Linux`

#### 🔄 Automatic Rollouts (Updating an Existing Package):
If `omengaminghub` already exists in the repository:
- `upload.sh` automatically detects the previous version (e.g. `0.1.1`).
- Prompts for confirmation to roll out the update (e.g. `0.1.2`).
- Safely replaces the old file, recalculates checksums, updates `database/registry.json`, and rebuilds APT indexes (`Packages`, `Packages.gz`, `Release`, GPG signatures).

#### Option B: Direct One-Line Command (CLI Flags)
```bash
./upload.sh -f ~/Downloads/omengaminghub_0.1.1_amd64.deb -n omengaminghub -v 0.1.1 -o debian -d "HP Omen Gaming Hub for Linux"
```

#### 🚀 Fully Automated Rollout & Local Disk Cleanup:
At the end of upload, `upload.sh` automatically:
1. Recalculates cryptographic hashes and updates `database/registry.json`.
2. Re-generates APT repository indexes (`Packages`, `Packages.gz`, `Release`, GPG signatures).
3. Automatically runs `git add --sparse database/` and commits with a descriptive message.
4. Automatically runs `git push` to publish the package live on GitHub.
5. Automatically runs local sparse-checkout cleanup so your PC stays at **0 MB disk usage**!
*(Zero manual git commands required!)*

---

### 2️⃣ How to Free Up Local PC Disk Space (`delete.sh -c`)

If you have uploaded packages and want to keep your local PC disk completely clean (0 MB used by packages), run:

```bash
./delete.sh -c
```
*(Or launch `./delete.sh` and type `c`)*

#### 💡 How it works & why it is safe:
- Uses **Git Sparse-Checkout** to remove the physical `.deb` / `.rpm` binaries from your local PC.
- **Your local PC saves 100% of the disk space.**
- The packages remain **100% safe and hosted on GitHub** for all Linux users to install.
- Future git commits will **NEVER** accidentally delete packages from GitHub!
- Check local storage vs online package status anytime:
  ```bash
  ./delete.sh -s
  ```

---

### 3️⃣ How to Permanently Delete a Package from GitHub (`delete.sh`)

When you want to **permanently remove a hosted software from GitHub and the repository**:

#### Option A: Interactive Delete Menu
Run:
```bash
./delete.sh
```
You will see the list of all hosted packages:
```text
  [#]   NAME                    VERSION    DISTRO       FILENAME
  ----------------------------------------------------------------------------------
  [1]   omengaminghub           0.1.1      debian       omengaminghub_0.1.1.deb
```
1. Type `1` (or package name) and press **Enter**.
2. Confirm deletion (`y`).
3. That's it! `delete.sh` automatically removes the package, updates indexes, stages changes, commits, and pushes directly to GitHub!

#### Option B: Direct Command
```bash
./delete.sh omengaminghub -y
```
*(Automatically removes, commits, and pushes to GitHub with 0 manual steps).*

---

### 4️⃣ How to Fresh Setup on a New PC (Lightweight Clone)

If your PC crashes or you clone this repository on a new computer, you do **not** need to download gigabytes of heavy packages:

```bash
# 1. Clone without downloading heavy binaries:
git clone --filter=blob:none https://github.com/SujitKumarBharti/repo.git

# 2. Enter repository and set clean local workspace:
cd repo
./delete.sh -c
```
- Clones in 2 seconds (< 1 MB).
- Downloads only scripts, documentation, and the `registry.json` database.
- You can immediately start uploading or managing packages fresh!

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
├── install.sh           # One-line curl installer for systems
├── uninstall.sh         # One-line curl uninstaller / cleaner
├── upload.sh            # Maintainer package upload & rollout manager
├── delete.sh            # Maintainer deletion & local disk cleaner (delete.sh -c)
└── README.md            # Repository documentation
```
