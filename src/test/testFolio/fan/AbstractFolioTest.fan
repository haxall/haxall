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

  FolioTestImpl[] impls()
  {
    acc := [FolioFlatFileTestImpl(), HxFolioTestImpl()]
    try
      acc.addNotNull(Type.find("testSkyarcd::Folio3TestImpl", false)?.make)
    catch (Err e)
      e.trace
    acc.each |impl| { impl.test = this }
    return acc
  }

  override Void teardown()
  {
    if (folio != null) close
    tempDir.delete
  }

  FolioTestImpl? impl

  Void runImpls()
  {
    impls.each |impl| { runImpl(impl) }
  }

  Void runImpl(FolioTestImpl impl)
  {
    doMethod := typeof.method("do" + curTestMethod.name.capitalize)
    echo("-- Run:  $doMethod($impl.name) ...")
    this.impl = impl
    doMethod.callOn(this, [,])
    teardown
    this.impl = null
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
    folioRef = impl.open(config)
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

  Void verifyDictDis(Dict r, Str dis)
  {
    r = folio.readById(r.id)
    if (r.missing("disMacro"))
    {
      // we expect all implementations to handle non-macro updates
      verifyEq(r.dis, dis)
      verifyEq(r.id.dis, dis)
    }
    else
    {
      // route to implementation
      impl.verifyDictDis(r, dis)
    }
  }

  Void verifyIdDis(Ref id, Str dis)
  {
    impl.verifyIdDis(id, dis)
  }

  Dict readById(Ref id)
  {
    folio.readById(id)
  }

  Void verifyReadById(Ref id, Dict? expect)
  {
    if (expect != null)
    {
      verifyDictEq(folio.readById(id), expect)
      verifyDictEq(folio.readById(id, false), expect)
      verifyDictEq(folio.readById(id, true), expect)
      verifyDictEq(folio.readByIdsList([id]).first, expect)
    }
    else
    {
      verifyEq(folio.readById(id, false), null)
      verifyEq(folio.readByIdsList([id], false), Dict?[null])
      verifyErr(UnknownRecErr#) { folio.readById(id) }
      verifyErr(UnknownRecErr#) { folio.readById(id, true) }
      verifyErr(UnknownRecErr#) { folio.readByIdsList([id]) }
      verifyErr(UnknownRecErr#) { folio.readByIdsList([id], true) }
    }
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

