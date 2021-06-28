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
** AbstractFolioTest is base class for black box testing across
** all the different Folio implementations
**
class AbstractFolioTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Test
//////////////////////////////////////////////////////////////////////////

  override Void teardown()
  {
    if (folio != null) close
  }

  TestImpl? curImpl

  Void allImpls()
  {
    runImpls(TestImpl.vals)
  }

  Void fullImpls()
  {
    runImpls(TestImpl.vals.findAll |i| { i.isFull })
  }

  Void runImpls(TestImpl[] impls)
  {
    doMethod := typeof.method("do" + curTestMethod.name.capitalize)
    impls.each |impl|
    {
      echo("-- Run:  $doMethod($impl) ...")
      curImpl = impl
      doMethod.callOn(this, [,])
      teardown
    }
    curImpl = null
  }

//////////////////////////////////////////////////////////////////////////
// Folio Lifecycle
//////////////////////////////////////////////////////////////////////////

  virtual Folio? folio() { folioRef }
  Folio? folioRef

  virtual Folio open(FolioConfig? config := null)
  {
    if (folio != null) throw Err("Folio is already open!")
    if (config == null) config = toConfig
    switch (curImpl)
    {
      case TestImpl.flatFile: openFlatFile(config)
      case TestImpl.hx:       openHx(config)
      default: throw Err("No curImpl set!")
    }
    return folio
  }

  Folio openFlatFile(FolioConfig config)
  {
    folioRef = FolioFlatFile.open(config)
  }

  Folio openHx(FolioConfig config)
  {
    folioRef = HxFolio.open(config)
  }

  FolioConfig toConfig(Str? idPrefix := null)
  {
    FolioConfig
    {
      it.dir      = tempDir
      it.log      = Log.get("test")
      it.idPrefix = idPrefix
    }
  }

  Void close()
  {
   if (folio == null) throw Err("Folio not open!")
   folio.close
   folioRef = null
  }

  Folio reopen(FolioConfig? config := null)
  {
    close
    return open(config)
  }

//////////////////////////////////////////////////////////////////////////
// Folio Utils
//////////////////////////////////////////////////////////////////////////

  Dict readById(Ref id)
  {
    folio.readById(id)
  }

  Dict addRec(Str:Obj tags)
  {
    id := tags["id"]
    if (id != null)
      tags.remove("id")
    else
      id = Ref.gen
    return folio.commit(Diff.makeAdd(tags, id)).newRec
  }

  Dict? commit(Dict rec, Obj? changes, Int flags := 0)
  {
    folio.commit(Diff.make(rec, changes, flags)).newRec
  }

  Void removeRec(Dict rec)
  {
    folio.commit(Diff.make(folio.readById(rec.id), null, Diff.remove))
  }

}

**************************************************************************
** TestImpl
**************************************************************************

enum class TestImpl
{
  flatFile,
  hx

  Bool isFull() { this !== flatFile }
}