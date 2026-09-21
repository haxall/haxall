//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Sep 2026  Brian Frank  Move from ion
//

using concurrent
using util
using xeto
using haystack

**
** Client side record cache
**
@NoDoc @Js
const abstract class PiRecCache
{
  ** Lookup record by id, or null if not cached or expired.  An id
  ** cached as unresolvable also returns null.
  abstract Dict? get(Ref id)

  ** Has this id been read to a verdict: either a record or a known
  ** miss.  False means the answer is simply not known yet, which
  ** callers must not report as a missing target.  Use this rather
  ** than tracking resolution yourself: only the cache knows when
  ** an entry expires and its answer reverts to unknown.
  abstract Bool isResolved(Ref id)

  ** Asynchronously resolve the given ids.  Ids already cached and
  ** unexpired are skipped, so the future completes immediately when
  ** everything is already available.
  abstract PiFuture resolve(Ref[] ids)

  ** Seed the cache with a record already read by the caller so a
  ** view holding recs does not re-read them
  abstract Void put(Dict rec)

  ** Evict all entries
  abstract Void clear()

}

