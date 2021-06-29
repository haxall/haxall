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

  static const FolioTestImpl[] impls
  static
  {
    list := [FolioFlatFileTestImpl(), HxFolioTestImpl()]
    list.addNotNull(Type.find("testSkyarcd::Folio3TestImpl")?.make)
    impls = list
  }

  override Void teardown()
  {
    if (folio != null) close
    tempDir.delete
  }

  FolioTestImpl? curImpl

  Void allImpls()
  {
    impls.each |impl| { runImpl(impl) }
  }

  Void fullImpls()
  {
    impls.each |impl| { if (impl.isFull) runImpl(impl) }
  }

  Void runImpl(FolioTestImpl impl)
  {
    doMethod := typeof.method("do" + curTestMethod.name.capitalize)
    echo("-- Run:  $doMethod($impl.name) ...")
    curImpl = impl
    doMethod.callOn(this, [,])
    teardown
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
    folioRef = curImpl.open(this, config)
    return folio
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
** FolioTestImpl
**************************************************************************

abstract const class FolioTestImpl
{
  abstract Str name()
  abstract Bool isFull()
  abstract Folio open(AbstractFolioTest t, FolioConfig config)
}

const class FolioFlatFileTestImpl : FolioTestImpl
{
  override Str name() { "flatfile" }
  override Bool isFull() { false }
  override Folio open(AbstractFolioTest t, FolioConfig c) { FolioFlatFile.open(c) }
}

const class HxFolioTestImpl : FolioTestImpl
{
  override Str name() { "hx" }
  override Bool isFull() { true }
  override Folio open(AbstractFolioTest t, FolioConfig c) { HxFolio.open(c) }
}