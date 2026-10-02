class_name MapCatalog
extends RefCounted

## Every map in one place. The map picker, the pause menu's drone lock,
## the loading screen title and the self-test all read this list, so
## adding a map is one entry here plus its scene.
##
## tier: how demanding the map is to render - "Low" runs on anything
## (4 GB RAM, integrated graphics), "Medium" wants a mid-range laptop,
## "High" is the showcase tier (big, detailed, full effects).
## drone: "any", or the one profile id the map forces (indoor whoop
## maps - a 650 g five-inch has no business in a school corridor).

const TIERS: Array[String] = ["Low", "Medium", "High"]
const TIER_COLORS := {"Low": Color("#3fae5a"), "Medium": Color("#e0a526"), "High": Color("#e8551a")}

const MAPS: Array[Dictionary] = [
	{"id": "village", "name": "Village", "scene": "res://scenes/Main.tscn", "tier": "Medium", "drone": "any",
	 "color": Color("#3f8f4a"),
	 "text": "Main street with houses you can fly into, a church, an FPV club field with gates, a railway underpass and a farm."},
	{"id": "factory", "name": "Factory", "scene": "res://scenes/Main2.tscn", "tier": "Medium", "drone": "any",
	 "color": Color("#e8551a"),
	 "text": "A working plant: rail yard and dock, fly-through production halls, a boiler house, chimneys, tanks and pipe bridges."},
	{"id": "school", "indoor": true, "name": "School", "scene": "res://scenes/Main3.tscn", "tier": "Low", "drone": "whoop",
	 "color": Color("#1f6fe0"),
	 "text": "A full-size sports hall with goals, ropes and hoops, a long corridor and furnished classrooms. Indoors only."},
	{"id": "steelmill", "name": "Abandoned Steel Mill", "scene": "res://scenes/maps/SteelMill.tscn", "tier": "High", "drone": "any",
	 "color": Color("#b5552b"),
	 "text": "After the Völklinger Hütte: six blast furnaces in a row, skip hoists to the tops, a column slalom under the bunker hall, hollow gas mains, the ore monorail."},
	{"id": "playground", "name": "Playground", "scene": "res://scenes/maps/Playground.tscn", "tier": "Low", "drone": "whoop",
	 "color": Color("#e0a526"),
	 "text": "Slides, swings, a climbing frame and a tunnel tube - a whoop playground."},
	{"id": "race_field", "race": true, "track": 2, "name": "Race Field", "scene": "res://scenes/maps/RaceField.tscn", "tier": "Low", "drone": "any",
	 "color": Color("#1f6fe0"),
	 "text": "A 12-gate MultiGP lap round the whole field: a climb through the ladder, two dive gates, a tower gate, hurdles and turn flags."},
	{"id": "race_arena", "race": true, "track": 2, "indoor": true, "name": "Race Arena", "scene": "res://scenes/maps/RaceArena.tscn", "tier": "Medium", "drone": "any",
	 "color": Color("#c03fd0"),
	 "text": "League night indoors: glowing LED gates in a dark hall, a tunnel, a ladder, a dive, a scaffold tower gate and a gate hung from the roof."},
	{"id": "office", "race": true, "track": 2, "indoor": true, "name": "Office Whoop Race", "scene": "res://scenes/maps/Office.tscn", "tier": "Low", "drone": "whoop",
	 "color": Color("#6c7a89"),
	 "text": "After hours on the 5th floor: whoop gates between the desks, a glass meeting room, the kitchen - and the city below the windows."},
	{"id": "garage", "name": "Parking Garage", "scene": "res://scenes/maps/ParkingGarage.tscn", "tier": "Medium", "drone": "any",
	 "color": Color("#8a8f98"),
	 "text": "An abandoned multi-storey car park: tight decks, ramps, collapsed slabs to dive through, broken parapets to punch out of."},
	{"id": "construction", "name": "Construction Site", "scene": "res://scenes/maps/ConstructionSite.tscn", "tier": "High", "drone": "any",
	 "color": Color("#e0a526"),
	 "text": "A high-rise going up in the city: fly through its open floors, round two tower cranes, down the 12 m pit, through a steel frame and under the railway arches."},
	{"id": "harbour", "name": "Harbour & Central Station", "scene": "res://scenes/maps/Harbour.tscn", "tier": "High", "drone": "any",
	 "color": Color("#2a7fb0"),
	 "text": "A port city at sunset: container cranes and ships, a rail branch into the terminal, a through station with a glass train shed, the old harbour and the city grid."},
	{"id": "mountain_lake", "name": "Mountain Lake", "scene": "res://scenes/maps/MountainLake.tscn", "tier": "High", "drone": "any",
	 "color": Color("#3a9a8a"),
	 "text": "An alpine lake in the evening alpenglow: surf the ridges, skim the water, dive the dam, chase the waterfall and the cable car."},
]

## Race maps (a timed course): the only maps in Race mode; in Freestyle
## they're flown without the timer like any other map.
static func is_race(m: Dictionary) -> bool:
	return m.get("race", false)

## Maps whose scene exists in this build.
static func available() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in MAPS:
		if ResourceLoader.exists(m.scene):
			out.append(m)
	return out

static func for_scene(path: String) -> Dictionary:
	for m in MAPS:
		if m.scene == path:
			return m
	return {}

## The drone profile a map insists on, or "" if any drone may fly it.
static func forced_drone(scene_path: String) -> String:
	var m := for_scene(scene_path)
	return "" if m.is_empty() or m.drone == "any" else m.drone

## Which tier suits the current graphics setting (Low/Medium/High
## quality -> Low/Medium/High maps).
static func recommended_tier() -> String:
	return TIERS[clampi(Settings.graphics_quality, 0, 2)]
