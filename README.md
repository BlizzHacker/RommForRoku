# RomM for Roku

Roku companion channel for the MoveWeight RomM library. It uses RomM 4.9 client API-token pairing, so it never asks for or stores a RomM password.

## Pairing

1. Sign into `https://romm.moveweight.com` in a browser.
2. Create a Client API Token named `RomM for Roku` with read-only `platforms.read` and `roms.read` scopes.
3. Choose **Pair** for that token and enter the displayed eight-digit code in the channel.

Pairing codes are single-use and expire after five minutes. The resulting scoped token is stored in this channel's local Roku registry and can be revoked at any time in RomM.

## Build a sideload package

```powershell
./scripts/package.ps1
```

The package is written to `dist/RommForRoku-0.4.0.zip`. Upload that archive from the Roku device development web page. Do not zip the enclosing `romm-roku` folder; Roku requires `manifest`, `source`, and `components` at the archive root.

## Scope and platform limit

This is a real RomM library client: it pairs, reads the live platform/game catalog, and presents controller-friendly Roku navigation. It cannot directly run EmulatorJS or low-latency game streaming because Roku channels do not embed a browser/WebRTC game client and Roku does not expose arbitrary Bluetooth/USB gamepad input to channels. A future game-play path needs a separate approved relay/input architecture; it must not be represented as direct EmulatorJS support.
