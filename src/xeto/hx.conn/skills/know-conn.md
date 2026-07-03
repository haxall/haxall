# Know Conn

The connector framework integrates remote systems. Each protocol
ships as its own lib (hx.haystack, hx.modbus, hx.mqtt, hx.sql, ...)
plugged into a common framework: a *conn* rec models the connection,
*points* bind to it with protocol address tags, and the framework
manages three data flows - cur, write, and his sync.

# Conn Recs

A conn rec has the `conn` marker plus its protocol marker:

```trio
haystackConn
conn
dis: "Main Haystack Server"
uri: `http://server/api/demo/`
username: "su"
```

Never put passwords in recs; store them with
`passwordSet(connId, "secret")`.

Runtime status (transient tags):
- `connStatus`: unknown, ok, down (network problem), fault (config
  problem), disabled, plus remoteDown/Fault/Disabled/Unknown when
  the remote system reports the error
- `connState`: closed, opening, open, closing
- `connErr`: error message when status is an error

Lifecycle tags: `disabled` marker pauses the conn; `connPingFreq`
enables periodic auto-ping; `connLinger` (default 30sec) controls
how long a connection stays open after use; `actorTimeout` (default
1min) bounds every operation.

# Point Binding

Points bind to a conn with protocol-specific tags following a
uniform naming pattern - `{protocol}ConnRef` plus one address tag
per facet:

```trio
point
kind: "Number"
unit: "°F"
haystackConnRef: @conn-id
haystackCur: "remote-point-id"     // enables cur sync
haystackWrite: "remote-point-id"   // enables write flow
haystackHis: "remote-point-id"     // enables his sync
```

The presence of each address tag enables that facet's flow. Not
every protocol supports all three: modbus has cur/write only, sql
is his-only, mqtt maps pub/sub topics.

Normalize raw values with conversion tags (see the know-point
conversion pipeline): `curConvert`, `writeConvert`, `hisConvert`,
plus `curCalibration` (number added to converted cur value).

# Lifecycle

Connections open on demand and auto-close after `connLinger`
(default 30sec); the framework pins connections open while points
are watched and retries downed conns every `connOpenRetryFreq`.

```axon
connPing(conn)     // open + ping; updates product/vendor tags
connClose(conn)    // force close
connLearn(conn)    // discovery (see Learn below)
```

# Cur Flow

Cur values sync while points are in a watch (opening a view or
`watchOpen` puts them there). The framework polls or subscribes per
the protocol: bucket polling groups points by tuning and polls each
bucket at its `pollTime`; some protocols poll manually or use
subscriptions. One-time sync: `connSyncCur(points)`.

The stale rule: `curStatus` goes from "ok" to "stale" only when the
point is not watched and no update has arrived within `staleTime`
(default 5min). Watched points never go stale. Stale keeps the last
`curVal` - it means old, not lost.

# Write Flow

When a writable point's effective value changes (see know-point
priority array), the framework observes it, applies `writeConvert`,
and dispatches to the device. Tuning shapes the traffic:

- `writeMinTime`: throttles rapid changes; intermediate writes are
  coalesced and the last value wins
- `writeMaxTime`: periodically re-sends the value even if unchanged
- `writeOnStart` / `writeOnOpen`: rewrite on system start / every
  time the conn opens (re-sync after reconnect)

# His Sync

For remote systems with their own trend logs, `connSyncHis(points, span)`
pulls history into the local historian. A null span defaults from each point's
`hisEnd` to now. The call blocks and syncs points sequentially - schedule
recurring syncs in a task, never from UI code. Points without remote logs
use local collection instead (hisCollect tags, see know-point).

# Learn

`connLearn(conn)` navigates the remote system's tree for discovery:

```axon
connLearn(conn)             // root of remote tree
connLearn(conn, learnArg)   // drill into a node's `learn` value
```

Rows with a `learn` value are navigable folders; leaf rows carry
`dis`, `kind`, `unit`, and ready-to-use address tags
(`{protocol}Cur/Write/His`). To create proxy points, commit recs
from leaf rows plus `point`, `kind`, and `{protocol}ConnRef`.

# Tuning

Tuning recs hold the timing knobs and bind via `connTuningRef`,
resolved point, then conn, then ext level - so one conn can mix
fast and slow points:

```trio
connTuning
dis: "Fast Poll"
pollTime: 5sec
staleTime: 1min
writeMinTime: 2sec
```

Knobs: `pollTime` (default 10sec), `staleTime` (default 5min),
`writeMinTime`, `writeMaxTime`, `writeOnStart`, `writeOnOpen`.
Points sharing a tuning form one poll bucket; buckets are staggered
at startup to spread load.

# Troubleshooting

Point status inherits the conn status: if the conn is down or
disabled, every point reports that status regardless of its own
config. A point-level config fault (bad `kind`, wrong address tag
type, invalid convert string) overrides with "fault". So debug
order: conn first, then point.

```axon
read(conn and dis=="Main").connPing
connDetails(conn)           // config, state, stats, poll buckets
connDetails(pt)             // per-facet state, tuning, watches
connPointsInWatch(conn)     // what is actually being polled
connTraceEnable(conn)       // capture protocol traffic
connTrace(conn)             // read trace (in-RAM, last 500 msgs)
connPoints(conn)            // all points bound to conn
```

Common causes: "stale" = point not in a watch (open a view or
watch it); "down" = network/IO problem, check uri and remote
system; "fault" on conn = config error; "fault" on point = bad
kind/address/convert; "unknown" = never communicated since startup.

# Style Notes

- Store credentials with passwordSet, never as rec tags
- Run recurring his syncs in a task
- Ensure converted values match the point's `kind` and `unit`
- Disable a conn or point with the `disabled` marker rather than
  deleting it
- Start every investigation with connDetails

