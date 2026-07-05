# EJJ Boombox

A compact FiveM boombox resource with a Mantine-based NUI for positional music playback. Players can place a boombox in the world, open it through `ox_target` or a 3D text fallback, play stream URLs, manage a queue, adjust volume/range, seek through tracks, and pick the boombox back up as an inventory item.

## Features

- Placeable boombox object using `prop_boombox_01`
- Optional `ox_target` interactions for opening and removing the boombox
- 3D draw text fallback with keybinds when `ox_target` is disabled
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
- `xsound`

Optional:

- `ox_target`

Example `server.cfg` order:

```cfg
ensure ox_lib
ensure ox_inventory
ensure xsound
ensure ox_target # optional when Config.UseOxTarget = true
ensure ejj_boombox
```

## Installation

1. Place this folder in your server `resources` directory.
2. Add the boombox item to `ox_inventory`.
3. Ensure the required dependencies are started before this resource.
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

After placement, interact with the boombox using `ox_target` or the fallback 3D prompt to:

- Open the music menu
- Pick up/remove the boombox

Inside the menu, players can enter a stream URL, start playback, add tracks to the queue, adjust volume and range, seek, pause, resume, or stop the current track.

## Configuration

Configuration is handled in `config.lua`:

```lua
Config.EnableCommand = true
Config.Command = 'boombox'
Config.UseOxTarget = true
Config.OpenControl = 38 -- E
Config.PickupControl = 47 -- G
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

Set `Config.UseOxTarget = false` to use the built-in 3D draw text fallback instead of `ox_target`. In fallback mode, players press `E` to open the boombox UI and `G` to pick it up.

If `Config.UseOxTarget = true` but `ox_target` is not started, the client automatically uses the 3D draw text fallback.

## Language

This resource uses `ox_lib` locale files from `locales/*.json`. Included languages: English (`en`), Danish (`da`), Norwegian (`no`), Swedish (`sv`), Finnish (`fi`), Hebrew (`he`), Chinese (`zh`), Arabic (`ar`), Indonesian (`id`), French (`fr`), Portuguese (`pt`), Spanish (`es`), Thai (`th`), Filipino (`tl`), German (`de`), Romanian (`ro`), and Hungarian (`hu`).

Set the preferred language in `server.cfg`:

```cfg
setr ox:locale en
```

Replace `en` with any included language code, for example `setr ox:locale da` for Danish or `setr ox:locale sv` for Swedish.

## NUI

The included NUI is already built in `web/dist` and loaded through `fxmanifest.lua`.

The interface is built with Mantine and follows a compact dark menu style: charcoal surfaces, thin borders, restrained spacing, and quiet interactive states suitable for an in-game FiveM menu.

## Notes

- `xsound` must support the URL being played.
- YouTube titles are resolved only for queued YouTube links when the oEmbed request succeeds.
- Placed boomboxes are runtime objects and are cleaned up when the resource stops.
