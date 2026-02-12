//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jan 2022  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio

**
** ConnCommitter manages and optimizes the commits to a conn or point rec.
** This class keeps track of all the transient tags the connector framework
** is managing so we can avoid making Folio commits when no tags are changed.
**
internal const final class ConnCommitter
{
  ** Last representation of all tags we are managing on the rec
  Dict managed() { managedRef.val }
  private const AtomicRef managedRef := AtomicRef(Etc.dict0)

  ** Make a forced transient commit for one tag
  Void commit1(ConnExt ext, Dict rec, Str n0, Obj? v0)
  {
    m := managed
    if (m[n0] == v0) return

    changes := Etc.dict1(
      n0, v0 ?: None.val)

    commit(ext, rec, changes)
  }

  ** Make a forced transient commit for two tags
  Void commit2(ConnExt ext, Dict rec, Str n0, Obj? v0, Str n1, Obj? v1)
  {
    m := managed
    if (m[n0] == v0 && m[n1] == v1) return

    changes := Etc.dict2(
      n0, v0 ?: None.val,
      n1, v1 ?: None.val)

    commit(ext, rec, changes)
  }

  ** Make a forced transient commit for three tags
  Void commit3(ConnExt ext, Dict rec, Str n0, Obj? v0, Str n1, Obj? v1, Str n2, Obj? v2)
  {
    m := managed
    if (m[n0] == v0 && m[n1] == v1 && m[n2] == v2) return

    changes := Etc.dict3(
      n0, v0 ?: None.val,
      n1, v1 ?: None.val,
      n2, v2 ?: None.val)

    commit(ext, rec, changes)
  }

  ** Choke point for folio commit
  private Void commit(ConnExt ext, Dict rec, Dict changes)
  {
    // update managed tags (bit more optimized than Etc.dictMerge)
    acc := Etc.dictToMap(managed)
    changes.each |v, n|
    {
      if (v === None.val) acc.remove(n)
      else acc[n] = v
    }
    managedRef.val = Etc.makeDict(acc)

    // use blocking commit so we have back pressure if folio queues
    // back up; maybe eventually do something more sophisticated
    try
    {
      ext.proj.db.commit(Diff(rec, changes, Diff.forceTransient))
    }
    catch (ShutdownErr e)
    {
      // ignore
    }
    catch (Err e)
    {
      // don't report if record has been removed
      newRec := ext.proj.db.readById(rec.id, false)
      if (newRec == null || newRec.has("trash")) return
      throw e
    }
  }

  ** Debug details
  Void details(StrBuf s)
  {
    m := managed
    Etc.dictNames(m).sort.each |n|
    {
      s.add("$n:".padr(16)).add(m[n]).add("\n")
    }
  }
}

