# AWS S3 Browser 🪣

<div align="center">

**A beautiful, modern desktop application for browsing and managing your AWS S3 buckets**

[![Flutter](https://img.shields.io/badge/Flutter-3.5.3-02569B?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Contributing](#contributing) • [Support](#support)

</div>

---

## ✨ Features

- 🎨 **Beautiful UI** - Clean, modern interface built with Flutter
- 🔐 **Secure Credentials** - Store multiple AWS profiles with encrypted credential storage
- 📁 **Bucket Management** - Browse all your S3 buckets in one place
- 🗂️ **File Navigation** - Navigate through folders with breadcrumb navigation
- ⬆️ **Upload Files** - Easy file uploads with drag-and-drop support
- ⬇️ **Download Objects** - Download files from your S3 buckets
- 🔄 **Real-time Updates** - Automatic refresh and real-time bucket listing
- 💻 **Cross-platform** - Works on macOS, Windows, and Linux
- 🌐 **Multi-region Support** - Connect to any AWS region
- 👤 **Profile Management** - Switch between multiple AWS accounts seamlessly

## 📸 Screenshots

> _Screenshots coming soon!_

## 🚀 Installation

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.5.3 or higher)
- macOS, Windows, or Linux
- AWS Account with S3 access

### Build from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/aws_s3_browser.git
   cd aws_s3_browser
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   # For macOS
   flutter run -d macos
   
   # For Windows
   flutter run -d windows
   
   # For Linux
   flutter run -d linux
   ```

4. **Build for production**
   ```bash
   # For macOS
   flutter build macos
   
   # For Windows
   flutter build windows
   
   # For Linux
   flutter build linux
   ```

## 📖 Usage

### Adding Your First Profile

1. Launch AWS S3 Browser
2. Click **"Add New Profile"**
3. Enter your profile details:
   - **Profile Name**: A friendly name for this AWS account
   - **Access Key ID**: Your AWS access key
   - **Secret Access Key**: Your AWS secret key
   - **Region**: Your preferred AWS region (e.g., `us-east-1`)
4. Click **"Save"**

### Connecting to S3

1. Select a profile from the list
2. Click **"Connect"**
3. Browse your buckets and objects!

### Managing Files

- **View Buckets**: All your buckets appear in the left sidebar
- **Navigate Folders**: Click on folders to navigate, use breadcrumbs to go back
- **Upload Files**: Click the upload button and select files
- **Download Files**: Click on any file to download it

### Managing Profiles

- **Edit Profile**: Click the menu icon (⋮) next to a profile and select "Edit"
- **Delete Profile**: Click the menu icon (⋮) and select "Delete"
- **Switch Profiles**: Click "Logout" and connect with a different profile

## 🔒 Security

- Credentials are stored securely using platform-specific secure storage
- No credentials are ever transmitted except directly to AWS
- All AWS communication uses official AWS SDK with HTTPS
- Credentials are encrypted at rest

## 🛠️ Tech Stack

- **Framework**: Flutter 3.5.3
- **State Management**: Provider
- **AWS SDK**: aws_s3_api
- **Secure Storage**: flutter_secure_storage
- **File Handling**: file_picker, path_provider

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💖 Support

If you find this project useful, consider supporting its development:

<a href="https://www.buymeacoffee.com/yourusername" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="50">
</a>

## 🐛 Bug Reports & Feature Requests

Found a bug or have a feature request? Please [open an issue](https://github.com/yourusername/aws_s3_browser/issues).

## 📧 Contact

- **Author**: Your Name
- **Email**: your.email@example.com
- **Twitter**: [@yourusername](https://twitter.com/yourusername)

## 🙏 Acknowledgments

- Built with [Flutter](https://flutter.dev)
- AWS SDK by [AWS](https://aws.amazon.com)
- Icons from [Material Design Icons](https://materialdesignicons.com)

---

<div align="center">
Made with ❤️ by Your Name
</div>
