# webOS Photo Screensaver

Show your own photos on an LG TV instead of LG's built-in art.

It replaces two screens:

- **The "no signal" screen.** When the device on an HDMI input is off or unplugged, LG shows a slideshow of paintings. You'll see your photos instead.
- **The screensaver.** After the TV sits idle on the home screen or in an app, you'll see your photos instead of LG's screensaver.

Each time one of these screens starts, it picks a random order of your photos and repeats that order until you wake the TV. You never see the same photo twice in a row. One command puts LG's screens back.

## Before you start

You need:

1. **A rooted LG TV with Homebrew Channel.** Rooting unlocks your TV so it can run apps and tools that LG doesn't allow. Go to **[cani.rootmy.tv](https://cani.rootmy.tv/)**, enter your TV's firmware version, and follow its steps. Homebrew Channel gets installed as part of rooting.
2. **Telnet turned on.** Open Homebrew Channel on the TV, go to Settings, and make sure **Telnet** is on. It's on by default.
3. **A Mac or a Linux computer** on the same network as the TV. Windows isn't supported yet.
4. **Linux only:** ImageMagick (for example `sudo apt install imagemagick`). A Mac needs nothing extra.

> [!WARNING]
> **Rooting your TV and using this tool is at your own risk.** Rooting can void your warranty, and a mistake while rooting can damage your TV. This tool changes how two of the TV's screens look and doesn't touch anything else. It has been tested on one TV model only (see [Tested on](#tested-on)). If anything looks wrong, `./uninstall.sh` puts LG's screens back.

## Install

1. **Download this project.** Click the green **Code** button at the top of this page, then **Download ZIP**, and unzip it.
2. **Add your photos.** Put them in the `photos` folder inside the project. JPG, PNG, HEIC, WebP, and TIFF all work.
3. **Open Terminal.** On a Mac, press Cmd+Space, type `Terminal`, and press Return.
4. **Go to the project folder.** Type `cd ` (with a space after it), drag the project folder onto the Terminal window, and press Return.
5. **Run the installer:**

   ```
   ./install.sh
   ```

The installer finds your TV on the network, asks you to confirm it, prepares your photos, and sends them to the TV. That's it.

To see your photos right away, switch the TV to an HDMI input with nothing plugged in.

## Change your photos

Add or remove photos in the `photos` folder, then run `./install.sh` again.

## Uninstall

```
./uninstall.sh
```

This puts LG's screensaver and art back and removes everything this tool put on the TV.

## Options

| Command | What it does |
| --- | --- |
| `./install.sh ~/Pictures/tv` | Use photos from another folder |
| `./install.sh --no-shuffle` | Leave out the shuffle helper (see below) |
| `./install.sh --tv 192.168.1.50` | Use this TV address and skip the search |
| `./uninstall.sh --tv 192.168.1.50` | Same, for uninstalling |

## Photo tips

- **Crop your photos to 16:9 (widescreen) first** for the best fit. Any other shape gets cropped from the center to fill the screen, so edges may be cut off.
- 1920x1080 or larger looks best. The TV shows these screens at 1920x1080.
- **Sideways photos on a Mac without ImageMagick:** macOS's built-in photo tool can't read the rotation setting that phones save, so a photo taken sideways can show sideways. Export your photos from the Photos app (File > Export) before adding them, or install [ImageMagick](https://imagemagick.org/) with `brew install imagemagick`.

## About the shuffle helper

LG's no-signal screen picks a random painting every 10 seconds, so it can show the same one twice in a row. The shuffle helper fixes that and gives you the random order that repeats.

**Is it a listener? Is it spying on me?** No. It's a short Python script, [`tv/shuffle.py`](tv/shuffle.py), that you can read yourself. It runs on the TV, uses no network at all, and opens no ports. The only thing it watches is the screensaver's own photo folder on the TV. When the TV opens a photo from that folder, the helper lines up the next one.

To leave it out, install with `./install.sh --no-shuffle`. The no-signal screen then shows your photos in random order (LG's way), using up to 16 photos.

## Good to know

- **Telnet:** Homebrew Channel's Telnet lets anyone on your home network control the TV, with no password. After installing, you can turn Telnet off in Homebrew Channel's settings, and your photos keep working. Turn it back on when you want to update or uninstall.
- **Restarts:** your photos stay after the TV restarts. Homebrew Channel turns them back on at every startup.
- **Timing:** the no-signal screen changes photos every 10 seconds with no fade. That's LG's timing and can't be changed. The idle screensaver changes photos every 15 seconds with a fade.
- **LG's files:** nothing in LG's system files changes. The tool lays your photos over LG's screens, and uninstalling or turning off Homebrew Channel's startup scripts removes that layer.

## Tested on

| TV | Software version | webOS TV version | Result |
| --- | --- | --- | --- |
| LG OLED42C3PUA (2023) | 03.11.45 | 8.1.0-47 (webOS 23) | Both screens work |

Tried it on another TV? Please open an issue with your model, software version, webOS TV version, and what worked. Both versions are in the TV's settings, under General > System > TV Information and Support > Software Update. Please leave out your serial number and MAC addresses.

## Troubleshooting

**"No rooted LG TV found"**
- Make sure the TV is on and connected to the same network as your computer.
- Make sure Telnet is on in Homebrew Channel's settings.
- Find the TV's address in Settings > General > Network > Wi-Fi Connection (or Wired Connection) > Advanced Settings, then run `./install.sh --tv <address>`.

**"The TV couldn't download the files from this computer"**
- A firewall on your computer is blocking the TV. On a Mac, check System Settings > Network > Firewall > Options and make sure **Block all incoming connections** is off. On Linux, allow incoming connections from the TV for a moment while you install.

**"Another mod already replaces this TV's screensaver"**
- Another app, such as Aerial Screensaver or Custom Screensaver, is using the same screen. Turn it off in that app first.

**The no-signal screen still shows LG's paintings**
- Some TV models use a different set of art. Please open an issue with your model and webOS version.

## How it works

For the curious:

- **Screensaver:** LG's screensaver is a small app. The tool mounts its own slideshow over the app's main file (`/usr/palm/applications/com.webos.app.screensaver/qml/main.qml`) with a Linux bind mount. Nothing in LG's file changes.
- **No-signal screen:** LG's HDMI input app shows the paintings `modernart_0.jpg` to `modernart_15.jpg` from `/mnt/lg/appstore/preload/igallery/files/data/modernart`, choosing one at random every 10 seconds. The tool mounts a folder of your photos over that folder under the same 16 names. The input app's own code can't be changed this way, because the TV restores it at startup from a snapshot made at the factory.
- **Shuffle helper:** all 16 names point to one photo. When the input app opens a name, the helper (using the Linux kernel's file notifications) points all 16 names at the next photo in the order. Whichever name LG picks, it gets the next photo.
- **Startup:** Homebrew Channel runs `/var/lib/webosbrew/init.d/50-photo-screensaver` at every startup, which turns everything back on.
- **On the TV,** everything lives in `/media/developer/photo-screensaver`.

## License

[MIT](LICENSE)
