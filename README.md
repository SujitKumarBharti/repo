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

#### 🌐 Handling Large Packages (> 100 MB via Multi-Provider Remote Hosting)
GitHub has a strict limit of 100 MB per file in Git. If you upload a package exceeding 100 MB (e.g. Burp Suite Pro, Android Studio, large IDEs, heavy applications):
- `upload.sh` automatically detects the size and creates a lightweight (~9 KB) cryptographic payload-fetcher wrapper package.
- The actual binary payload is fetched on-the-fly during installation from any supported public cloud storage or web server.
- Built-in **Multi-Mirror Failover**: You can provide multiple URLs (comma-separated). If the primary host is unreachable, the installer automatically tries the next mirror!

##### 🚀 Supported Remote Storage Providers & URL Syntax:

| Provider | Supported URL Format | Features & Highlights |
| :--- | :--- | :--- |
| **Google Drive** | `https://drive.google.com/file/d/<ID>/view` | Auto-resolves direct stream and automatically bypasses the Google virus scan warning for large files (>100MB). |
| **Mega.nz** | `https://mega.nz/file/<ID>#<KEY>` | Direct API streaming with on-the-fly AES-128-CTR decryption using standard OpenSSL / Python crypto. |
| **Direct Web Server** | `https://jharkhand.duckdns.org/repo/app.deb` | Direct Apache / Nginx / Caddy / Lighttpd web server hosting. |
| **IP-Based Host** | `http://192.168.1.100:8080/repo/app.deb` or `http://1.2.3.4/...` | Direct LAN IP, VPS, or home lab server with custom ports. |
| **GitHub Releases** | `https://github.com/<user>/<repo>/releases/download/<tag>/app.deb` | Free high-speed global CDN with support up to 2 GB per asset file! |
| **TeraBox & Mirrors** | `https://terabox.com/s/<surl>` or `https://1024tera.com/s/...` | Auto-resolves direct download streams across multiple public Terabox gateways. |
| **Dropbox** | `https://www.dropbox.com/s/<ID>/app.deb` | Auto-converts share links into direct download stream (`dl=1`). |
| **OneDrive** | `https://1drv.ms/...` or `https://onedrive.live.com/...` | Auto-resolves direct binary download stream. |
| **MediaFire** | `https://www.mediafire.com/file/...` | Automatically extracts direct CDN download link from page. |
| **PixelDrain** | `https://pixeldrain.com/u/<ID>` | Auto-converts to direct API stream (`api/file/<ID>`). |
| **GitLab / HuggingFace** | `https://gitlab.com/...` / `https://huggingface.co/.../resolve/...` | Direct CDN streaming. |
| **Archive.org / SourceForge** | `https://archive.org/download/...` | Direct mirror download. |
| **Multi-Mirror Failover** | `<url1>, <url2>, <url3>` | Comma-separated list for automatic redundancy and failover. |

##### 💡 Maintainer Examples for Remote Packages:

```bash
# Example 1: Upload with Google Drive link
./upload.sh -f ./burpsuite-pro.deb -n burpsuite-pro -v 2026.4.0 -o debian \
  -m "https://drive.google.com/file/d/1d1erCEzsCfidqVH1Zhcyn5KHLUiOSNvn/view?usp=drive_link"

# Example 2: Upload with Mega.nz encrypted link
./upload.sh -f ./burpsuite-pro.deb -n burpsuite-pro -v 2026.4.0 -o debian \
  -m "https://mega.nz/file/O1ABmDYS#FzdqQEUJZ3AeZugHA2D0AS9Jn1luYCy_9IZlJQE4M8U"

# Example 3: Upload with DuckDNS / Apache server link
./upload.sh -f ./burpsuite-pro.deb -n burpsuite-pro -v 2026.4.0 -o debian \
  -m "https://jharkhand.duckdns.org/repo/burpsuite-pro_2026.3.3-1_amd64.deb"

# Example 4: Upload with Local or Public IP server
./upload.sh -f ./burpsuite-pro.deb -n burpsuite-pro -v 2026.4.0 -o debian \
  -m "http://192.168.1.100:8080/repo/burpsuite-pro.deb"

# Example 5: High-Availability Multi-Mirror Failover (Drive + Mega + DuckDNS)
./upload.sh -f ./burpsuite-pro.deb -n burpsuite-pro -v 2026.4.0 -o debian \
  -m "https://drive.google.com/file/d/1d1erCEzsCfidqVH1Zhcyn5KHLUiOSNvn/view?usp=drive_link, https://mega.nz/file/O1ABmDYS#FzdqQEUJZ3AeZugHA2D0AS9Jn1luYCy_9IZlJQE4M8U, https://jharkhand.duckdns.org/repo/burpsuite-pro_2026.3.3-1_amd64.deb"

# Example 6: Direct remote upload without having local file (fetches & indexes directly)
./upload.sh -f "https://mega.nz/file/O1ABmDYS#FzdqQEUJZ3AeZugHA2D0AS9Jn1luYCy_9IZlJQE4M8U" -n burpsuite-pro -v 2026.4.0 -o debian
```

##### 💻 How the End-User Installs:
The end-user simply installs using standard APT:
```bash
sudo apt update
sudo apt install burpsuite-pro
```
During installation:
1. APT installs the verified lightweight wrapper.
2. The bundled multi-provider downloader streams the payload from the remote host with a real-time progress bar and speed display.
3. Cryptographic SHA256 integrity is strictly verified.
4. Files are extracted and registered with `dpkg`.
5. Desktop icons, launchers, and configs are created automatically!

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
├── scripts/
│   └── downloader.py    # Multi-provider payload fetcher (Mega, GDrive, IP, TeraBox, etc.)
├── install.sh           # One-line curl installer for systems
├── uninstall.sh         # One-line curl uninstaller / cleaner
├── upload.sh            # Maintainer package upload & rollout manager
├── delete.sh            # Maintainer deletion & local disk cleaner (delete.sh -c)
└── README.md            # Repository documentation
```
