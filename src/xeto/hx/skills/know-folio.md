# Know Folio

Folio is the tag-oriented database built into the runtime. Records
("recs") are Dicts identified by a Ref id. Recs are queried with
filters and modified by committing diffs. All the database functions
operate on the current project's Folio.

# Recs and Special Tags

- `id`: unique Ref assigned when rec is added; immutable
- `mod`: DateTime of last persistent change; read-only, used as the
  concurrency token for commits
- `dis`: display name (see Display Names below)
- `spec`: Ref to the rec's Xeto spec type
- `trash`: marker for soft delete (see Trash below)

The `id` and `mod` tags are managed by Folio and can never be
committed directly.

Funcs, specs, and instances managed in the project companion lib
(written via write_xeto) are recs discriminated by the `rt` tag:
filter with `rt=="func"`, `rt=="spec"`, or `rt=="instance"`. There
is no bare `func` marker tag on 4.x managed recs.

# Filters

Filters are the query language used by `read`, `readAll`, and
`readCount`. They are not Axon expressions:

```axon
site                           // has marker tag
not point                      // missing tag
equip and hvac                 // logical and
ahu or chiller                 // logical or
geoCity == "Chicago"           // string equality
curVal > 75                    // number comparison
equipRef == @abc123            // ref equality
siteRef->geoCity == "Chicago"  // ref path traversal
equipRef->siteRef->dis == "X"  // multi-hop traversal
Meter                          // match by unqualified Xeto spec name
ph::Meter                      // match by qualified Xeto spec name
```

Filter semantics:
- Any comparison against a missing tag is false; `ref->tag` excludes
  the rec if the ref or the target tag is missing
- Number comparisons require exact unit match: `num == 75` does not
  match `75°F`; there is no automatic unit conversion
- A tag with a list of refs matches if any ref in the list matches
- Parse a string to a filter with `parseFilter("equip and hvac")`
- Convert a filter to a predicate func with `filterToFunc`:
  `grid.findAll(filterToFunc(area > 1000ft²))`

# Reading

```axon
read(site)                        // first match, throws if none
read(chiller, false)              // null instead of throw
readById(@2b00f9dc-82690ed6)      // lookup by id, throws if not found
readById(id, false)               // null if not found
readByIds([@a, @b])               // grid, rows correspond by index
readByIds(ids, false)             // missing ids yield all-null rows
readAll(equip and siteRef==@xyz)  // grid of all matches
readAll(equip, {limit:10})        // cap results
readAll(equip, {sort})            // sort by display name
readAll(equip, {trash})           // include recs in trash
readAll(equip, {search:"RTU*"})   // apply search pattern
readCount(point)                  // number of matches
```

Notes:
- `read` with multiple matches returns an indeterminate one
- The `search` option is a case insensitive glob by default; use
  `re:` prefix for regex or `f:` prefix for a nested filter
- `readAllTagNames(equip)` returns grid of tag names in use with
  columns name, kind, count
- `readAllTagVals(point, "unit")` returns grid of unique values for
  one tag, capped at 200 results

For large result sets use streams to avoid loading everything into
memory:

```axon
readAllStream(point).filter(x => x.has("unit")).limit(100).collect
readByIdsStream(ids).map(r => r->dis).collect
```

Advanced reads:
- `readByIdPersistentTags(id)`: only the persistent tags
- `readByIdTransientTags(id)`: only the transient tags
- `readLink(id)`: dict with grid-standard column order for hyperlinks

# Writing

Modifications are two steps: construct a diff, then commit it.
Commit requires admin permission.

```axon
// add new rec (id is auto-generated)
newRec: commit(diff(null, {dis:"New Rec", site}, {add}))

// update tags on existing rec
commit(diff(rec, {area:5000ft²}))

// remove a tag
commit(diff(rec, {-oldTag}))

// batch commit list of diffs (atomic)
readAll(equip).toRecList.map(r => diff(r, {someTag})).commit
```

The `diff(orig, changes, flags)` flags:
- `add`: create new rec; orig must be null; pass `id` tag in changes
  to use an explicit id
- `remove`: delete rec permanently; prefer the `trash` tag instead
- `transient`: changes are not persisted (see Transient Tags below);
  cannot be combined with add or remove
- `force`: skip the concurrent change check (use with caution)

Commit semantics:
- Single diff returns the new rec; list of diffs returns list of recs;
  a stream of diffs returns the commit count
- A list commit is atomic: all diffs succeed or none do
- All diffs in one commit must be all persistent or all transient,
  and may not target the same rec twice
- Commit is synchronous; the returned rec has the updated `mod`

# Concurrency

Every persistent commit updates the `mod` timestamp. Commit verifies
`orig->mod` still matches the database and throws ConcurrentChangeErr
if another commit happened after your read:

```axon
// safe pattern: commit against a freshly read rec
commit(diff(readById(id), {newTag}))

// force overwrite regardless of concurrent changes
commit(diff(rec, {newTag}, {force}))
```

The `force` flag only bypasses the mod check; all other validation
still runs.

# Transient Tags

Transient tags live in memory only and are lost on restart. They are
used for fast changing runtime state such as `curVal`, `curStatus`,
`writeVal`, and `connStatus`. Rules:

- `diff(rec, {curVal:72°F}, {transient})` commits transiently
- Transient commits do not update `mod` and are not persisted
- Normal reads return the merged persistent and transient tags
- A tag must be consistently one or the other: you cannot commit a
  tag transiently if it already exists persistently (or vice versa)
- Some tags are transient-only (`curVal`, `curStatus`, `writeLevel`)
  and some are persistent-only (`dis`, `site`, `equip`, `point`)

# Trash

Deleting is a two step process: add the `trash` marker for soft
delete, then permanently purge later:

```axon
commit(diff(rec, {trash}))        // move to trash
commit(diff(rec, {-trash}))       // restore from trash
readAll(equip)                    // trash excluded by default
readAll(equip, {trash})           // include trash recs
readById(trashedId, false)        // null; by-id reads exclude trash
commit(diff(rec, null, {remove})) // permanently remove
```

# Copying Recs

Recs contain tags which cannot be committed to another project or
another rec: `id`, `mod`, transient tags, and his config tags such as
`hisSize`. Use `stripUncommittable` to clean them:

```axon
rec.stripUncommittable          // strip, keep id
rec.stripUncommittable({-id})   // strip id too
rec.stripUncommittable({mod})   // keep mod

// copy pattern
src: readById(@a)
commit(diff(null, src.stripUncommittable({-id}), {add}))
```

# Display Names

Display name resolution precedence for a rec:
1. `disMacro`: macro string interpolating tags: `"$siteRef $navName"`
   where a `$tag` ref resolves recursively to its display name
2. `dis`: explicit display string
3. otherwise the id is displayed

```axon
dis(rec)               // display name of rec
relDis(parent, child)  // relative display, strips common prefix
```

# Performance

- In Haxall every filter is a full table scan except direct id
  lookups; SkySpark additionally builds tag indexes automatically
- Prefer one batch commit over many single commits
- Use `readAllStream`/`readByIdsStream` for very large result sets
- `readCount` is cheaper than `readAll(f).size`

# Style Notes

- Prefer trash over remove so users can recover recs
- Commit from a freshly read rec; never fabricate `mod`
- Use checked:false variants and null checks instead of try/catch

