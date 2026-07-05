# EJJ Boombox

A compact FiveM boombox resource with a Mantine-based NUI for positional music playback. Players can place a boombox in the world, open it through `ox_target`, play stream URLs, manage a queue, adjust volume/range, seek through tracks, and pick the boombox back up as an inventory item.

## Features

- Placeable boombox object using `prop_boombox_01`
- `ox_target` interactions for opening and removing the boombox
- `ox_inventory` item support with item consume/return handling
- Positional audio playback through `xsound`
- Stream URL playback from the NUI
- Queue system with add, play now, and remove controls
- Automatic next-track playback when a song ends
- YouTube oEmbed title lookup for queued YouTube links
- Volume control from 0% to 100%
- Adjustable sound distance/range
- Seek/progress support for active tracks
- Pause, resume, stop, and close actions
- Server-side state handling per placed boombox
- Mantine dark UI with a minimal, Linear-inspired game menu style

## Dependencies

Make sure these resources are installed and started before `ejj_boombox`:

- `ox_lib`
- `ox_inventory`
- `ox_target`
- `xsound`

Example `server.cfg` order:

```cfg
ensure ox_lib
ensure ox_inventory
ensure ox_target
ensure xsound
ensure ejj_boombox
```

## Installation

1. Place this folder in your server `resources` directory.
2. Add the boombox item to `ox_inventory`.
3. Ensure the dependencies are started before this resource.
4. Add `ensure ejj_boombox` to your `server.cfg`.
5. Restart the server or start the resource.

## ox_inventory Item

Add an item similar to this in your `ox_inventory` item data:

```lua
['boombox'] = {
    label = 'Boombox',
    weight = 1500,
    stack = false,
    close = true,
    client = {
        export = 'ejj_boombox.placeBoombox'
    }
}
```

The item name must match `Config.ItemName`.

## Usage

Players can use the configured item to place a boombox. The resource also includes a command for quick placement:

```txt
/boombox
```

After placement, target the boombox to:

- Open the music menu
- Pick up/remove the boombox

Inside the menu, players can enter a stream URL, start playback, add tracks to the queue, adjust volume and range, seek, pause, resume, or stop the current track.

## Configuration

Configuration is handled in `config.lua`:

```lua
Config.EnableCommand = true
Config.Command = 'boombox'
Config.ItemName = 'boombox'
Config.Model = 'prop_boombox_01'
Config.PlaceDistance = 1.0
Config.TargetDistance = 2.0
Config.DefaultVolume = 0.50
Config.DefaultDistance = 18.0
Config.MinDistance = 2.0
Config.MaxDistance = 40.0
Config.SoundPrefix = 'ejj_boombox'
```

Set `Config.EnableCommand = false` if players should only place boomboxes through the inventory item.

## NUI

The included NUI is already built in `web/dist` and loaded through `fxmanifest.lua`.

The interface is built with Mantine and follows a compact dark menu style: charcoal surfaces, thin borders, restrained spacing, and quiet interactive states suitable for an in-game FiveM menu.

## Notes

- `xsound` must support the URL being played.
- YouTube titles are resolved only for queued YouTube links when the oEmbed request succeeds.
- Placed boomboxes are runtime objects and are cleaned up when the resource stops.
