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

It remembers NAS connection profiles per Wi-Fi network, stores credentials securely in the macOS Keychain, and can automatically mount saved shares when your Mac connects to a known network.

Mount your shares. Move on with your day.

---

## Features

- Mount SMB shares from a NAS using an IP address or hostname
- Browse available shares from the connected NAS
- Select and mount one or multiple shares
- Save credentials securely in the macOS Keychain
- Remember NAS connection profiles per Wi-Fi network
- Auto-mount saved shares when connected to a known network
- Keep mounted shares visually separate from selected shares
- Use a compact macOS menu bar popover interface
- Enable or disable the Dock icon from Settings
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
7. NAS-Mountie saves the connection profile for the current Wi-Fi network.
8. Next time you are on that network, saved shares can mount automatically.

---

## Network Profiles

NAS-Mountie remembers connection profiles by Wi-Fi network.

For example:

- On your home network, it can remember your home NAS and selected shares.
- On another network, it starts with an empty form unless you save a separate profile there.
- This helps avoid showing or mounting shares from the wrong network.

A network profile can include:

- Wi-Fi network name
- NAS host or IP address
- Username
- Previously mounted shares

Passwords are handled separately through the macOS Keychain.

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
git clone https://github.com/josueluna/NAS-Mountie.git
```

Open the project in Xcode:

```bash
open NAS-Mountie/NAS-Mountie.xcodeproj
```

Build and run:

```text
Cmd + R
```

---

## Create a local app build

To create a local usable `.app`:

1. In Xcode, set the scheme to **Release**.
2. Build the project.
3. Go to **Product > Show Build Folder in Finder**.
4. Open `Products/Release`.
5. Copy `NAS-Mountie.app` to `/Applications`.

---

## Current status

NAS-Mountie is currently in beta.

The app is stable enough for daily local testing, but features and UI details may continue to change.

---

## Roadmap

- App icon and custom menu bar icon polish
- Cleaner release packaging
- GitHub Releases
- Improved settings management
- Better network profile management UI
- Optional unmount/disconnect actions
- Additional SMB validation and error handling
- More detailed mount status feedback

---

## Author

Developed by [Josué Luna](https://www.linkedin.com/in/josuelunagamboa/).

---

## License

This project is licensed under the MIT License.
