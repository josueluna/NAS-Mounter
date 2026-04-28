# NAS-Mountie

[![Version](https://img.shields.io/github/v/release/josueluna/NAS-Mountie?logo=github&color=2F6F4E)](https://github.com/josueluna/NAS-Mountie/releases)
[![License](https://img.shields.io/badge/license-MIT-2F6F4E)](https://opensource.org/licenses/MIT)
[![Status](https://img.shields.io/badge/status-BETA-B8892E)](https://github.com/josueluna/NAS-Mountie)
[![Platform](https://img.shields.io/badge/platform-macOS-3F7F5F?logo=apple)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-SwiftUI-D96C3B?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Commit Activity](https://img.shields.io/github/commit-activity/m/josueluna/NAS-Mountie?color=5F8F6A)](https://github.com/josueluna/NAS-Mountie)
[![Issues](https://img.shields.io/github/issues/josueluna/NAS-Mountie?color=8A6F3D)](https://github.com/josueluna/NAS-Mountie/issues)
[![Maintenance](https://img.shields.io/badge/maintenance-active-2F6F4E)](https://github.com/josueluna/NAS-Mountie)

**NAS-Mountie** is a lightweight macOS menu bar app for mounting SMB/NAS shares quickly, safely, and with as little friction as possible.

It remembers your NAS profiles per Wi-Fi network, stores credentials securely in the macOS Keychain, and can automatically mount saved shares when your Mac connects to a known network.

Mount your shares. Move on with your day.

---

## Features

- Mount SMB shares from a NAS using IP address or hostname
- Browse available shares from the connected NAS
- Select and mount one or multiple shares
- Save credentials securely in the macOS Keychain
- Remember NAS connection profiles per Wi-Fi network
- Auto-mount saved shares when connected to a known network
- Separate mounted shares from selected shares for clearer status
- Menu bar popover interface
- Optional Dock icon setting
- Launch at Login support
- Lightweight, focused macOS UI

---

## How it works

1. Open NAS-Mountie from the macOS menu bar.
2. Enter your NAS address, username, and password.
3. Browse available SMB shares.
4. Select one or more shares.
5. Click **Mount**.
6. Optionally enable **Remember Password**.
7. NAS-Mountie saves the profile for the current Wi-Fi network.
8. Next time you are on that network, saved shares can mount automatically.

---

## Network Profiles

NAS-Mountie remembers connection profiles by Wi-Fi network.

For example:

- On your home network, it can remember your home NAS and selected shares.
- On another network, it will start with an empty form unless you save a separate profile there.
- This avoids showing or mounting shares from the wrong network.

---

## Security

NAS-Mountie uses the macOS Keychain to store credentials securely.

Passwords are not stored as plain text in app files or source code.

---

## Requirements

- macOS 13 or later recommended
- SMB sharing enabled on your NAS
- Network access to the NAS
- Xcode for building from source

Some features, such as Launch at Login, require modern macOS APIs.

---

## Installation from source

Clone the repository:

```bash
git clone https://github.com/josueluna/NAS-Mountie.git# NAS Mounter
[![Version](https://img.shields.io/github/v/release/josueluna/NAS-Mountie?logo=github)](https://github.com/josueluna/NAS-Mountie/releases)
[![License](https://img.shields.io/badge/license-MIT-blue)](https://opensource.org/licenses/MIT)
[![Beta](https://img.shields.io/badge/status-BETA-orange)](https://github.com/josueluna/NAS-Mountie)
[![Platform](https://img.shields.io/badge/platform-macOS-blue)](https://developer.apple.com/macos/)
[![Commit Activity](https://img.shields.io/github/commit-activity/m/josueluna/NAS-Mountie)](https://github.com/josueluna/NAS-Mountie)
[![Issues](https://img.shields.io/github/issues/josueluna/NAS-Mountie)](https://github.com/josueluna/NAS-Mountie/issues)
[![Contributors](https://img.shields.io/github/contributors/josueluna/NAS-Mountie)](https://github.com/josueluna/NAS-Mountie/graphs/contributors)
[![Maintenance](https://img.shields.io/badge/maintenance-semi--active-yellow)](https://github.com/josueluna/NAS-Mountie)

NAS Mounter is a macOS application that allows users to easily mount SMB 
shares using credentials saved in the system keychain. It provides a 
simple interface to connect to NAS devices and manage shared resources.

## Features
- Mount SMB shares via IP or hostname
- Save credentials securely in the Keychain for future use
- Browse available shares from the connected NAS
- Modern and simple UI

## Requirements
- macOS 10.15 or later
- Network access to a NAS device with SMB sharing enabled

## Installation

1. Clone the repository:

```bash
git clone https://github.com/josueluna/nas-mounter.git
