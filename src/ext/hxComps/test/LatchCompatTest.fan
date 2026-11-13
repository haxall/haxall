//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using concurrent
using xeto
using haystack

class LatchCompatTest : HxCompTest
{
  ** A saved Bool clock of true loads with status ok
  Void testLoadsSavedBoolClock()
  {
    TestHxCompContext().asCur |cx|
    {
      cs.loadXeto(Str<|@1: Folder { lat @2: NumberLatch { clock: "true" } }|>)
      lat := cs.root.get("lat") as Comp
      verifyEq(lat.get("clock"), sb(true))
      lat.set("in", sn(7))
      cs.execute
      verifyEq(lat.get("out"), sn(7))
    }
  }

  ** A saved Bool clock of false loads as false
  Void testLoadsSavedBoolClockFalse()
  {
    TestHxCompContext().asCur |cx|
    {
      cs.loadXeto(Str<|@1: NumberLatch { clock: "false" }|>)
      verifyEq(cs.root.get("clock"), sb(false))
    }
  }

  ** A plain Bool linked into clock latches and logs one warning
  Void testBoolLinkIntoClock()
  {
    TestHxCompContext().asCur |cx|
    {
      src := createComp("StatusBoolToBool")
      lat := createComp("NumberLatch")
      cs.root.add(src)
      cs.root.add(lat)
      lat.set("links", lat.links.add("clock", Etc.link(src.id, "out")))
      recs := capture |->|
      {
        lat.set("in", sn(7))
        setAndExec(src, "in", sb(false))
        setAndExec(src, "in", sb(true))
        verifyEq(lat.get("out"), sn(7))
        lat.set("in", sn(8))
        setAndExec(src, "in", sb(false))
        setAndExec(src, "in", sb(true))
        verifyEq(lat.get("out"), sn(8))
      }
      verifyEq(recs.size, 1)
      verifyEq(recs[0].level, LogLevel.warn)
      verify(recs[0].msg.startsWith("NumberLatch @${lat.id}.clock: plain Bool read as StatusBool ok"))
    }
  }

  ** Each latch with a plain Bool clock logs its own warning, once
  Void testBoolLinkWarnsOncePerInstance()
  {
    TestHxCompContext().asCur |cx|
    {
      src := createComp("StatusBoolToBool")
      a := createComp("NumberLatch")
      b := createComp("NumberLatch")
      cs.root.add(src)
      cs.root.add(a)
      cs.root.add(b)
      a.set("links", a.links.add("clock", Etc.link(src.id, "out")))
      b.set("links", b.links.add("clock", Etc.link(src.id, "out")))
      recs := capture |->|
      {
        3.times
        {
          setAndExec(src, "in", sb(false))
          setAndExec(src, "in", sb(true))
        }
      }
      verifyEq(recs.size, 2)
      verify(recs.any { it.msg.startsWith("NumberLatch @${a.id}.clock:") })
      verify(recs.any { it.msg.startsWith("NumberLatch @${b.id}.clock:") })
    }
  }

  ** A saved clock scalar that is not true or false does not load
  Void testJunkScalarClockFails()
  {
    TestHxCompContext().asCur |cx|
    {
      Err? err := null
      try cs.loadXeto(Str<|@1: NumberLatch { clock: "yes" }|>)
      catch (Err e) err = e
      verifyNotNull(err, "a clock of \"yes\" loaded")
      verify(err.msg.contains("\"yes\""), err.msg)
    }
  }

  ** Run f and return what the hxComps log took meanwhile
  private LogRec[] capture(|->| f)
  {
    Actor.locals["hxComps.test.recs"] = LogRec[,]
    h := |LogRec r| { if (r.logName == "hxComps") (Actor.locals["hxComps.test.recs"] as LogRec[])?.add(r) }
    Log.addHandler(h)
    try f()
    finally Log.removeHandler(h)
    return Actor.locals.remove("hxComps.test.recs")
  }
}
