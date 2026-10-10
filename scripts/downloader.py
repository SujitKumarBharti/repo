#!/usr/bin/env python3
# ==============================================================================
# Universal Linux Repository - Multi-Provider Remote Package Downloader
# Maintainer: SujitKumarBharti
# Repository: https://github.com/SujitKumarBharti/repo
#
# Supports:
#   • Google Drive (large files >100MB direct streaming confirmation, view/uc links)
#   • Mega.nz (API streaming + client-side AES-128-CTR decryption via openssl/python)
#   • Direct HTTP/HTTPS & IP hosts (Apache, Nginx, Caddy, DuckDNS, LAN/VPS IPs)
#   • TeraBox & mirrors (terabox.com, 1024tera.com, teraboxapp.com, etc.)
#   • GitHub Releases (free high-speed hosting up to 2GB per asset)
#   • Dropbox (auto dl=1 conversion)
#   • OneDrive (1drv.ms / onedrive.live.com direct download)
#   • MediaFire (HTML direct CDN scraper)
#   • PixelDrain (api/file conversion)
#   • GitLab & Hugging Face
#   • Archive.org & SourceForge
#   • Multi-Mirror Failover (comma or list separated URLs)
# ==============================================================================

import os
import sys
import re
import json
import time
import base64
import struct
import hashlib
import subprocess
import urllib.request
import urllib.parse
import http.cookiejar

USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

def format_size(bytes_val):
    val = float(bytes_val)
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if val < 1024.0:
            return f"{val:.2f} {unit}" if unit != 'B' else f"{int(val)} B"
        val /= 1024.0
    return f"{val:.2f} PB"

def identify_provider(url):
    u = url.strip().lower()
    if "mega.nz" in u or "mega.co.nz" in u:
        return "Mega Cloud Storage"
    elif "drive.google.com" in u or "docs.google.com" in u:
        return "Google Drive"
    elif any(d in u for d in ["terabox.com", "terabox.app", "1024tera.com", "teraboxapp.com", "freeterabox.com", "teraboxlink.com", "mirrobox.com", "nephobox.com"]):
        return "TeraBox"
    elif "dropbox.com" in u:
        return "Dropbox"
    elif "1drv.ms" in u or "onedrive.live.com" in u:
        return "OneDrive"
    elif "mediafire.com" in u:
        return "MediaFire"
    elif "pixeldrain.com" in u:
        return "PixelDrain"
    elif "github.com" in u and "/releases/download/" in u:
        return "GitHub Releases (High Speed CDN)"
    elif "gitlab.com" in u:
        return "GitLab"
    elif "huggingface.co" in u:
        return "Hugging Face"
    elif "archive.org" in u:
        return "Archive.org"
    elif "sourceforge.net" in u:
        return "SourceForge"
    elif re.search(r"https?://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}", u):
        return "Direct IP Host / Web Server"
    elif "duckdns.org" in u:
        return "DuckDNS Dynamic Web Server (Apache/Nginx)"
    else:
        return "Direct HTTP/HTTPS Web Server"

class UniversalDownloader:
    def __init__(self, raw_url, dest_path, expected_sha256=None):
        self.raw_url = raw_url.strip()
        self.dest_path = dest_path
        self.expected_sha256 = expected_sha256.lower().strip() if expected_sha256 else None
        self.cookie_jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.cookie_jar))
        self.provider = identify_provider(self.raw_url)

    def log(self, msg):
        print(f"[*] {msg}", flush=True)

    def progress_stream(self, response_stream, total_size, out_file, custom_filter=None):
        downloaded = 0
        start_time = time.time()
        last_print = 0
        buf_size = 64 * 1024

        while True:
            chunk = response_stream.read(buf_size)
            if not chunk:
                break
            if custom_filter:
                chunk = custom_filter(chunk)
            out_file.write(chunk)
            downloaded += len(chunk)
            now = time.time()
            if now - last_print >= 0.3:
                last_print = now
                elapsed = max(now - start_time, 0.001)
                speed = downloaded / elapsed
                speed_str = f"{format_size(speed)}/s"
                if total_size and total_size > 0:
                    pct = min((downloaded / total_size) * 100, 100.0)
                    bar_len = 28
                    filled = int(bar_len * downloaded / total_size)
                    bar = "=" * filled + ">" + " " * max(bar_len - filled - 1, 0)
                    rem_sec = int((total_size - downloaded) / max(speed, 1))
                    eta_str = f"ETA: {rem_sec//60:02d}:{rem_sec%60:02d}"
                    sys.stdout.write(f"\r  [{bar}] {pct:5.1f}% ({format_size(downloaded)}/{format_size(total_size)}) @ {speed_str} {eta_str}   ")
                else:
                    sys.stdout.write(f"\r  Downloading: {format_size(downloaded)} @ {speed_str}   ")
                sys.stdout.flush()
        sys.stdout.write("\n")
        sys.stdout.flush()
        return downloaded

    def download_direct(self, direct_url, headers=None):
        h = {"User-Agent": USER_AGENT}
        if headers:
            h.update(headers)
        req = urllib.request.Request(direct_url, headers=h)
        resp = self.opener.open(req, timeout=30)
        total_size = int(resp.headers.get("Content-Length", 0))
        with open(self.dest_path, "wb") as f:
            self.progress_stream(resp, total_size, f)

    def download_gdrive(self):
        self.log("Connecting to Google Drive repository storage...")
        m = re.search(r"[-_\w]{25,}", self.raw_url)
        if not m:
            raise ValueError("Could not extract Google Drive File ID from URL.")
        file_id = m.group(0)
        init_url = f"https://drive.google.com/uc?id={file_id}&export=download"
        req = urllib.request.Request(init_url, headers={"User-Agent": USER_AGENT})
        resp = self.opener.open(req, timeout=30)
        
        # Check if direct stream or confirmation form
        first_peek = resp.read(65536)
        content_type = resp.headers.get("Content-Type", "")
        if "text/html" not in content_type and (first_peek.startswith(b"!<arch>") or resp.status == 200 and not first_peek.startswith(b"<!DOCTYPE")):
            total_size = int(resp.headers.get("Content-Length", 0))
            with open(self.dest_path, "wb") as f:
                f.write(first_peek)
                self.progress_stream(resp, total_size, f)
            return

        # Handle confirmation form for large files
        html = first_peek.decode("utf-8", errors="ignore")
        action_m = re.search(r'<form[^>]*id=["\']download-form["\'][^>]*action=["\']([^"\']+)["\']', html) or re.search(r'action=["\'](https://drive\.usercontent\.google\.com/download[^"\']*)["\']', html)
        inputs = dict(re.findall(r'<input[^>]*name=["\']([^"\']+)["\'][^>]*value=["\']([^"\']*)["\']', html))
        
        if action_m:
            download_url = action_m.group(1)
            if inputs:
                download_url += "?" + urllib.parse.urlencode(inputs)
            self.log("Connected to storage server. Starting download...")
            req2 = urllib.request.Request(download_url, headers={"User-Agent": USER_AGENT})
            resp2 = self.opener.open(req2, timeout=30)
            total_size = int(resp2.headers.get("Content-Length", 0))
            with open(self.dest_path, "wb") as f:
                self.progress_stream(resp2, total_size, f)
        else:
            raise RuntimeError("Failed to resolve Google Drive download stream.")

    def download_mega(self):
        self.log("Connecting to Mega repository storage...")
        m = re.search(r"mega\.(?:nz|co\.nz)/(?:file/|#!)?([a-zA-Z0-9_-]+)[#!]([a-zA-Z0-9_-]+)", self.raw_url)
        if not m:
            raise ValueError("Invalid Mega URL format. Expected: https://mega.nz/file/<id>#<key>")
        file_id, file_key = m.group(1), m.group(2)

        data = file_key + '=' * ((4 - len(file_key) % 4) % 4)
        key_bytes = base64.urlsafe_b64decode(data)
        if len(key_bytes) % 4 != 0:
            key_bytes += b'\0' * (4 - len(key_bytes) % 4)
        k = [struct.unpack('>I', key_bytes[i:i+4])[0] for i in range(0, len(key_bytes), 4)]
        key_aes = b''.join(struct.pack('>I', x) for x in (k[0] ^ k[4], k[1] ^ k[5], k[2] ^ k[6], k[3] ^ k[7]))
        iv_aes = b''.join(struct.pack('>I', x) for x in (k[4], k[5], 0, 0))

        api_url = "https://g.api.mega.co.nz/cs"
        post_data = json.dumps([{"a": "g", "g": 1, "ssl": 2, "p": file_id}]).encode('utf-8')
        req = urllib.request.Request(api_url, data=post_data, headers={"Content-Type": "application/json", "User-Agent": USER_AGENT})
        resp = urllib.request.urlopen(req, timeout=20)
        res = json.loads(resp.read().decode('utf-8'))
        if not (isinstance(res, list) and res and "g" in res[0]):
            raise RuntimeError(f"Mega API error: {res}")
        
        dl_url = res[0]["g"]
        total_size = res[0].get("s", 0)
        self.log(f"Connected to storage server ({format_size(total_size)}). Starting download...")

        # Decrypt using openssl enc (built into all Linux distros)
        openssl_proc = subprocess.Popen(
            ["openssl", "enc", "-d", "-aes-128-ctr", "-K", key_aes.hex(), "-iv", iv_aes.hex()],
            stdin=subprocess.PIPE,
            stdout=open(self.dest_path, "wb"),
            stderr=subprocess.PIPE
        )

        stream_req = urllib.request.Request(dl_url, headers={"User-Agent": USER_AGENT})
        stream_resp = urllib.request.urlopen(stream_req, timeout=30)
        
        class PipeWriter:
            def __init__(self, proc_in): self.proc_in = proc_in
            def write(self, b): self.proc_in.write(b)
        
        self.progress_stream(stream_resp, total_size, PipeWriter(openssl_proc.stdin))
        openssl_proc.stdin.close()
        openssl_proc.wait()

    def download_terabox(self):
        self.log("Connecting to TeraBox repository storage...")
        # Extract shorturl / surl
        m = re.search(r"/s/1?([a-zA-Z0-9_-]+)", self.raw_url) or re.search(r"surl=1?([a-zA-Z0-9_-]+)", self.raw_url)
        surl = m.group(1) if m else ""
        
        # Try direct link resolver endpoints
        gateways = [
            f"https://api.teraboxfast.com/api/get-download?url={urllib.parse.quote(self.raw_url)}",
            f"https://terabox-dl.qtcloud.workers.dev/api/get-download?url={urllib.parse.quote(self.raw_url)}",
            f"https://yt-video.in/api/terabox?url={urllib.parse.quote(self.raw_url)}"
        ]
        
        resolved_link = None
        for gw in gateways:
            try:
                req = urllib.request.Request(gw, headers={"User-Agent": USER_AGENT})
                resp = self.opener.open(req, timeout=10)
                data = json.loads(resp.read().decode("utf-8", errors="ignore"))
                # Check known response formats
                link = data.get("download_link") or data.get("dlink") or data.get("url") or (data.get("list") and data["list"][0].get("dlink"))
                if link:
                    resolved_link = link
                    break
            except Exception:
                continue

        if resolved_link:
            self.log("Connected to storage server. Starting download...")
            self.download_direct(resolved_link)
        else:
            # Fallback: attempt direct HTTP stream in case URL is already direct or uses a proxy
            self.log("Connecting to repository server...")
            self.download_direct(self.raw_url)

    def download_dropbox(self):
        self.log("Connecting to Dropbox repository storage...")
        dl_url = re.sub(r"[?&]dl=0", "", self.raw_url)
        dl_url += ("&" if "?" in dl_url else "?") + "dl=1"
        self.download_direct(dl_url)

    def download_onedrive(self):
        self.log("Connecting to OneDrive repository storage...")
        dl_url = self.raw_url
        if "1drv.ms" in dl_url:
            req = urllib.request.Request(dl_url, headers={"User-Agent": USER_AGENT})
            resp = self.opener.open(req, timeout=15)
            dl_url = resp.geturl()
        if "download=1" not in dl_url:
            dl_url = dl_url.replace("redir?", "download?") + ("&download=1" if "?" in dl_url else "?download=1")
        self.download_direct(dl_url)

    def download_mediafire(self):
        self.log("Connecting to MediaFire repository storage...")
        req = urllib.request.Request(self.raw_url, headers={"User-Agent": USER_AGENT})
        html = self.opener.open(req, timeout=20).read().decode("utf-8", errors="ignore")
        m = re.search(r'href=["\'](https?://download\d+\.mediafire\.com/[^"\']+)["\']', html)
        if m:
            self.download_direct(m.group(1))
        else:
            raise RuntimeError("Could not find direct download link on MediaFire page.")

    def download_pixeldrain(self):
        self.log("Connecting to PixelDrain repository storage...")
        m = re.search(r"pixeldrain\.com/u/([a-zA-Z0-9_-]+)", self.raw_url)
        if m:
            self.download_direct(f"https://pixeldrain.com/api/file/{m.group(1)}")
        else:
            self.download_direct(self.raw_url)

    def execute(self):
        url = self.raw_url
        self.log(f"Host:     {self.provider}")
        self.log(f"Source:   {url}")

        if "mega.nz" in url or "mega.co.nz" in url:
            self.download_mega()
        elif "drive.google.com" in url or "docs.google.com" in url:
            self.download_gdrive()
        elif any(d in url for d in ["terabox.com", "terabox.app", "1024tera.com", "teraboxapp.com", "freeterabox.com", "teraboxlink.com", "mirrobox.com", "nephobox.com"]):
            self.download_terabox()
        elif "dropbox.com" in url:
            self.download_dropbox()
        elif "1drv.ms" in url or "onedrive.live.com" in url:
            self.download_onedrive()
        elif "mediafire.com" in url:
            self.download_mediafire()
        elif "pixeldrain.com" in url:
            self.download_pixeldrain()
        else:
            # Direct HTTP / HTTPS / IP / DuckDNS / GitHub Releases / GitLab / S3
            if not re.match(r"^https?://", url):
                if re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}", url):
                    url = "http://" + url
                else:
                    url = "https://" + url
            self.download_direct(url)

        # Integrity verification
        if self.expected_sha256:
            self.log("Verifying package SHA256 checksum...")
            sha256 = hashlib.sha256()
            with open(self.dest_path, "rb") as f:
                while True:
                    b = f.read(128 * 1024)
                    if not b:
                        break
                    sha256.update(b)
            actual_sha256 = sha256.hexdigest().lower()
            if actual_sha256 != self.expected_sha256:
                raise ValueError(
                    f"Integrity verification failed! Checksum mismatch.\n"
                    f"  Expected: {self.expected_sha256}\n"
                    f"  Actual:   {actual_sha256}"
                )
            self.log(f"Package integrity verified: OK")

def download_with_failover(urls, dest_path, expected_sha256=None):
    """Attempts download across multiple mirror URLs with automatic failover."""
    cleaned_urls = []
    for u in urls:
        for item in re.split(r"[\s,;]+", u):
            item = item.strip()
            if item:
                cleaned_urls.append(item)

    if not cleaned_urls:
        raise ValueError("No download URLs provided.")

    last_error = None
    for idx, url in enumerate(cleaned_urls, 1):
        if len(cleaned_urls) > 1:
            print(f"\n[🔗] Connecting to Mirror {idx}/{len(cleaned_urls)}: {identify_provider(url)}")
        try:
            dl = UniversalDownloader(url, dest_path, expected_sha256)
            dl.execute()
            if os.path.exists(dest_path) and os.path.getsize(dest_path) > 0:
                print(f"[✔] Package download completed successfully.")
                return True
        except Exception as e:
            last_error = e
            print(f"[!] Warning: Mirror {idx} temporarily unavailable ({e})")
            if os.path.exists(dest_path):
                try: os.remove(dest_path)
                except: pass
            if idx < len(cleaned_urls):
                print("[*] Switching to next available mirror...")
                time.sleep(1)

    raise RuntimeError(f"All mirrors failed to download package. Last error: {last_error}")

def parse_size_str(s):
    if not s:
        return 0
    m = re.match(r"^([\d.]+)\s*([kmgtp]?b?)$", s.strip(), re.IGNORECASE)
    if not m:
        return 0
    val = float(m.group(1))
    unit = m.group(2).upper()
    multiplier = 1
    if "K" in unit:
        multiplier = 1024
    elif "M" in unit:
        multiplier = 1024 * 1024
    elif "G" in unit:
        multiplier = 1024 * 1024 * 1024
    elif "T" in unit:
        multiplier = 1024 * 1024 * 1024 * 1024
    return int(val * multiplier)

def probe_remote_url(raw_url):
    cleaned = [u.strip() for u in re.split(r"[\s,;]+", raw_url) if u.strip()]
    if not cleaned:
        return {"url": raw_url, "provider": "Unknown", "filename": "", "size_bytes": 0, "size_str": "Unknown", "is_large": False}
    u = cleaned[0]
    provider = identify_provider(u)
    res = {
        "url": u,
        "provider": provider,
        "filename": "",
        "size_bytes": 0,
        "size_str": "Unknown",
        "is_large": False
    }

    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

    try:
        if "drive.google.com" in u or "docs.google.com" in u:
            m = re.search(r"[-_\w]{25,}", u)
            if m:
                fid = m.group(0)
                init_url = f"https://drive.google.com/uc?id={fid}&export=download"
                req = urllib.request.Request(init_url, headers={"User-Agent": USER_AGENT})
                resp = opener.open(req, timeout=15)
                cd = resp.headers.get("Content-Disposition", "")
                if "filename=" in cd:
                    fns = re.findall(r"filename\*?=(?:UTF-8\'\')?\"?([^\";]+)\"?", cd)
                    if fns:
                        res["filename"] = fns[0]
                cl = resp.headers.get("Content-Length")
                if cl and cl.isdigit():
                    res["size_bytes"] = int(cl)

                peek = resp.read(65536)
                html = peek.decode("utf-8", errors="ignore")
                fn_m = re.search(r"class=[\"\']uc-name-size[\"\']?>.*?<a[^>]*>([^<]+)</a>\s*\(([^)]+)\)", html, re.DOTALL) or re.search(r"download-file-name[\"\']?>([^<]+)<", html)
                if fn_m:
                    if len(fn_m.groups()) >= 2:
                        res["filename"] = fn_m.group(1).strip()
                        raw_size = fn_m.group(2).strip()
                        res["size_bytes"] = parse_size_str(raw_size)
                        res["size_str"] = format_size(res["size_bytes"]) if res["size_bytes"] > 0 else raw_size
                    else:
                        res["filename"] = fn_m.group(1).strip()
                    res["is_large"] = True
                elif res["size_bytes"] > 0:
                    res["size_str"] = format_size(res["size_bytes"])
                    if res["size_bytes"] > 100 * 1024 * 1024:
                        res["is_large"] = True

        elif "mega.nz" in u or "mega.co.nz" in u:
            m = re.search(r"mega\.(?:nz|co\.nz)/(?:file/|#!)?([a-zA-Z0-9_-]+)[#!]([a-zA-Z0-9_-]+)", u)
            if m:
                file_id, file_key = m.group(1), m.group(2)
                api_url = "https://g.api.mega.co.nz/cs"
                post_data = json.dumps([{"a": "g", "g": 1, "ssl": 2, "p": file_id}]).encode('utf-8')
                req = urllib.request.Request(api_url, data=post_data, headers={"Content-Type": "application/json", "User-Agent": USER_AGENT})
                resp = urllib.request.urlopen(req, timeout=15)
                mega_res = json.loads(resp.read().decode('utf-8'))
                if isinstance(mega_res, list) and mega_res and "s" in mega_res[0]:
                    s = mega_res[0]["s"]
                    res["size_bytes"] = int(s)
                    res["size_str"] = format_size(res["size_bytes"])
                    if res["size_bytes"] > 100 * 1024 * 1024:
                        res["is_large"] = True
                    if "at" in mega_res[0]:
                        try:
                            data = file_key + '=' * ((4 - len(file_key) % 4) % 4)
                            key_bytes = base64.urlsafe_b64decode(data)
                            if len(key_bytes) % 4 != 0: key_bytes += b'\0' * (4 - len(key_bytes) % 4)
                            k = [struct.unpack('>I', key_bytes[i:i+4])[0] for i in range(0, len(key_bytes), 4)]
                            key_aes = b''.join(struct.pack('>I', x) for x in (k[0] ^ k[4], k[1] ^ k[5], k[2] ^ k[6], k[3] ^ k[7]))
                            at_data = base64.urlsafe_b64decode(mega_res[0]["at"] + '==')
                            p = subprocess.Popen(["openssl", "enc", "-d", "-aes-128-cbc", "-K", key_aes.hex(), "-iv", "0"*32, "-nopad"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                            out, _ = p.communicate(input=at_data)
                            if out.startswith(b"MEGA"):
                                meta_json = json.loads(out[4:].rstrip(b"\0").decode("utf-8", errors="ignore"))
                                res["filename"] = meta_json.get("n", "")
                        except Exception:
                            pass

        elif "pixeldrain.com" in u:
            m = re.search(r"pixeldrain\.com/u/([a-zA-Z0-9_-]+)", u)
            if m:
                info_url = f"https://pixeldrain.com/api/file/{m.group(1)}/info"
                req = urllib.request.Request(info_url, headers={"User-Agent": USER_AGENT})
                resp = urllib.request.urlopen(req, timeout=10)
                info = json.loads(resp.read().decode("utf-8"))
                res["filename"] = info.get("name", "")
                res["size_bytes"] = int(info.get("size", 0))
                res["size_str"] = format_size(res["size_bytes"])
                if res["size_bytes"] > 100 * 1024 * 1024:
                    res["is_large"] = True

        elif "dropbox.com" in u:
            dl_url = re.sub(r"[?&]dl=0", "", u)
            dl_url += ("&" if "?" in dl_url else "?") + "dl=1"
            req = urllib.request.Request(dl_url, headers={"User-Agent": USER_AGENT}, method="HEAD")
            resp = opener.open(req, timeout=10)
            cd = resp.headers.get("Content-Disposition", "")
            if "filename=" in cd:
                fns = re.findall(r"filename\*?=(?:UTF-8\'\')?\"?([^\";]+)\"?", cd)
                if fns: res["filename"] = fns[0]
            cl = resp.headers.get("Content-Length")
            if cl and cl.isdigit():
                res["size_bytes"] = int(cl)
                res["size_str"] = format_size(res["size_bytes"])
                if res["size_bytes"] > 100 * 1024 * 1024:
                    res["is_large"] = True

        else:
            target = u
            if not re.match(r"^https?://", target):
                target = ("http://" if re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}", target) else "https://") + target
            
            parsed = urllib.parse.urlparse(target)
            path_file = os.path.basename(parsed.path)
            if path_file and "." in path_file:
                res["filename"] = urllib.parse.unquote(path_file)

            req = urllib.request.Request(target, headers={"User-Agent": USER_AGENT}, method="HEAD")
            try:
                resp = opener.open(req, timeout=10)
            except Exception:
                req2 = urllib.request.Request(target, headers={"User-Agent": USER_AGENT, "Range": "bytes=0-0"})
                resp = opener.open(req2, timeout=10)

            cd = resp.headers.get("Content-Disposition", "")
            if "filename=" in cd:
                fns = re.findall(r"filename\*?=(?:UTF-8\'\')?\"?([^\";]+)\"?", cd)
                if fns: res["filename"] = fns[0]
            
            cr = resp.headers.get("Content-Range", "")
            cl = resp.headers.get("Content-Length")
            if cr and "/" in cr:
                total = cr.split("/")[-1].strip()
                if total.isdigit():
                    res["size_bytes"] = int(total)
            elif cl and cl.isdigit() and resp.status != 206:
                res["size_bytes"] = int(cl)
            
            if res["size_bytes"] > 0:
                res["size_str"] = format_size(res["size_bytes"])
                if res["size_bytes"] > 100 * 1024 * 1024:
                    res["is_large"] = True

    except Exception:
        if not res["filename"]:
            parsed = urllib.parse.urlparse(u)
            path_file = os.path.basename(parsed.path)
            if path_file and "." in path_file:
                res["filename"] = urllib.parse.unquote(path_file)

    if res["filename"]:
        res["filename"] = re.sub(r"[?#].*$", "", res["filename"]).strip("\"'")

    return res

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Universal Linux Repository Multi-Provider Downloader")
    parser.add_argument("urls", nargs="+", help="Download URL(s) - supports Mega, Google Drive, Direct/IP, TeraBox, Dropbox, etc.")
    parser.add_argument("-o", "--output", help="Destination output file path (required for downloading)")
    parser.add_argument("--sha256", help="Expected SHA256 checksum for verification")
    parser.add_argument("--info", action="store_true", help="Print provider info and exit")
    parser.add_argument("--probe", action="store_true", help="Probe remote URL metadata without downloading (outputs JSON)")
    parser.add_argument("--probe-env", action="store_true", help="Probe remote URL metadata without downloading (outputs bash eval format)")
    args = parser.parse_args()

    if args.info:
        cleaned = []
        for u in args.urls:
            for item in re.split(r"[\s,;]+", u):
                item = item.strip()
                if item:
                    cleaned.append(item)
        for u in cleaned:
            print(f"URL:      {u}")
            print(f"Provider: {identify_provider(u)}\n")
        sys.exit(0)

    if args.probe or args.probe_env:
        probe_res = probe_remote_url(args.urls[0])
        if args.probe_env:
            fn = probe_res.get("filename", "").replace('"', '\\"')
            prov = probe_res.get("provider", "Unknown").replace('"', '\\"')
            sb = probe_res.get("size_bytes", 0)
            ss = probe_res.get("size_str", "Unknown").replace('"', '\\"')
            isl = "true" if probe_res.get("is_large", False) else "false"
            print(f'PROBE_PROVIDER="{prov}"')
            print(f'PROBE_FILENAME="{fn}"')
            print(f'PROBE_SIZE_BYTES={sb}')
            print(f'PROBE_SIZE_STR="{ss}"')
            print(f'PROBE_IS_LARGE="{isl}"')
        else:
            print(json.dumps(probe_res, indent=2))
        sys.exit(0)

    if not args.output:
        parser.error("-o/--output is required when downloading.")

    try:
        download_with_failover(args.urls, args.output, args.sha256)
    except Exception as e:
        print(f"\n[-] ERROR: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
