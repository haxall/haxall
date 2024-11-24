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

  AbstractFolioTest? test

  ** Implementation name for output
  abstract Str name()

  ** I
  abstract Bool isFull()

  ** Open the folio implementation
  abstract Folio open(FolioConfig config)

//////////////////////////////////////////////////////////////////////////
// Feature Overrides
//////////////////////////////////////////////////////////////////////////

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

  override Bool isFull() { false }

  override Folio open(FolioConfig c) { FolioFlatFile.open(c) }

  // don't support disMacro
  override Void verifyDictDis(Dict r, Str expect) {}

  // don't support disMacro
  override Void verifyIdDis(Ref id, Str expect) {}
}

**************************************************************************
** HxFolioTestImpl
**************************************************************************

class HxFolioTestImpl : FolioTestImpl
{
  override Str name() { "hx" }

  override Bool isFull() { true }

  override Folio open(FolioConfig c) { HxFolio.open(c) }
}

