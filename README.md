# Flux Script

Flux is a multi-purpose utility script for GTA: San Andreas Multiplayer (SAMP)

## Features

- **Weapon**
  - NoSpread
  - NoReload
  - Instant Crosshair

- **Visual**
  - ESP (Player boxes)
  - Lines (from player to others)
  - Skeleton (player bone visualization)
  - Info Bar (FPS, Ping, Position)
  - Adjustable box thickness

- **Car**
  - Drift Mode (hold/toggle/always)
  - Speed Control (auto speed, boost, increment/decrement)
  - Ground Stick (improved handling at high speed)
  - GM InCar (godmode for vehicles)
  - GM Wheels (unbreakable tires)
  - AntiBoom (prevents explosion when upside down)
  - WaterDrive (drive on water)
  - FireCar (set car health to 4)
  - Fix Wheels (repair tires)
  - Damage Multiplier

- **Misc**
  - AntiStun
  - FakeAFK
  - FakeLag
  - No Fall
  - Infinite Oxygen
  - Mega Jump
  - BMX Mega Jump
  - GodMode (player)
  - NoBike Fall
  - QuickStop

- **Configuration Manager**
  - Create, load, overwrite, and delete named configurations
  - Manage multiple settings profiles via scrollable list

- **Keybind Manager**
  - Change keybinds in-game
  - Save/load keybind configuration

## Installation

1. Place `flux.lua` in your `moonloader` directory.
2. Start SAMP and ensure MoonLoader is running.
3. The script will load automatically.

## Usage

- Press `U` to open the Flux menu.
- Use the menu to toggle features and adjust settings.
- Keybinds can be changed in the Keybinds tab.
- Configurations can be managed in the Configs tab.
- Quick actions (Reconnect, Fix Wheels) are available in the sidebar.

## Configuration

- Settings profiles are saved in `moonloader/config/Flux/`.
- Keybinds are saved to `moonloader/Flux_keybinds.cfg`.
- Log messages are written to `moonloader/Flux_log.txt`.

## Requirements

- MoonLoader
- SAMP
- Required libraries: `imgui`, `encoding`, `memory`, `ffi`, `lib.samp.events`, `vkeys`, `lfs`

## Credits

- Skeleton visualization/Info Bar adapted from Zuwi

## Support

For issues or suggestions, contact the author or open an issue in the relevant forum/thread.
