class_name Battery
extends RefCounted

## A LiPo pack for the OSD and (with Settings.battery_enabled) for thrust:
## charge drains with the current the motors draw, the resting voltage
## follows a real LiPo discharge curve, and the loaded voltage sags by
## current x internal resistance plus a slower polarisation part (the
## voltage creeps down during a long punch and recovers over seconds
## afterwards - what a pilot sees in the OSD after landing).
##
## Model (2026-10-04, Round 2):
##   V_cell = OCV(charge) - I * R(charge) - V_p,   dV_p/dt = (I * R_p - V_p) / TAU_P
##   I      = I_electronics + I_hover * (thrust / hover thrust)^n
## n is fitted per drone through two real points: the hover current and
## the full-throttle burst current (motor bench tables), so the current
## curve is right at both ends (n comes out 0.8-1.5 - small ducted props
## are inefficient at hover, big open props scale close to momentum
## theory's power ~ thrust^1.5).
##
## Thrust: a prop's thrust goes with rpm^2 (T = C_T * rho * n^2 * D^4,
## standard propeller theory), and a brushless motor's rpm at a given
## ESC duty goes with the voltage it gets (rpm ~ KV * duty * V). So at
## the same stick, thrust ~ V^2. Betaflight doesn't compensate by
## default (vbat_sag_compensation = 0), so a drained pack really does
## feel weaker. The flight model's thrust numbers are what a FRESH pack
## gives (they were tuned to real flight claims, sag included), so the
## factor is (V now / V of a fresh pack at the same current)^2 - 1.0 on a
## fresh pack at any throttle, the default feel untouched.
##
## Sources: resting voltage per state of charge - the widely published
## LiPo chart (4.20 V full, 3.84 V at 50%, 3.69 V at 10%, 3.27 V empty;
## e.g. oscarliang.com "LiPo battery guide", rcgroups/ultimatelipo
## charts); Betaflight's battery warnings: vbat_warning_cell_voltage
## 3.5 V ("LOW BATTERY"), vbat_min_cell_voltage 3.3 V ("LAND NOW" -
## betaflight.com/docs/wiki/guides/current/Battery). Internal resistance:
## typical per-cell values for good FPV packs (~6-12 mOhm for 850-1300 mAh
## 75-120C, ~30 mOhm for a 1S 450-550 mAh whoop pack), checked against
## the sag pilots see in blackbox logs (a fresh 4S/6S pack punched from
## ~4.2 to ~3.5-3.6 V per cell). Hover/burst currents: ESTIMATES from
## typical flight times (whoop ~6-7 min on 480 mAh, 3" 4S 850 ~5-6 min,
## 5" 6S 1300 ~4-5 min freestyle) and bench tables for the motor classes
## (0802 1S ~4 A, 1404 4S ~15 A, 2207 6S ~35-40 A per motor at 100%).

const PACKS := {
	# 1S 480 mAh LiHV (BT2.0 whoop packs are high-voltage: 4.35 V full).
	"whoop": {"cells": 1, "mah": 480.0, "hv": true, "hover_a": 3.0, "max_a": 16.0, "r_cell": 0.03, "idle_a": 0.3},
	"seeker3": {"cells": 4, "mah": 850.0, "hover_a": 5.0, "max_a": 60.0, "r_cell": 0.010, "idle_a": 0.4},
	"five": {"cells": 6, "mah": 1300.0, "hover_a": 6.5, "max_a": 130.0, "r_cell": 0.006, "idle_a": 0.5},
	"race": {"cells": 6, "mah": 1100.0, "hover_a": 4.5, "max_a": 120.0, "r_cell": 0.007, "idle_a": 0.5},
}
## Resting cell voltage by state of charge (standard LiPo, see above).
const CURVE: Array[Vector2] = [Vector2(0.0, 3.27), Vector2(0.05, 3.61), Vector2(0.1, 3.69), Vector2(0.2, 3.73),
	Vector2(0.3, 3.77), Vector2(0.4, 3.80), Vector2(0.5, 3.84), Vector2(0.6, 3.87), Vector2(0.7, 3.95),
	Vector2(0.8, 4.02), Vector2(0.9, 4.11), Vector2(1.0, 4.20)]
## Betaflight's defaults.
const LOW_CELL_V: float = 3.5
const CRITICAL_CELL_V: float = 3.3
## Past 0% the cells collapse: over this much more capacity (fraction)
## the pack can't hold the motors up any more - the quad sinks down.
const TAIL: float = 0.03
## Polarisation: part of the sag builds up and recovers over seconds.
const R_POLAR: float = 0.4 ## x r_cell
const TAU_P: float = 8.0 ## s
## The warnings read a filtered voltage (Betaflight filters vbat too), so
## a one-second punch doesn't flash LOW BATTERY on a full pack.
const WARN_TAU: float = 2.0

var cells: int = 4
var capacity_mah: float = 850.0
var hv: bool = false
var hover_a: float = 5.0
var max_a: float = 60.0
var idle_a: float = 0.4
var r_cell: float = 0.01
var hover_fraction: float = 0.14 ## hover thrust / max thrust, from the frame
var exponent: float = 1.3
var used_mah: float = 0.0
var current_a: float = 0.0
var cell_v: float = 4.2 ## under load
var warn_v: float = 4.2 ## filtered, for the warnings
var _vp: float = 0.0

func setup(profile: String) -> void:
	var p: Dictionary = PACKS.get(profile, PACKS["seeker3"])
	cells = p.cells
	capacity_mah = p.mah
	hv = p.get("hv", false)
	hover_a = p.hover_a
	max_a = p.max_a
	idle_a = p.idle_a
	r_cell = p.r_cell
	var d: Dictionary = Drone.PROFILES.get(profile, Drone.PROFILES["seeker3"])
	hover_fraction = clampf(d.mass * 9.8 / (4.0 * d.max_motor_thrust_n), 0.02, 0.9)
	# Through (hover_fraction, hover_a) and (1, max_a).
	exponent = log(max_a / hover_a) / log(1.0 / hover_fraction)
	reset()

## A fresh pack (Reset / R).
func reset() -> void:
	used_mah = 0.0
	current_a = 0.0
	_vp = 0.0
	cell_v = rest_cell_v()
	warn_v = cell_v

## thrust_fraction: total thrust / total max thrust this step.
func step(delta: float, thrust_fraction: float, armed: bool) -> void:
	var f: float = clampf(thrust_fraction, 0.0, 1.0)
	current_a = idle_a + (hover_a * pow(f / hover_fraction, exponent) if armed and f > 0.0 else 0.0)
	used_mah += current_a * delta / 3.6
	_vp += (current_a * r_cell * R_POLAR - _vp) * (1.0 - exp(-delta / TAU_P))
	cell_v = rest_cell_v() - current_a * resistance() - _vp
	warn_v += (cell_v - warn_v) * (1.0 - exp(-delta / WARN_TAU))

## 1 full .. 0 at the rated capacity (it can go a little past, see TAIL).
func charge() -> float:
	return clampf(1.0 - used_mah / capacity_mah, 0.0, 1.0)

## Internal resistance rises as the pack runs low (roughly constant down
## to ~20%, up to ~1.8x at empty).
func resistance() -> float:
	return r_cell * (1.0 + 0.8 * (1.0 - smoothstep(0.0, 0.2, charge())))

func rest_cell_v(c: float = -1.0) -> float:
	var own: bool = c < 0.0
	if own:
		c = charge()
	var v: float = CURVE[-1].y
	for i in range(CURVE.size() - 1):
		if c <= CURVE[i + 1].x:
			v = lerpf(CURVE[i].y, CURVE[i + 1].y, (c - CURVE[i].x) / (CURVE[i + 1].x - CURVE[i].x))
			break
	if hv:
		v += 0.15 * c # LiHV: 4.35 V full, the same 3.3 V-ish empty
	# Over-discharged: the curve falls off a cliff.
	var over: float = used_mah / capacity_mah - 1.0
	if own and over > 0.0:
		v -= 0.5 * clampf(over / TAIL, 0.0, 1.0)
	return v

func pack_v() -> float:
	return cell_v * cells

## Past the rated capacity (and the short tail): no more flying.
func is_empty() -> bool:
	return used_mah >= capacity_mah

func is_low() -> bool:
	return warn_v < LOW_CELL_V or is_empty()

func is_critical() -> bool:
	return warn_v < CRITICAL_CELL_V or is_empty()

## OSD warning text ("" = none), Betaflight's words.
func warning() -> String:
	if is_empty():
		return "BATTERY EMPTY"
	if is_critical():
		return "LAND NOW"
	if is_low():
		return "LOW BATTERY"
	return ""

## Thrust scale from the pack: 1.0 on a fresh pack at any throttle, ~V^2
## as it drains (see the class docs); fading to 0.15 over the tail past
## empty, so the quad comes down.
func thrust_factor() -> float:
	var fresh: float = rest_cell_v(1.0) - current_a * r_cell
	var k: float = clampf(pow(maxf(cell_v, 0.0) / maxf(fresh, 0.1), 2.0), 0.0, 1.0)
	var over: float = used_mah / capacity_mah - 1.0
	if over > 0.0:
		k *= lerpf(1.0, 0.15, clampf(over / TAIL, 0.0, 1.0))
	return k
