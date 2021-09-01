//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2016  Brian Frank  Creation
//

using concurrent
using haystack
using folio

**
** WhiteboxTest is base class for internal white-box tests
**
abstract class WhiteboxTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Test
//////////////////////////////////////////////////////////////////////////

  override Void teardown()
  {
    if (folio != null) close
  }

//////////////////////////////////////////////////////////////////////////
// Folio Lifecycle
//////////////////////////////////////////////////////////////////////////

  HxFolio? folio

  virtual HxFolio open()
  {
    folio = HxFolio.open(FolioConfig { it.dir = tempDir; it.log = Log.get("test") })
  }

  Void close()
  {
   if (folio == null) throw Err("Folio not open!")
   folio.close
   folio = null
  }

  Folio reopen()
  {
    close
    return open
  }

//////////////////////////////////////////////////////////////////////////
// Folio Utils
//////////////////////////////////////////////////////////////////////////

  Dict readById(Ref id)
  {
    folio.readById(id)
  }

  Dict addRec(Obj tags)
  {
    dict := Etc.makeDict(tags)
    id := dict["id"]
    if (id != null)
      dict = Etc.dictRemove(dict, "id")
    else
      id = Ref.gen
    return doCommit(Diff.makeAdd(dict, id))
  }

  Dict commit(Dict rec, Obj changes, Int flags := 0)
  {
    doCommit(Diff.make(rec, changes, flags))
  }

  private Dict doCommit(Diff diff)
  {
    stats := diff.isTransient ? folio.stats.commitsTransient : folio.stats.commitsPersistent
    oldCount := stats.count
    diff = folio.commit(diff)
    verifyEq(stats.count, oldCount+1)
    return diff.newRec
  }

  Void verifySparksEq(Dict[] actual, Dict[] expected)
  {
    sortSparks(expected)
    sortSparks(actual)
    verifyEq(actual.size, expected.size)
    expected.each |e, i|
    {
      a := actual[i]
      verifyDictEq(e, a)
    }
  }

  Void sortSparks(Dict[] sparks)
  {
    sparks.sort |a, b|
    {
      at := a->targetRef
      bt := b->targetRef
      if (at != bt) return at <=> bt

      ad := a->date
      bd := b->date
      if (ad != bd) return ad <=> bd

      return a->ruleRef <=> b->ruleRef
    }
  }

}

