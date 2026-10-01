class_name Rates
extends RefCounted

## Betaflight's rate types, with Betaflight's own formulas - so a pilot
## can type in the exact numbers from their quad's PID Tuning -> Rates
## tab and it flies the same. Ported from Betaflight 4.x
## src/main/fc/rc.c (applyBetaflightRates, applyActualRates,
## applyQuickRates, applyKissRates). Values are stored the way the
## Configurator shows them (RC Rate 1.00, Super Rate 0.70, Center 70,
## Max 670, Expo 0.54...), per axis: roll, pitch, yaw.

enum { BETAFLIGHT, ACTUAL, QUICK, KISS }
const TYPE_NAMES: Array[String] = ["Betaflight", "Actual", "Quick", "KISS"]
const AXIS_NAMES: Array[String] = ["Roll", "Pitch", "Yaw"]
const RC_RATE_INCREMENTAL: float = 14.54
const SETPOINT_RATE_LIMIT: float = 1998.0

## Per type: the three columns' names, ranges [min, max, step] and the
## Configurator's defaults for that type.
const COLUMNS := {
	BETAFLIGHT: [["RC Rate", 0.01, 2.55, 0.01], ["Super Rate", 0.0, 1.0, 0.01], ["RC Expo", 0.0, 1.0, 0.01]],
	ACTUAL: [["Center Sensitivity", 10.0, 2000.0, 10.0], ["Max Rate", 0.0, 2000.0, 10.0], ["Expo", 0.0, 1.0, 0.01]],
	QUICK: [["RC Rate", 0.01, 2.55, 0.01], ["Max Rate", 0.0, 2000.0, 10.0], ["Expo", 0.0, 1.0, 0.01]],
	KISS: [["RC Rate", 0.01, 2.55, 0.01], ["Rate", 0.0, 0.99, 0.01], ["RC Curve", 0.0, 1.0, 0.01]],
}
const DEFAULTS := {
	BETAFLIGHT: [1.0, 0.7, 0.0],
	ACTUAL: [70.0, 670.0, 0.54],
	QUICK: [1.0, 670.0, 0.0],
	KISS: [1.0, 0.7, 0.0],
}

## Well-known starting points (all Actual rates, roll = pitch).
const PRESETS: Array = [
	["Betaflight default", ACTUAL, [70.0, 670.0, 0.54], [70.0, 670.0, 0.54]],
	["Smooth cinematic", ACTUAL, [120.0, 450.0, 0.3], [100.0, 350.0, 0.3]],
	["Freestyle", ACTUAL, [200.0, 800.0, 0.45], [200.0, 650.0, 0.35]],
	["Racing", ACTUAL, [250.0, 720.0, 0.2], [250.0, 600.0, 0.2]],
	["Beginner", ACTUAL, [70.0, 400.0, 0.2], [70.0, 300.0, 0.2]],
]

## Rotation rate in deg/s for stick -1..1 on one axis.
static func rate_deg(type: int, v: Array, stick: float) -> float:
	var x: float = clampf(stick, -1.0, 1.0)
	var a: float = absf(x)
	match type:
		BETAFLIGHT:
			var cmd: float = x
			if v[2] > 0.0:
				cmd = x * pow(a, 3.0) * v[2] + x * (1.0 - v[2])
			var rc: float = v[0]
			if rc > 2.0:
				rc += RC_RATE_INCREMENTAL * (rc - 2.0)
			var r: float = 200.0 * rc * cmd
			if v[1] > 0.0:
				r *= 1.0 / clampf(1.0 - a * v[1], 0.01, 1.0)
			return clampf(r, -SETPOINT_RATE_LIMIT, SETPOINT_RATE_LIMIT)
		QUICK:
			var rc_rate: float = v[0] * 200.0
			var max_dps: float = maxf(v[1], rc_rate)
			var cfg: float = (max_dps / rc_rate - 1.0) / (max_dps / rc_rate)
			var curve: float = pow(a, 3.0) * v[2] + a * (1.0 - v[2])
			var sf: float = 1.0 / clampf(1.0 - curve * cfg, 0.01, 1.0)
			return clampf(x * rc_rate * sf, -SETPOINT_RATE_LIMIT, SETPOINT_RATE_LIMIT)
		KISS:
			var use: float = 1.0 / clampf(1.0 - a * v[1], 0.01, 1.0)
			var k: float = (pow(x, 3.0) * v[2] + x * (1.0 - v[2])) * (v[0] / 10.0)
			return clampf(2000.0 * use * k, -SETPOINT_RATE_LIMIT, SETPOINT_RATE_LIMIT)
	# ACTUAL:  expof = |x| * (x^5 * expo + x * (1 - expo)),
	#          rate  = x * center + max(0, max - center) * expof
	var expof: float = a * (pow(x, 5.0) * v[2] + x * (1.0 - v[2]))
	return x * v[0] + maxf(0.0, v[1] - v[0]) * expof

## Max rate (full stick) of an axis, deg/s.
static func max_deg(type: int, v: Array) -> float:
	return rate_deg(type, v, 1.0)

## Converts one axis to another rate type, keeping its feel: matches the
## centre slope and the full-stick rate of the old curve as closely as
## the new type's numbers allow.
static func convert(from: int, v: Array, to: int) -> Array:
	if from == to:
		return v.duplicate()
	var center: float = rate_deg(from, v, 0.1) * 10.0
	var top: float = rate_deg(from, v, 1.0)
	var out: Array = DEFAULTS[to].duplicate()
	match to:
		ACTUAL:
			out = [snappedf(center, 10.0), snappedf(top, 10.0), 0.5]
		QUICK:
			out = [snappedf(center / 200.0, 0.01), snappedf(top, 10.0), 0.3]
		BETAFLIGHT, KISS:
			var rc: float = clampf(center / 200.0, 0.01, 2.0)
			# full stick: 200 * rc / (1 - super) = top
			var sup: float = clampf(1.0 - 200.0 * rc / maxf(top, 1.0), 0.0, 0.95)
			out = [snappedf(rc, 0.01), snappedf(sup, 0.01), 0.0]
	return out
