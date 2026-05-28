# 📦 Vostok Packages

![toki_in_space](https://github.com/user-attachments/assets/3656fabe-5a35-4b90-be0d-d27def955ac2)

Custom package repository for Vostok Linux — a collection of hand-crafted .xbps packages, bringing the best software to your Void-based distribution.

# ⚙️ Automation & CI/CD (GitOps)

This repository is powered by a fully automated GitOps pipeline to ensure reliability and up-to-date software:

*   **Auto-Updates:** A dedicated bot monitors official upstream APIs daily. When a new version is released, it automatically updates templates, verifies checksums, and opens a Pull Request.
*   **Continuous Integration (CI):** Every change is automatically tested on our build farm via GitHub Actions. We never merge a package that fails to build.
*   **Continuous Deployment (CD):** Once a PR is merged, packages are automatically built, **cryptographically signed**, and deployed to our production VPS repository.


# 🚀 How to use this repository

You can either build the packages yourself using xbps-src, or install pre-built binaries directly from our repository.

Add the Vostok Linux repository to your system:

```bash
# Add the Vostok repository
echo "repository=https://repo.vostoklinux.org/current" | sudo tee -a /etc/xbps.d/vostok.conf

# Sync and install
sudo xbps-install -S
sudo xbps-install <package-name>
```

🌐 Stay connected

    💬 Telegram chat – for users and contributors

    🐦 @vostoklinux – updates and news

   













