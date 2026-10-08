# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-10-08

### Changed
- Renamed the app from S3 Scout to **Hoistbay**, with a new app icon
- Release builds are now `Hoistbay-macOS.zip` and `Hoistbay-Windows.zip`; the Windows app is `hoistbay.exe`
- New macOS bundle identifier (`com.kshah.hoistbay`): profiles saved with earlier builds need to be added again

## [1.1.0] - 2026-10-08

### Added
- macOS-style redesign with sidebar navigation
- Activity panel tracking uploads, downloads, deletes and CloudFront invalidations
- Folder download
- CloudFront cache clearing (invalidations)
- Search within buckets
- Copy objects across buckets (including cross-region)
- Multi-folder and drag-and-drop uploads with progress

### Fixed
- Deleting objects now reports per-object failures (e.g. AccessDenied) instead of silently succeeding
- Folder delete no longer sends duplicate keys
- Folder upload now includes files at the top level of the selected folder
- Search text is cleared when navigating to another page

### Changed
- Release builds are published as `S3-Scout-macOS.zip` and `S3-Scout-Windows.zip`
- Minimum macOS version is 12

## [1.0.0] - 2025-01-26

### Added
- Initial release (as AWS S3 Browser)
- Multi-profile support for managing multiple AWS accounts
- Secure credential storage using platform-specific encryption
- Browse and navigate S3 buckets and objects
- Upload files to S3 buckets
- Download objects from S3
- Breadcrumb navigation for folder hierarchy
- Profile management (create, edit, delete)
- Real-time bucket listing
- Support for all AWS regions
- Cross-platform support (macOS, Windows)
- Clean, modern UI with Material Design

### Security
- Encrypted credential storage
- Secure communication with AWS using official SDK
- No credential transmission except to AWS

## [Unreleased]

### Planned
- Drag and drop file uploads
- Batch file operations
- Search functionality
- File preview
- Bucket creation and deletion
- Object metadata viewing and editing
- Access control management
- Cost estimation
- Dark mode support
