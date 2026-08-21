<!--
author:     Brian Frank
created:    21 Aug 2026
copyright:  Copyright (c) 2026, SkyFoundry LLC, All Rights Reserved
-->

# hxApi Design

The hxApi pod implements the HTTP API endpoint for a Haxall server.  Every
request is `/api/{proj}/{op}` where proj names a runtime and op names a
function in its namespace.  One endpoint serves two protocol versions:
version 4 is the legacy pre-xeto Haystack protocol where every exchange is
a grid; version 5 is the xeto protocol with typed parameters and returns.
The wire contracts are specified in the `doc.xeto::HttpApi` chapter; this
document covers how the implementation is organized.

## Pipeline

`ApiPipeline` owns the entire lifecycle of one request:

1. `routeRemote` - subclass hook to tunnel the request to another node
2. `resolveRuntime` - map `/api/{proj}` to the runtime ("sys" is reserved
   for the system runtime)
3. `upgrade` - websocket upgrade check before authentication; the ext
   declaring the protocol services the whole request
4. `authenticate` - the auth layer writes its own 401 challenges
5. `resolveVersion` - after authentication, so an unauthenticated request
   answers its auth challenge before any version error
6. `onAuthenticated` - subclass hook with the authenticated context, before
   the body is read (a subclass may pipe the unread body elsewhere)
7. `resolveOpFunc` - map op name to its func spec; qnames ("lib::name")
   resolve directly, simple names narrow ambiguity to `<op>` marked funcs
8. `dispatch` - build the version specific dispatcher and run
   readReq / call / writeRes

The catch sequence in `service` is the mapping from Fantom err types to
API errors: ApiErr passes through, PermissionErr / UnknownRecErr /
UnknownWatchErr / TimeoutErr map to their ApiErr equivalents, and anything
else is a 500 InternalErr.  `call` unwraps EvalErr so those types are
visible - it is the only unwrap site.

SkySpark subclasses the pipeline for clustering and session concerns
via the `routeRemote` and `onAuthenticated` hooks.

## Version Model

The client selects the version with the `Xeto-Version` header or the
`xeto-version` query param (param wins; the param exists so a version 5
request can be made from a browser or curl).  No version means version 4,
which keeps every existing Haystack client working unchanged.

Each dispatcher declares its version via the abstract
`ApiDispatch.version`, which drives all filetype resolution - the version
is never passed around as a parameter.

Version 5 responses echo the version in the header.  Error responses
always report the server's *current* version (`xeto::ApiErr.writeRes`):
many errors occur before version resolution, so echoing the negotiated
version is not even well defined on the error path.

## Dispatch

`ApiDispatch` is the base class holding everything version neutral;
`ApiDispatchV4` and `ApiDispatchV5` implement the four seams: `version`,
`readReqGet`, `readReqPost`, `writeResVal`.

Shared machinery in the base:

- `checkMethod` - GET only for `<noSideEffects>` ops, POST for all,
  anything else 501.  Skipped for funcs which read the request themselves.
- `mapArgs` - map named args onto the positional thunk args, applying
  param defaults from `metaOwn` (meta inherited from the param's *type*
  must never be mistaken for a default - sys::Ref declares an example
  `val`).  A file typed param declared beside others is rejected here.
- `mapGridArgs` - a request grid passed whole, or the first row's cells
  demuxed as named args.  Version 4 passes whole per `takesReqGridV4`;
  version 5 per the `<opGrid>` marker.
- `writeResGrid` / `writeResBody` - the single response writing path:
  headers, gzip, and `Filetype.apiEncode`.
- `reqFiletype` / `acceptFiletype` / `acceptOpts` - negotiation resolution,
  see below.
- File results are served as downloads by `writeResFile` (FileWeblet:
  etag, 304, Content-Disposition) in both versions; file params receive
  the raw POST body spooled to a temp file which the pipeline deletes
  after dispatch.

Version 4 specifics: every request and response is a grid.  A failure
raised by the op func itself is reported as a 200 response carrying an
error grid - the legacy contract `haystack::Client` parses - while
failures in the HTTP processing still answer real status codes.  The
`ApiDispatchV4Op.specials` table adapts the five legacy ops (read, defs,
libs, ops, filetypes, watchPoll) whose wire shapes predate modeled params;
the filetypes special synthesizes its def-shaped rows from the Filetype
registry rather than the def namespace.

Version 5 specifics: the named args formats - bare JSON and the xeto
family - carry one object whose members are the named args, each decoded
against its own param spec (JSON alone is lossy; a date is just a string
until a spec says otherwise).  GET args ride as bare query params quoted
into JSON for the same per-spec decode.  Haystack grid formats still
carry a request grid exactly as version 4.  Responses answer the bare
result value with no envelope in the xeto family, and bridge through a
grid for the haystack formats so a version 5 call with `Accept: text/zinc`
returns what a version 4 client would see.

## Op Function Contract

Dispatch behavior is driven entirely by the func's xeto spec - never by
sniffing its signature.  `ApiUtil` is the single catalog of these checks:

| Marker            | Meaning                                              |
|-------------------|------------------------------------------------------|
| `op`              | invocable as an API op                               |
| `noSideEffects`   | may be invoked with GET                              |
| `opGrid`          | receives its request grid whole on grid transports   |
| `opWebReq`        | reads the raw HTTP request itself, owns method rules |
| `opWebRes`        | writes the raw HTTP response itself                  |

File params and returns are type derived via `SpecFunc.isFileParam` /
`isFileReturn`.  Query params prefixed `xeto-` are reserved for protocol
control and never map to op args (a xeto name cannot contain a dash, so
no collision is possible).

## Content Negotiation

`haystack::Filetype` is the choke point for all format concerns; hxApi
never touches mime strings directly.  The registry key is the full mime
type - params included - so `application/vnd.haystack+json;version=3` is
a different filetype (jsonV3) than the bare hayson mime.

- `Filetype.apiMime(mime, version)` is the one place version policy
  lives: the null-Accept defaults (zinc / jeto) and the bare
  `application/json` binding (hayson / jeto).
- `Filetype.mimeRes` is the response Content-Type: the JSON dialects
  (jeto, hayson, jsonV3) all serve `application/json`; text formats add
  the charset param.  The `mime` field stays the pure lookup key.
- `apiDecode` / `apiEncode` are the codec entry points: grid formats ride
  GridReader/GridWriter, the xeto family (`isXetoIO`) rides the namespace
  codec with refs resolved externally (API refs point at recs, not xeto
  instances).
- `acceptOpts` extracts the `box` mime param for the jeto boxing mode;
  an unrecognized token is a 406 so a client never silently gets the
  wrong wire.  `box=none` is the wire the OpenAPI schemas describe.

Both versions expose discovery: the version 5 `sys.api::filetypes` op and
the version 4 filetypes special both serve from `Filetype.list`, so the
registry is the single system of record.

## Errors

`xeto::ApiErr.writeRes` is the choke point for every error response: real
status code, `application/json` body with a `spec` tag naming the precise
`sys.api` error type so clients dispatch without parsing messages.  Error
bodies are always JSON regardless of Accept - an error must be
deliverable even when negotiation itself is what failed.

## Testing

`testHx::ApiTest` runs the shared assertions under both dialects through
three hooks (`callOp`, `callGridOp`, `callWatchPoll`) so one test body
pins both wire contracts; `Api4Test` and `Api5Test` add the version
specific coverage (negotiation matrix, def ops, named args, box modes,
upload).  Every exchange streams to stdout and a trace report file as
`### <op> <req-type> <res-type> <ver>` blocks with raw headers and bodies,
so the wire can be reviewed by eye; `haystack::Client` traffic including
the scram handshake is captured through its debug log.

