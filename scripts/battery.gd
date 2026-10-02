class_name Battery
extends RefCounted

## A LiPo pack for the OSD and (optionally) for thrust: charge drains
## with current, resting voltage follows a typical LiPo discharge curve,
## and the loaded voltage sags by current x internal resistance - the
## number a pilot watches in the OSD to know when to land.
##
## Packs are typical real ones for each frame class: a 1S 480 mAh for
## the whoop, 4S 850 mAh for the 3-inch (the Seeker3 class flies 4S
## 650-850), 6S 1300 mAh for the 5-inch. Max current and per-cell
## resistance are round typical values for those packs, not one brand.

const PACKS := {
	"whoop": {"cells": 1, "mah": 480.0, "max_a": 12.0, "r_cell": 0.05}, # 1S 480 mAh, 12 A ESC
	"seeker3": {"cells": 4, "mah": 850.0, "max_a": 70.0, "r_cell": 0.014},
	"five": {"cells": 6, "mah": 1300.0, "max_a": 130.0, "r_cell": 0.009},
}
## Resting cell voltage by state of charge (LiPo, rough but typical).
const CURVE: Array[Vector2] = [Vector2(0.0, 3.3), Vector2(0.1, 3.55), Vector2(0.25, 3.7), Vector2(0.5, 3.82), Vector2(0.8, 4.0), Vector2(1.0, 4.2)]
const LOW_CELL_V: float = 3.5

var cells: int = 4
var capacity_mah: float = 850.0
var max_current: float = 70.0
var r_cell: float = 0.014
var used_mah: float = 0.0
var current_a: float = 0.0
var cell_v: float = 4.2 ## under load

func setup(profile: String) -> void:
	var p: Dictionary = PACKS.get(profile, PACKS["seeker3"])
	cells = p.cells
	capacity_mah = p.mah
	max_current = p.max_a
	r_cell = p.r_cell
	reset()

func reset() -> void:
	used_mah = 0.0
	current_a = 0.0
	cell_v = rest_cell_v()

## thrust_fraction: total thrust / total max thrust. Current rises
## faster than thrust (motor power ~ thrust^1.5), plus a small idle draw
## for the flight controller, VTX and camera.
func step(delta: float, thrust_fraction: float, armed: bool) -> void:
	current_a = (max_current * pow(clampf(thrust_fraction, 0.0, 1.0), 1.5) if armed else 0.0) + 0.4
	used_mah += current_a * delta / 3.6
	cell_v = rest_cell_v() - current_a * r_cell

func charge() -> float:
	return clampf(1.0 - used_mah / capacity_mah, 0.0, 1.0)

func rest_cell_v() -> float:
	var c: float = charge()
	for i in range(CURVE.size() - 1):
		if c <= CURVE[i + 1].x:
			return lerpf(CURVE[i].y, CURVE[i + 1].y, (c - CURVE[i].x) / (CURVE[i + 1].x - CURVE[i].x))
	return CURVE[-1].y

func pack_v() -> float:
	return cell_v * cells

func is_low() -> bool:
	return cell_v < LOW_CELL_V and current_a < max_current * 0.3 or rest_cell_v() < LOW_CELL_V + 0.1

## Motor thrust scales with voltage squared at a given throttle; 1.0 on a
## fresh pack at moderate load, less as it drains and sags.
func thrust_factor() -> float:
	return clampf(pow(cell_v / 4.05, 2.0), 0.5, 1.0)
