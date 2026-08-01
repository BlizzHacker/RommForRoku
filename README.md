# RomM for Roku

> A **[Cartridge](https://github.com/BlizzHacker/rom-hub/blob/master/BRAND.md)** app by MoveWeight — the play pillar. Cartridge is a self-hosted retro-gaming ecosystem. Unofficial; not affiliated with RomM, Gaseous or Retrom.

Browse your self-hosted [RomM](https://github.com/rommapp/romm) game library
from the couch: a Roku channel with controller-friendly navigation over your
live platform and game catalog. It uses RomM 4.9's client API-token pairing,
so it never asks for — and never stores — your RomM password.

## Pair it with your RomM

1. Sign into your RomM instance in a browser.
2. Create a Client API Token named `RomM for Roku` with read-only
   `platforms.read` and `roms.read` scopes.
3. Choose **Pair** for that token and enter the displayed eight-digit code in
   the channel.

Pairing codes are single-use and expire after five minutes. The resulting
scoped token is stored in the channel's local Roku registry and can be revoked
in RomM at any time.

## Build a sideload package

```powershell
./scripts/package.ps1
```

The package is written to `dist/RommForRoku-<version>.zip`, with the version
taken from the manifest. Upload that archive from the Roku device development
web page. Do not zip the enclosing project folder; Roku requires `manifest`,
`source`, and `components` at the archive root.

## Playing games — what a Roku can and can't do

Roku channels cannot embed a browser or WebRTC client, and Roku exposes no
arbitrary gamepad input to channels — so games cannot run *on* the Roku.
Instead, streaming is served by
[RommStreamServer](https://github.com/BlizzHacker/RommStreamServer), the same
backend that powers
[RommForXbox](https://github.com/BlizzHacker/RommForXbox): sessions use
server-side **RetroArch** cores (GameCube, Wii, Dreamcast, PS2, Saturn, N64,
PSP, …) when available, falling back to a headless-Chromium EmulatorJS path —
delivered to the TV as HLS, with your phone as the controller.
