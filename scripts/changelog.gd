class_name Changelog
extends RefCounted

## "What's new" for the versions this build knows about, shipped inside
## the game so the Updates screen works offline. Newest first. Same simple
## markdown as GitHub release notes (# headings, - bullets). Add an entry
## with every release (and bump config/version in project.godot).

const ENTRIES: Array = [
	["0.10.1", """# Fixes and a higher sky
- A reset switch on the radio no longer keeps the drone pinned to the start while the switch stays on.
- Resetting the drone close to the start gate now also restarts the race at the first gate.
- You can fly up to 250 m on the outdoor maps (higher on Harbour and Mountain Lake), and the haze thins with height so you can see the map from up there.
- Grass no longer pops in a moment after a map loads.
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
