class_name Changelog
extends RefCounted

## "What's new" for the versions this build knows about, shipped inside
## the game so the Updates screen works offline. Newest first. Same simple
## markdown as GitHub release notes (# headings, - bullets). Add an entry
## with every release (and bump config/version in project.godot).

const ENTRIES: Array = [
	["0.11.1", """# Faster, smoother, and a way to report bugs

# Performance
- Higher frame rates on weak computers, most on the bigger maps (Harbour, Mountain Lake, Village): the maps are drawn in fewer, bigger pieces, and fine details stop where they are only a pixel wide.
- High quality is faster too.
- "Low-res window" (Settings -> Graphics) runs the whole window at half resolution on Retina/HiDPI screens - the biggest speed-up for weak Macs (takes effect after a restart).
- The frame rate limit now goes down to 10 FPS.

# Loading
- A new loading screen: a picture of the map, what the game is doing right now, and tips. The first load of a map after an update takes longest - the game says so.
- Shaders are prepared while the loading screen is up, so the first flight no longer jerks when new things come into view.
- Fixed: "OUT OF RANGE" could appear right after loading.

# Fixes
- Fixed: on High with the Clean camera look some maps were black.
- Fullscreen or window: your choice is remembered. F11 or Alt+Enter switches at any time.
- Radio calibration: an arm switch that wasn't moved since the game started is recognised.
- Motor sound: no more quiet ticking in time with the motors.
- Village: the start cross on the mat shows from every distance.
- Flying with the keyboard: if you switched the key guide off, a short hint says how to get it back (H).
- Settings: the Static Whoop's render distance ends at 400 m (its camera sits very close to walls); the slider says so.

# New
- Report a bug: in the main menu and the pause menu. Write what happened, then copy it, send it as an email, or open a GitHub issue - the game info that helps me find the bug comes along if you want.
- Support me: if you want to support the project.
"""],
	["0.11.0", """# The Race Update

# Race mode: six tracks per race map
- Race Field, Race Arena and Office have six tracks each, from easy to hard: pick one from cards showing its layout, difficulty, gates, lap length and your best time with the drone you fly.
- Races are 2 laps. Miss a gate and the game tells you which one and which way to turn - fly back through it and the race goes on.
- A racing line shows the way to the next gates (Settings -> Flight: colour or off, Short / Medium / Long).
- Turn flags, split-S ladders, hairpins; green and red rings on every gate show which way to fly through. New gates and flags; indoor LED gates keep their colour.
- New finish card with your time, the difference to your best and the podium; a gold banner for a new track record.
- Records are kept per track and per drone. Redesigned tracks start with fresh records; your old times stay in the save file.
- Village courses: short timed laps through the village.

# Maps
- Rebuilt: Harbour, Race Field, Race Arena, Office, and the Construction Site as a company campus under construction.
- Mountain Lake: a dam outlet and river, a spring and creek, a real waterfall into the lake; the hotel now stands along the road instead of in it.
- Steel Mill: the blast furnaces' top houses no longer float in the air.
- Nothing small floats any more either: hall lamps hang from cables, benches, tables and chairs have legs, railings have posts, torpedo wagons are joined up, window panes sit on walls.
- Detailed cars and trains, new street lamps and road signs, entrances instead of turning circles, easter eggs on ten maps, a church clock that shows the real time.

# Flight and settings
- R always resets the drone, also while the radio's reset switch is on.
- Optional water damage. Keyboard flying improved. Settings pages scroll.
- The screen no longer dims during long flights with a radio.
- "Full 3D resolution" replaces "Full screen resolution": menus and text always stay sharp; turning it off lowers only the 3D picture, at once, without a restart.
- Four harder achievements: race every map, the hardest track of every race map, every track with every drone, and fly every drone.
- Harbour: the high-speed train got a long, rounded nose.

# Updates and privacy
- A first-start card asks two things: check for updates (on, once a day; the game sends no personal data, GitHub sees your IP address as with any website) and whether it may count your first start ("Yes, count me" / "No thanks"; with Yes the game sends its version and operating system once - no ID, no IP address stored). The update check can be changed under Updates, the count in Settings.
- From 0.11.0 the game can download and install updates itself (signed update packs). 0.10.1 has no update code, so coming from 0.10.1 please download 0.11.0 by hand once; automatic updates start from 0.11.0.
"""],
	["0.10.1", """# Fixes and a higher sky
- A reset switch on the radio no longer keeps the drone pinned to the start while the switch stays on.
- Resetting the drone close to the start gate now also restarts the race at the first gate.
- You can fly up to 250 m on the outdoor maps (higher on Harbour and Mountain Lake), and the haze thins with height so you can see the map from up there.
- Grass no longer pops in a moment after a map loads.
- New VSync switch (Settings -> Screen). On (default) is smooth and stops at your screen's refresh rate; off lets "Unlimited" go past 60 FPS on strong PCs.
- The dust specks in the air on Medium and High are gone.
- Trees no longer vanish for a moment in patches while you fly, and they stand still (no more swaying).
- Turning away from the sun quickly no longer leaves a glare fading in the middle of the screen.
- Faster everywhere, same picture: the 3D view, camera look, lens and sun glare now reach the screen in one step instead of three (Village on a 2015 MacBook at full Retina resolution: 28 to 43 FPS).
- New in Settings -> Screen: "Full screen resolution". Switched off, Retina and other high-resolution screens draw the HUD, menus and camera effects at half the pixels, which is faster on weak graphics.
- The mouse cursor no longer stays visible over the flight view after switching apps.
- The camera angle and FOV sliders in Settings work during a flight too, and stay in step with the ones in the pause menu.
- Mountain Lake: no more stripes across the lake's water.
- The Whoop no longer starts under the launch mat (Village) or under the pier (Mountain Lake).
- A gnome you found turns grey for a few seconds, then looks like itself again.
- The licences of the game, its font and the Godot Engine are now under About.
- The game is now called Static Horizon FPV Simulator. Your settings, radio calibration, records, ghosts and found gnomes are carried over.
"""],
	["0.10.0", """# New maps, camera looks and realism options
- Rebuilt maps: a new Village with a church tower to fly up, a railway viaduct and a ruined bando; a working Factory with a fly-through hall and cooling tower; Mountain Lake; and the Abandoned Steel Mill, now properly derelict.
- Camera looks: Analog, Digital and HDZero, each breaking up like the real thing when walls, hills or distance come between you and the drone.
- Optional realism: battery sag with Betaflight-style voltage warnings, prop damage after hard crashes, and wind with gusts.
- A ghost of your best lap in Race mode.
- Garden gnomes are hiding on the maps - find them all (Achievements).
- Closer detail on the ground, grass around the drone, sun glare, warmer haze and better clouds.
- Maps load much faster after the first time and use less memory.
- The game tells you quietly when a new version is out (Updates in the menu; can be switched off).
"""],
	["0.9.0", """# First public release
- Four drones with real masses and thrust: Static Three, Static Five, Static Race and Static Whoop.
- Twelve maps, from a fly-through village and a steelworks to a port city, an alpine lake and an office after hours.
- Freestyle and Race modes: three-lap races, live gate splits, personal bests and a top five per track.
- Betaflight rates (Actual, Betaflight, Quick, KISS), throttle MID/EXPO, airmode, and a flight model with motor lag, prop wash and ground effect.
- Fly with your own radio in USB joystick mode: calibration wizard, arm switch and extra switches you assign.
- Replay of the last minute (P), stick overlay, fisheye lens and a line-of-sight view.
"""],
]

static func notes_for(version: String) -> String:
	for e in ENTRIES:
		if e[0] == version:
			return e[1]
	return ""
