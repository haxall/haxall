//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Nov 2015  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hxFolio

**
** FolioTestImpl is the
**
abstract class FolioTestImpl
{

  ** Current test
  AbstractFolioTest test() { testRef ?: throw Err("Not associated with test") }
  internal AbstractFolioTest? testRef

  ** Folio instance
  Folio folio() { folioRef ?: throw Err("Folio is not open") }
  internal Folio? folioRef

  ** Implementation name for output
  abstract Str name()

  ** Open the folio implementation
  abstract Folio open(FolioConfig config)

  ** Close the current database
  virtual Void close()
  {
    folio.close
    folioRef = null
  }

  ** Close and delete current database
  virtual Void teardown()
  {
    folioRef?.close
    test.tempDir.delete
    folioRef = null
  }

//////////////////////////////////////////////////////////////////////////
// Feature Overrides
//////////////////////////////////////////////////////////////////////////

  ** Does the implementation support transient commits
  virtual Bool supportsTransient() { true }

  ** Does the implementation support the history API
  virtual Bool supportsHis() { true }

  ** Verify record a is the same b.  If the implementation supports
  ** an in-memory cache then they should be the same instance in memory,
  ** otherwise they should be the same by tag values
  virtual Void verifyRecSame(Dict? a, Dict? b)
  {
    verifySame(a, b)
  }

  ** Verify the current version of Folio is greater than prev.
  ** Return new version
  virtual Int verifyCurVerChange(Int prev)
  {
    folio.sync
    cur := folio.curVer
    // echo("~~ verifyCurVerChange $cur ?> $prev")
    verify(cur > prev)
    return cur
  }

  ** Verify the current version the same as prev.
  ** Return new version
  Int verifyCurVerNoChange(Int prev)
  {
    folio.sync
    cur := folio.curVer
    // echo("~~ verifyCurVerNoChange $cur ?= $prev")
    verifyEq(cur, prev)
    return prev
  }

  ** Verify Dict.dis
  virtual Void verifyDictDis(Dict r, Str expect)
  {
    verifyEq(r.dis, expect)
    verifyEq(r.id.dis, expect)
  }

  ** Verify Ref.dis
  virtual Void verifyIdDis(Ref id, Str expect)
  {
    verifyEq(id.dis, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verify(Bool c, Str? msg := null)                { test.verify(c, msg) }
  Void verifyEq(Obj? a, Obj? b, Str? msg := null)      { test.verifyEq(a, b, msg) }
  Void verifyNotEq(Obj? a, Obj? b, Str? msg := null)   { test.verifyNotEq(a, b, msg) }
  Void verifySame(Obj? a, Obj? b, Str? msg := null)    { test.verifySame(a, b, msg) }
  Void verifyNotSame(Obj? a, Obj? b, Str? msg := null) { test.verifyNotSame(a, b, msg) }
}

**************************************************************************
** FolioFlatFileTestImpl
**************************************************************************

class FolioFlatFileTestImpl : FolioTestImpl
{
  override Str name() { "flatfile" }

  override Folio open(FolioConfig c) { FolioFlatFile.open(c) }

  // don't support disMacro
  override Void verifyDictDis(Dict r, Str expect) {}

  // don't support disMacro
  override Void verifyIdDis(Ref id, Str expect) {}

  // don't support history API
  override Bool supportsHis() { false }
}

**************************************************************************
** HxFolioTestImpl
**************************************************************************

class HxFolioTestImpl : FolioTestImpl
{
  override Str name() { "hx" }

  override Folio open(FolioConfig c) { HxFolio.open(c) }
}

