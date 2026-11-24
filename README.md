# webOS Custom Screens

Put your own pictures on three of an LG TV's screens:

- **The "no signal" screen.** When the device on an HDMI input is off or unplugged, LG shows a slideshow of paintings. You'll see your photos instead.
- **The screensaver.** After the TV sits idle on the home screen or in an app, you'll see your photos instead of LG's screensaver.
- **The power-off screen.** When you turn the TV off, LG shows its logo for a moment. You'll see your logo, or any picture you like, instead.

Each time the no-signal screen or the screensaver starts, it picks a random order of your photos and repeats that order until you wake the TV. You never see the same photo twice in a row. One command puts LG's screens back.

## Before you start

You need:

1. **A rooted LG TV with Homebrew Channel.** Rooting unlocks your TV so it can run apps and tools that LG doesn't allow. Go to **[cani.rootmy.tv](https://cani.rootmy.tv/)**, enter your TV's firmware version, and follow its steps. Homebrew Channel gets installed as part of rooting.
2. **Telnet turned on.** Open Homebrew Channel on the TV, go to Settings, and make sure **Telnet** is on. It's on by default.
3. **A Mac or a Linux computer** on the same network as the TV. Windows isn't supported yet.
4. **Linux only:** ImageMagick (for example `sudo apt install imagemagick`). A Mac needs nothing extra.

> [!WARNING]
> **Rooting your TV and using this tool is at your own risk.** Rooting can void your warranty, and a mistake while rooting can damage your TV. This tool changes how three of the TV's screens look and doesn't touch anything else. It has been tested on one TV model only (see [Tested on](#tested-on)). If anything looks wrong, `./uninstall.sh` puts LG's screens back.

## Install

1. **Download this project.** Click the green **Code** button at the top of this page, then **Download ZIP**, and unzip it.
2. **Open Terminal.** On a Mac, press Cmd+Space, type `Terminal`, and press Return.
3. **Go to the project folder.** Type `cd ` (with a space after it), drag the project folder onto the Terminal window, and press Return.
4. **Run the installer:**

   ```
   ./install.sh
   ```

The installer tells you what it's doing at each step and asks before it continues. It finds your TV on the network, prepares the pictures, and sends them to the TV.

Out of the box, it uses this project's own pictures: the photos in the `screensaver` folder and `logo.png`. That way you can see it working before you pick your own. To see them, switch the TV to an HDMI input with nothing plugged in, or turn the TV off with the remote.

## Use your own pictures

Your photos on the screensaver and the no-signal screen:

```
./install.sh --screensaver ~/Pictures/tv
```

Your logo, or any picture, on the power-off screen:

```
./install.sh --logo ~/Pictures/logo.png
```

Both at once:

```
./install.sh --screensaver ~/Pictures/tv --logo ~/Pictures/logo.png
```

Each option changes only its own screen. The other screen stays as it is on the TV. JPG, PNG, HEIC, WebP, and TIFF all work.

**Tip:** type the command up to the space after `--screensaver` or `--logo`, then drag your folder or picture onto the Terminal window. Terminal fills in its location for you.

To change your photos later, run the same command again.

## Turn a screen on or off

LG has a setting for the no-signal screen and one for the power-off logo. Both are on by default. To change them, open LG's hidden menu: press the **Settings** button or the **Mute** button on the remote over and over, quickly, until it opens. Then look for:

- **No Signal Image** for the no-signal screen
- **Show LG logo when turning off the TV** for the power-off screen

When one is off, the TV skips that screen, so your pictures don't show there either.

## Uninstall

```
./uninstall.sh
```

This puts LG's screensaver, no-signal art, and power-off logo back, and removes everything this tool put on the TV.

## Options

Mix and match any of these. Run `./install.sh --help` to see them in Terminal.

| Option | What it does |
| --- | --- |
| `--screensaver [FOLDER]` | Change only the screensaver and the no-signal screen. Uses the photos in FOLDER, or this project's `screensaver` folder when you leave FOLDER out. |
| `--logo [FILE]` | Change only the power-off logo. Uses the picture FILE, or this project's `logo.png` when you leave FILE out. |
| `--no-shuffle` | Leave out the shuffle helper (see below) |
| `--tv ADDRESS` | Use the TV at this address and skip the search |
| `--non-interactive` | Answer yes to every question. Needs `--tv` when the search finds more than one TV. |
| `--help` | Show the options |

With neither `--screensaver` nor `--logo`, both screens get this project's pictures. `./uninstall.sh` takes `--tv`, `--non-interactive`, and `--help` too.

## Picture tips

- **Crop your photos to 16:9 (widescreen) first** for the best fit. Any other shape gets cropped from the center to fill the screen, so edges may be cut off.
- 1920x1080 or larger looks best. The TV shows these screens at 1920x1080.
- **Logo:** a PNG with a transparent background looks best, and a light logo stands out on the black screen. The installer scales it to fit 640x320 on the 1920x1080 screen, about the size of LG's logo.
- **On a Mac without ImageMagick:**
  - macOS's built-in photo tool can't read the rotation setting that phones save, so a photo taken sideways can show sideways. Export your photos from the Photos app (File > Export) before adding them.
  - Empty space around a logo isn't trimmed, so crop your logo close to its edges first.
  - Or install [ImageMagick](https://imagemagick.org/) with `brew install imagemagick`, which handles both.

## About the shuffle helper

LG's no-signal screen picks a random painting every 10 seconds, so it can show the same one twice in a row. The shuffle helper fixes that and gives you the random order that repeats.

**Is it a listener? Is it spying on me?** No. It's a short Python script, [`tv/shuffle.py`](tv/shuffle.py), that you can read yourself. It runs on the TV, uses no network at all, and opens no ports. The only thing it watches is the screensaver's own photo folder on the TV. When the TV opens a photo from that folder, the helper lines up the next one.

To leave it out, add `--no-shuffle` when you install, for example `./install.sh --screensaver ~/Pictures/tv --no-shuffle`. The no-signal screen then shows your photos in random order (LG's way), using up to 16 photos.

## Good to know

- **Telnet:** Homebrew Channel's Telnet lets anyone on your home network control the TV, with no password. After installing, you can turn Telnet off in Homebrew Channel's settings, and your pictures keep working. Turn it back on when you want to update or uninstall.
- **Restarts:** your pictures stay after the TV restarts. Homebrew Channel turns them back on at every startup.
- **Timing:** the no-signal screen changes photos every 10 seconds with no fade. The idle screensaver changes photos every 15 seconds with a fade. The power-off logo fades in and out over about 2.5 seconds. The no-signal and power-off timing is LG's and can't be changed.
- **LG's files:** nothing in LG's system files changes. The tool lays your pictures over LG's screens, and uninstalling or turning off Homebrew Channel's startup scripts removes that layer.

## Tested on

| TV | Software version | webOS TV version | Result |
| --- | --- | --- | --- |
| LG OLED42C3PUA (2023) | 03.11.45 | 8.1.0-47 (webOS 23) | All three screens work |

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

**The no-signal screen still shows LG's paintings, or nothing**
- Make sure **No Signal Image** is on (see [Turn a screen on or off](#turn-a-screen-on-or-off)).
- Some TV models use a different set of art. Please open an issue with your model and webOS version.

**Turning the TV off still shows LG's logo, or no logo**
- Make sure **Show LG logo when turning off the TV** is on (see [Turn a screen on or off](#turn-a-screen-on-or-off)).
- Some TV models and special editions use a different logo. Please open an issue with your model and webOS version.

## How it works

For the curious:

- **Screensaver:** LG's screensaver is a small app. The tool mounts its own slideshow over the app's main file (`/usr/palm/applications/com.webos.app.screensaver/qml/main.qml`) with a Linux bind mount. Nothing in LG's file changes.
- **No-signal screen:** LG's HDMI input app shows the paintings `modernart_0.jpg` to `modernart_15.jpg` from `/mnt/lg/appstore/preload/igallery/files/data/modernart`, choosing one at random every 10 seconds. The tool mounts a folder of your photos over that folder under the same 16 names. The input app's own code can't be changed this way, because the TV restores it at startup from a snapshot made at the factory.
- **Shuffle helper:** all 16 names point to one photo. When the input app opens a name, the helper (using the Linux kernel's file notifications) points all 16 names at the next photo in the order. Whichever name LG picks, it gets the next photo.
- **Power-off screen:** when the TV turns off, LG's system UI shows `/usr/lib/qml/MasterBrand/LG_logo.png` centered on black (`LG_logo_4k.png` on TVs with 4K menus). The tool mounts your logo over both files. The system UI loads the logo fresh at every power-off, so the change shows the next time you turn the TV off.
- **Startup:** Homebrew Channel runs `/var/lib/webosbrew/init.d/50-webos-custom-screens` at every startup, which turns everything back on.
- **On the TV,** everything lives in `/media/developer/webos-custom-screens`.

## License

[MIT](LICENSE)
