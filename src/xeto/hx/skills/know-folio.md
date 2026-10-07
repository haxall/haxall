# Know Folio

Folio is the runtime's tag database of recs (Dicts keyed by Ref id).

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

Beyond the basics, filters support:

```axon
equipRef == @abc123            // ref equality
equipRef->siteRef->dis == "X"  // multi-hop traversal
ph::Meter                      // match by qualified Xeto spec name
```

Filter semantics:
- Any comparison against a missing tag is false; `ref->tag` excludes
  the rec if the ref or the target tag is missing
- Number comparisons require exact unit match: `num == 75` does not
  match `75°F`; there is no automatic unit conversion
- A tag with a list of refs matches if any ref in the list matches
- Parse a string to a filter with `parseFilter("equip and hvac")`
- Apply a filter to an in-memory grid, list, or stream with
  `filter`: `grid.filter(area > 1000ft²)`

# Reading

```axon
readById(id, false)               // null if not found
readByIds([@a, @b])               // grid, rows correspond by index
readByIds(ids, false)             // missing ids yield all-null rows
readAll(equip, {sort})            // sort by display name
readAll(equip, {search:"RTU*"})   // apply search pattern
```

Notes:
- `read` with multiple matches returns an indeterminate one
- The `search` option is a case insensitive glob by default; use
  `re:` prefix for regex or `f:` prefix for a nested filter
- `readAllTagNames(equip)` returns grid of tag names in use with
  columns name, kind, count
- `readAllTagVals(point, "unit")` returns grid of unique values for
  one tag, capped at 200 results
- `readByIdPersistentTags(id)` / `readByIdTransientTags(id)` return
  only one kind of tag

For large result sets use streams to avoid loading everything into
memory:

```axon
readAllStream(point).filter(unit).limit(100).collect
readByIdsStream(ids).map(r => r->dis).collect
```

# Writing

Commit requires admin permission. The `diff(orig, changes, flags)`
flags:
- `add`: create new rec; orig must be null; pass `id` tag in changes
  to use an explicit id
- `remove`: delete rec permanently (see Trash below)
- `transient`: changes are not persisted (see Transient Tags below);
  cannot be combined with add or remove
- `force`: skip the concurrent change check; all other validation
  still runs

Commit semantics:
- Single diff returns the new rec; list of diffs returns list of recs;
  a stream of diffs returns the commit count
- A list commit is atomic: all diffs succeed or none do
- All diffs in one commit must be all persistent or all transient,
  and may not target the same rec twice
- Commit is synchronous; the returned rec has the updated `mod`
- Every persistent commit updates `mod`; commit throws
  ConcurrentChangeErr if `orig->mod` no longer matches, so diff
  against a freshly read rec and never fabricate `mod`

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
readAll(equip)                    // trash always excluded
readTrash()                       // read everything in the trash
readTrash(equip)                  // read trashed equip recs (only)
readById(trashedId, false)        // null; by-id reads exclude trash
commit(diff(rec, null, {remove})) // permanently remove
```

# Copying Recs

Recs contain tags which cannot be committed to another project or
another rec: `id`, `mod`, transient tags, and his config tags such as
`hisSize`. Use `stripUncommittable` to clean them:

```axon
rec.stripUncommittable          // strip, keep id
rec.stripUncommittable({mod})   // keep mod

// copy pattern: strip id too
src: readById(@a)
commit(diff(null, src.stripUncommittable({-id}), {add}))
```

# Display Names

Display name resolution precedence for a rec:
1. `disMacro`: macro string interpolating tags: `"$siteRef $navName"`
   where a `$tag` ref resolves recursively to its display name
2. `dis`: explicit display string
3. otherwise the id is displayed

`relDis(parent, child)` returns the relative display, stripping the
common prefix.

# Performance

In Haxall every filter is a full table scan except direct id lookups;
SkySpark additionally builds tag indexes automatically.
