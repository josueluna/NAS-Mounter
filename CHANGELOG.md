# Changelog

All notable changes to this project will be documented in this file.

---

## [v0.2.0] - 2026-04-28

### Added

- Converted NAS-Mountie into a macOS menu bar popover app.
- Added custom menu bar flow with Settings and Quit actions.
- Added multi-share selection and mounting.
- Added SMB share discovery from a NAS.
- Added support for remembering mounted shares.
- Added network-specific NAS profiles.
- Added automatic mounting of saved shares when connected to a known Wi-Fi network.
- Added Launch at Login support.
- Added optional Dock icon setting.
- Added Settings panel with network profile management.
- Added mounted shares status on the main screen.
- Added password visibility toggle.
- Added support for pressing Enter in fields to trigger Mount.
- Added custom brand styling, including forest green UI accents.
- Added template menu bar icon support.

### Improved

- Updated primary action from **Connect** to **Mount** for clearer terminology.
- Separated selected shares from actually mounted shares.
- Prioritized selected shares at the top of the share picker.
- Preserved previously selected shares when browsing available shares.
- Improved Settings layout and copy for Network Profiles.
- Improved visual alignment of Settings cards and current network information.
- Improved menu button hit area and placement.
- Improved popover close behavior after successful mount.
- Improved startup behavior for menu bar usage.
- Improved app copy so UI is fully in English.
- Improved share picker layout and mounted share feedback.

### Fixed

- Fixed issue where saved shares appeared as mounted before actually being mounted.
- Fixed issue where selected shares were lost when browsing shares.
- Fixed issue where the app could show shares from the wrong Wi-Fi network.
- Fixed issue where the popover did not reliably close after mounting.
- Fixed issue where the SMB field received focus automatically when opening the popover.
- Fixed redundant or confusing network blocking behavior after moving to network profiles.
- Fixed Settings feedback message placement.
- Fixed menu/settings button visual placement issues.

---

## [v0.1.1] - 2026-04-18

### Fixed

- Resolved issue with redundant macOS authentication window.
- Adjusted window size for a more compact design.
- Improved initial UI layout.
- Moved labels outside input fields.
- Added clearer placeholders for SMB, username, and password fields.

---

## [v0.1.0] - 2026-04-17

### Added

- Initial release of NAS Mounter for macOS.
- Basic SMB share mounting functionality.
- Keychain integration to save credentials securely.
- UI for connecting to a NAS.
- Basic browse flow for available SMB shares.# Changelog

## [v0.1] - 2026-04-17
### Added
- Initial release of NAS Mounter for macOS.
- Basic SMB share mounting functionality.
- Keychain integration to save credentials securely.
- UI for connecting and browsing available shares.

## [v0.1.1] - 2026-04-18
### Fixed
- Resolved issue with redundant authentication window.
- Adjusted window size for a more compact and modern design.
