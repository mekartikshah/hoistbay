# S3 Scout 🪣

<div align="center">

**A beautiful, modern, and open-source desktop application for browsing and managing your AWS S3 buckets and CloudFront distributions.**

[![Flutter](https://img.shields.io/badge/Flutter-3.5.3-02569B?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

[Features](#features) • [Installation](#installation) • [Security](#-security) • [Support](#-support)

</div>

---

## ✨ Features

- 🎨 **Modern UI** - Clean, high-performance interface built with Flutter.
- 🔐 **Local & Secure** - Your AWS keys are stored locally in your system's secure keychain (macOS Keychain, Windows Credential Manager). They never leave your machine.
- 📁 **Bucket Management** - Browse, search, and manage all your S3 buckets.
- ⚡ **CloudFront Integration** - Manage your CloudFront distributions and create invalidations directly from the app.
- 🛠️ **Header Automation** - Define "Default HTTP Headers" rules based on file extensions (e.g., `*.js`, `*.css`) to automatically apply metadata like `Cache-Control` or `Content-Disposition` during uploads.
- 🗂️ **File Navigation** - Intuitive breadcrumb navigation and folder browsing.
- ⬆️ **Fast Uploads** - Concurrent file uploads with progress tracking.
- ⬇️ **Downloads** - Download objects to your local machine with ease.
- 🔄 **Profile Switching** - Seamlessly switch between multiple AWS accounts and regions.
- 💻 **Cross-platform** - Native performance on macOS, Windows, and Linux.

## 📸 Screenshots

> _Coming soon for Product Hunt launch!_

## 🔒 Security

Security is our top priority. S3 Scout is designed to be a "Zero-Knowledge" client:
- **Local Storage:** Credentials are stored using `flutter_secure_storage`, which utilizes platform-native encryption (Biometrics/PIN-backed where available).
- **Direct Communication:** The app communicates directly with AWS APIs. No intermediate servers or analytics trackers are used.
- **Open Source:** Because it's open-source, the security community can audit every line of code to ensure your keys are handled safely.

## 🚀 Installation

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.5.3 or higher)
- macOS, Windows, or Linux
- AWS Account with S3/CloudFront access

### Build from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/s3_scout.git
   cd s3_scout
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   # macOS
   flutter run -d macos
   
   # Windows
   flutter run -d windows
   ```

## 🛠️ Tech Stack

- **Framework**: Flutter 3.5.3
- **State Management**: Provider
- **AWS SDK**: `aws_s3_api`, `aws_cloudfront_api`
- **Secure Storage**: `flutter_secure_storage`

## 🤝 Contributing

Contributions are what make the open-source community an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

Distributed under the MIT License. See `LICENSE` for more information.

## 💖 Support

If S3 Scout makes your life easier, please consider giving it a ⭐ on GitHub or supporting the project:

<a href="https://www.buymeacoffee.com/yourusername" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="50">
</a>

---

<div align="center">
Built with ❤️ for the AWS Community
</div>
