# Know Api

The Haystack HTTP API is how external clients integrate with the
server. Every operation is a URI under `/api/{proj}/{op}` that
accepts and returns haystack grids. Use this skill to help users
write API clients or call other haystack servers.

# Authentication

Clients authenticate with the standard haystack flow: a `hello`
handshake, a SCRAM exchange (SHA-256), then a bearer token:

```
Authorization: hello username=<base64url-username>
  ... SCRAM challenge/response exchange (RFC 5802) ...
Authorization: bearer authToken=<token>
```

Every request after auth carries the bearer token. An expired or
invalid token returns HTTP 403 - redo the hello handshake; do not
retry with the old token. Most languages have a haystack client
library that implements this; point users there before hand-rolling
SCRAM.

# Requests and Responses

- Read-only ops (marked noSideEffects) support GET with query
  params parsed as zinc literals: `?filter=site&limit=5`
- Everything else is POST with a grid body
- Content negotiation: zinc is the default; use `Content-Type` /
  `Accept` headers (or `?filetype=json`) for json, csv, trio
- **Errors usually return HTTP 200 with an error grid**: check the
  grid meta for the `err` marker plus `dis` and `errTrace`. Real
  HTTP error codes only cover routing and auth (401/403/404/405/415)

# Operations

| Op | GET | Purpose |
|----|-----|---------|
| about | yes | server info |
| ops / defs / libs / filetypes | yes | introspection |
| read | yes | query recs by filter or ids |
| nav | yes | navigate the database tree |
| hisRead | yes | time-series read |
| eval | no | evaluate an axon expression |
| commit | no | add/update/remove recs (admin) |
| hisWrite | no | write time-series (admin) |
| pointWrite | no | read/write priority array (admin) |
| watchSub / watchPoll / watchUnsub | no | real-time subscriptions |
| close | no | end session, revoke token |

# Reading

```
GET /api/demo/read?filter=point and equipRef==@ahu1&limit=100

POST /api/demo/read
ver:"3.0"
filter,limit
"site",10

POST /api/demo/read      // batch by id
ver:"3.0"
id
@site-a
@site-b
```

# Eval and Commit

Eval posts a grid with one `expr` row and returns the result grid:

```
ver:"3.0"
expr
"readAll(site)"
```

Commit puts the mode in the grid meta - one mode per request:

```
ver:"3.0" commit:"add"
dis,site
"New Site",M

ver:"3.0" commit:"update"       // rows need id + mod for concurrency
id,mod,area
@site-a,2026-07-03T10:00:00Z UTC,5000ft²

ver:"3.0" commit:"remove"
id,mod
@site-a,2026-07-03T10:00:00Z UTC
```

Update supports `force` and `transient` markers in the meta (same
semantics as folio diffs).

# Watches

Stateful polling for real-time data:

1. `watchSub`: grid of `id` rows, meta `watchDis` and `lease`
   (duration). Response meta has the `watchId`; rows are the
   current state of the recs
2. `watchPoll`: meta `watchId`; returns only recs changed since the
   last poll (empty grid if none). Meta options: `refresh` marker
   returns all current state; `curValSub` returns only
   id/curVal/curStatus columns for lean polling
3. `watchUnsub`: meta `watchId` removes id rows, or with the
   `close` marker closes the whole watch

Each poll renews the lease; an unrenewed watch expires server-side
and subsequent polls fail - resubscribe.

# History

hisRead range strings: `"today"`, `"yesterday"`, `"2026-07-01"`,
`"2026-07-01,2026-07-03"`, or zinc datetime literals.

- Single point: meta `range`, one `id` row → `ts`,`val` columns
- Batch: meta `range` (+ optional `tz`), request columns `id` →
  response `ts`,`v0`,`v1`... where each value column's meta carries
  its point `id`

hisWrite mirrors it: single point puts `id` in meta with `ts`,`val`
rows; batch puts `ts` first with `v0`,`v1`... columns id-tagged in
column meta.

# PointWrite

- Read the priority array: post just the `id` → returns 17 rows
  (level, val, who, expires)
- Write: post `id`, `level` (1-17), `val`, optional `who`; level 8
  supports a `duration` for timed overrides

# Calling Other Haystack Servers from Axon

Inside the runtime, the haystack connector is the client. Configure
a `haystackConn` (see know-conn) then:

```axon
conn.haystackCall("ops")                  // any op
conn.haystackReadAll(point and equip)     // remote filter read
conn.haystackHisRead(remoteId, yesterday)
conn.haystackEval(readAll(site).count)    // SkySpark remote eval
conn.haystackInvokeAction(id, "reset", {})
```

`haystackEval` serializes referenced local variables when they are
atomic types (numbers, strings, dates, refs); complex values cannot
cross the wire.

# Style Notes

- Always check response grids for the `err` meta marker - HTTP 200
  does not mean success
- Recommend an existing haystack client library over hand-rolled
  SCRAM
- Keep watch leases modest and poll within them
- Batch his and read operations instead of per-point calls
