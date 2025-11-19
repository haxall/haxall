//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Nov 2015  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

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
    acc := FolioTestImpl[,]
    Env.cur.index("testFolio.impl").each |qname|
    {
      try
        acc.addNotNull(Type.find(qname).make)
      catch (Err e)
        e.trace
    }
    acc.each |impl| { impl.testRef = this }
    return acc
  }

  override Void teardown()
  {
    impl?.teardown
    impl = null
  }

  FolioTestImpl? impl

  virtual Void runImpls()
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

  virtual Folio folio() { impl.folio }

  virtual Folio open(FolioConfig? config := null)
  {
    if (impl.folioRef != null) throw Err("Folio is already open!")
    if (config == null) config = toConfig
    impl.folioRef = impl.open(config)
    return impl.folio
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
    impl.close
  }

  Folio reopen(FolioConfig? config := null)
  {
    close
    return open(config)
  }

//////////////////////////////////////////////////////////////////////////
// Folio Utils
//////////////////////////////////////////////////////////////////////////

  Void verifyIdsSame(Ref a, Ref b)
  {
    impl.verifyIdsSame(a, b)
  }

  Void verifyRecSame(Dict? a, Dict? b)
  {
    impl.verifyRecSame(a, b)
  }

  Int verifyCurVerChange(Int prev)
  {
    impl.verifyCurVerChange(prev)
  }

  Int verifyCurVerNoChange(Int prev)
  {
    impl.verifyCurVerNoChange(prev)
  }

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

**************************************************************************
** FolioTestImpl
**************************************************************************

**
** FolioTestImpl plugs a specific Folio implementation into AbstractFolioTest
**
abstract class FolioTestImpl
{
  ** Dump implementations installed
  static Void main()
  {
    echo("FolioTestImpl installed:")
    AbstractFolioTest().impls.each |impl | { echo("  $impl.typeof") }
  }

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

  ** Does the implementation support re-opening with different id prefix
  virtual Bool supportsIdPrefixRename() { true }

  ** Does the implementation support FolioX APIS
  virtual Bool supportsFolioX() { false }

  ** Does the implementation support spark index APIs
  virtual Bool supportsSparkIndex() { supportsFolioX }

  ** Verify that two ids are normalized to the same instance
  virtual Void verifyIdsSame(Ref a, Ref b) { verifySame(a, b) }

  ** Verify record a is the same b.  If the implementation supports
  ** an in-memory cache then they should be the same instance in memory,
  ** otherwise they should be the same by tag values
  virtual Void verifyRecSame(Dict? a, Dict? b) { verifySame(a, b) }

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
  virtual Int verifyCurVerNoChange(Int prev)
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

