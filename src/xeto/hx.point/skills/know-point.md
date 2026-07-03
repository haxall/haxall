# Know Point

Points model sensors, commands, and setpoints. A point rec combines
a value type with up to three facets: **cur** (real-time value),
**his** (history), and **writable** (command output). Each facet
adds its own runtime status tags.

# Point Recs

Required tags:
- `spec`: subtype of `ph::Point`, typically spec from `ph.points`
- `point`: marker
- `kind`: value type - "Number", "Bool", or "Str"
- `unit`: required for Number points
- `tz`: required for historized points

Facet markers and their transient status tags:
- `cur`: `curVal`, `curStatus`, `curErr`
- `his`: `hisStatus`, `hisErr`
- `writable`: `writeVal`, `writeLevel`, `writeStatus`, `writeErr`

Status values: `ok`, `stale` (cur only), `down`, `fault`,
`disabled`, `unknown`, plus `remoteDown/Fault/Disabled/Unknown`
for cur points behind a remote connector.

All facet tags are transient: they live in memory and reset on
restart (except priority array levels 1, 8, and def - see below).

# Cur Values

`curVal`/`curStatus` are maintained by connectors (via watch
subscription or explicit sync). The connector framework marks a
point `stale` when it is unwatched and unread past the tuning
`staleTime` (default 5min).

The `curTracksWrite` marker makes `curVal` mirror the point's
effective write value with `curStatus:"ok"` - useful for writable
points with no connector feedback. It should not be used if curVal
is bound to a connector.

# Writable Points

Writable points (use only on `cmd`/`sp` points, never sensors) have
a 16-level priority array plus relinquish default:

- Level 1: emergency override (highest priority)
- Levels 2-7: high priority applications
- Level 8: manual operator override, supports timed override
- Levels 9-16: schedules and applications
- Level 17 ("def"): relinquish default, used when levels 1-16 are
  all null

The effective `writeVal`/`writeLevel` is the first non-null value
scanning level 1 to 17. Writing null to a level releases it ("auto")
so the next level wins. Only levels 1, 8 (untimed), and def persist
across restart; all other levels must be rewritten by their
application on startup.

```axon
pointWrite(pt, 72°F, 16, "myApp")    // write level 16 with who
pointWrite(pt, null, 16, "myApp")    // release level 16
pointOverride(pt, 75°F)              // level 8 manual override
pointOverride(pt, 75°F, 30min)       // timed: auto-releases after 30min
pointAuto(pt)                        // release level 8
pointEmergencyOverride(pt, 60°F)     // level 1
pointEmergencyAuto(pt)               // release level 1
pointSetDef(pt, 70°F)                // level 17 relinquish default
pointWriteArray(pt)                  // grid of all 17 levels
```

Write rules:
- Requires admin and the `writable` marker
- Value must match `kind` exactly; unitless numbers inherit the
  point's `unit`, mismatched units throw
- The `who` argument is stored per level for auditing (defaults to
  the current user)
- Use `pointWriteArray(pt)` to debug "why is this point commanded
  to this value" - it shows every level, who set it, and timed
  override expiration

The `obsPointWrites` observable fires when the effective value
changes (not on every level write), so tasks can react to command
changes.

# History Collection

Local history collection samples `curVal` into the historian.
Configure with either or both:

- `hisCollectInterval`: periodic sampling; must divide evenly into
  a minute, hour, or day (15sec, 5min, 1hr ok; 7min not)
- `hisCollectCov`: change of value; marker collects any change, a
  number collects when the change exceeds that tolerance (Numbers
  only)

Both may be combined - whichever condition hits first collects.
Practical guidance: bool/enum/setpoint points use `hisCollectCov`
plus a 1day interval heartbeat; numeric sensors use an interval of
1-15min.

Behaviors:
- COV is always rate limited (default 1/10 of the interval, capped
  at 1min); override with `hisCollectCovRateLimit`
- Bad data (`curVal` null or `curStatus` not "ok") is skipped
  unless the `hisCollectNA` marker is set, which logs NA instead
- `hisCollectWriteFreq` buffers items in memory and flushes on
  that period for better storage efficiency; force a flush with
  `hisCollectWriteAll()`

# Enum Points

Bool and Str points with enumerated states use enum definitions:

- Project-wide: the singleton `enumMeta` rec maps named enum grids
  with `name`/`code` columns
- Per-point: the `enum` tag with comma separated names, e.g.
  `enum:"off,slow,fast"` (ordinals 0, 1, 2) - referenced as "self"

Conversion funcs: `enumStrToNumber`, `enumNumberToStr`,
`enumStrToBool`, `enumBoolToStr`; list definitions with
`enumDefs()` / `enumDef(id)`. Bool mapping: the first zero code is
false, the first non-zero code is true. Duplicate codes are
allowed; reverse lookup returns the first match.

# Point Conversions

Connectors normalize raw values with conversion strings on the
`curConvert`, `writeConvert`, and `hisConvert` tags. A conversion
is a left-to-right pipeline:

```axon
"* 100 + 75"                     // scale and offset
"°C => °F"                       // unit conversion
"as(°F)"                         // relabel unit, no conversion
"strToNumber() ?: 0"             // parse with null fallback
"numberToBool()"                 // 0=false, non-zero=true
"enumNumberToStr(speed)"         // enum code to name
"thermistor(10k-2)"              // resistance table decode
"& 0xFF >> 2"                    // bitwise ops
```

Test a conversion with `pointConvert(pt, "°C => °F", 20°C)`.

# Navigation Utilities

```axon
toPoints(recs)          // map site/space/equip recs to their points
equipToPoints(equip)    // points of one equip
toEquips(recs)          // map recs to equips
toOccupied(rec)         // find the occupied point for a rec
matchPointVal(val, 0..40)  // match value: exact, bool, range, func
pointDetails(pt)        // debug report: write array + his collect state
```

# Style Notes

- Writing null releases a priority level; it never writes zero
- Never assume levels 2-7/9-16 survive a restart; applications
  must rewrite them
- Without `curTracksWrite`, curVal and writeVal are independent
- Start any writable-point investigation with `pointWriteArray`
  and any point investigation with `pointDetails`

