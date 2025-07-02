//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Mar 2016  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio

**
** HisTest
**
class HisTest  : AbstractFolioTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics() { runImpls }
  Void doTestBasics()
  {
    if (!impl.supportsHis) return

    open

    // bad write rec configuration
    tz := TimeZone("Chicago")
    bads :=
    [
      addRec(["dis":"Bad", "his":m, "tz":tz.name, "kind":"Number"]),
      addRec(["dis":"Bad", "point":m, "tz":tz.name, "kind":"Number"]),
      addRec(["dis":"Bad", "point":m, "his":m, "kind":"Number"]),
      addRec(["dis":"Bad", "point":m, "his":m, "tz":tz.name, ]),
      addRec(["dis":"Bad", "point":m, "his":m, "tz":"Bad!", "kind":"Number"]),
      addRec(["dis":"Bad", "point":m, "his":m, "tz":tz.name, "kind":"Bad!"]),
    ]
    bads.each |bad|
    {
      items := [item(ts("2016-03-01 00:00", tz), n(9))]
      verifyErr(HisConfigErr#) { folio.his.write(bad.id, items) }
    }

    // bad write items
    a := addRec(["dis":"A", "point":m, "his":m, "tz":tz.name, "kind":"Number"])
    verifyErr(HisWriteErr#) { folio.his.write(a.id, [item(ts("2016-03-01 00:00", TimeZone.utc), n(9))]) }
    verifyErr(HisWriteErr#) { folio.his.write(a.id, [item(ts("2016-03-01 00:00", tz), true)]) }
    verifyErr(HisWriteErr#) { folio.his.write(a.id, [item(ts("2016-03-01 00:00", tz), n(9, "%"))]) }

    // empty writes
    verifyEq(folio.his.write(a.id, HisItem[,]).count, 0)

    // verify basic write
    items := [
      item(ts("2016-03-01 00:00", tz), n(3)),
      item(ts("2016-03-01 01:00", tz), n(4)),
      item(ts("2016-03-01 02:00", tz), n(5)),
      item(ts("2016-03-01 03:00", tz), n(6)),
    ]
    verifyEq(folio.his.write(a.id, items).count, 4)

    // basic read
    verifyRead(a, null, items)

    // append couple items
    newItems := [
      item(ts("2016-03-01 04:00", tz), n(6)),
      item(ts("2016-03-01 05:00", tz), n(7)),
    ]
    verifyEq(folio.his.write(a.id, newItems).count, 2)
    items.addAll(newItems)
    verifyRead(a, null, items)

    // prepend couple of items
    newItems = [
      item(ts("2016-02-29 01:00", tz), n(8)),
      item(ts("2016-02-29 03:00", tz), n(9)),
      item(ts("2016-02-29 02:00", tz), n(10)),
    ]
    r := folio.his.write(a.id, newItems).count
    verifyEq(r, 3)
    items.addAll(newItems).sort
    verifyRead(a, null, items)

    // insert couple of items
    newItems = [
      item(ts("2016-02-29 04:30", tz), n(11)),
      item(ts("2016-03-01 04:30", tz), n(12)),
    ]
    r = folio.his.write(a.id, newItems).count
    verifyEq(r, 2)
    items.addAll(newItems).sort
    verifyRead(a, null, items)

    // verify of we remove point tag exception is raised
    a = commit(a, ["point":Remove.val])
    verifyErr(HisConfigErr#) { verifyRead(a, null, items) }
    verifyErr(HisConfigErr#) { verifyRead(a, Span.today, items) }
    verifyErr(HisConfigErr#) { folio.his.write(a.id, [item(DateTime.now.toTimeZone(tz), n(99))]) }

    // add back point and verify it works again
    a = commit(a, ["point":m])
    verifyRead(a, null, items)

    // add trash and verify neither reads not write work
    a = commit(a, ["trash":m])
    verifyErr(HisConfigErr#) { verifyRead(a, null, items) }
    verifyErr(HisConfigErr#) { verifyRead(a, Span.today, items) }
    verifyErr(HisConfigErr#) { folio.his.write(a.id, [item(DateTime.now.toTimeZone(tz), n(99))]) }

    // remove trash
    a = commit(a, ["trash":Remove.val])
    verifyRead(a, null, items)

    // add aux tag
    a = commit(a, ["aux":m])
    verifyErr(HisConfigErr#) { verifyRead(a, null, items) }
    verifyErr(HisConfigErr#) { verifyRead(a, Span.today, items) }
    verifyErr(HisConfigErr#) { folio.his.write(a.id, [item(DateTime.now.toTimeZone(tz), n(99))]) }

    // verify large integers
    b := addRec(["dis":"B", "point":m, "his":m, "tz":tz.name, "kind":"Number"])
    bItems := [
      item(ts("2016-06-07 01:00", tz), n(16791115)),
      item(ts("2016-06-07 02:00", tz), n(16791116)),
      item(ts("2016-06-07 03:00", tz), n(16791117)),
      item(ts("2016-06-07 04:00", tz), n(16791118)),
      item(ts("2016-06-07 05:00", tz), n(0xab_ffff_ffff)),
      item(ts("2016-06-07 06:00", tz), n(0xab_ffff_0123)),
      item(ts("2016-06-07 07:00", tz), n(-16791115)),
      item(ts("2016-06-07 08:00", tz), n(-16791116)),
      item(ts("2016-06-07 09:00", tz), n(-16791117)),
      item(ts("2016-06-07 10:00", tz), n(-16791118)),
      item(ts("2016-06-07 11:00", tz), n(-0xab_ffff_ffff)),
      item(ts("2016-06-07 12:00", tz), n(-0xab_ffff_0123)),
    ]
    folio.his.write(b.id, bItems).count
    verifyRead(b, null, bItems)
  }

//////////////////////////////////////////////////////////////////////////
// Config
//////////////////////////////////////////////////////////////////////////

  Void testConfig() { runImpls }
  Void doTestConfig()
  {
    if (!impl.supportsHis) return

    open

    // create rec with couple items
    tz := TimeZone("Melbourne")
    r := addRec(["dis":"Config", "point":m, "his":m, "tz":tz.name, "kind":"Number"])
    items := [
      item(ts("2016-05-15 12:00", tz), n(1200)),
      item(ts("2016-05-15 12:30", tz), n(1220)),
      item(ts("2016-05-15 13:00", tz), n(1300)),
    ]
    folio.his.write(r.id, items).count
    verifyRead(r, null, items)

    // change tz
    tz = TimeZone("New_York")
    r = commit(r, ["tz":tz.name])
    folio.sync
    items = items.map |item->HisItem| { HisItem(item.ts.toTimeZone(tz), item.val) }
    verifyRead(r, null, items)

    // add unit
    r = commit(r, ["unit":"%"])
    folio.sync
    items = items.map |item->HisItem| { HisItem(item.ts, n(((Number)item.val).toFloat, "%")) }
    verifyRead(r, null, items)

    // change unit
    r = commit(r, ["unit":"kW"])
    folio.sync
    items = items.map |item->HisItem| { HisItem(item.ts, n(((Number)item.val).toFloat, "kW")) }
    verifyRead(r, null, items)

    // remove unit
    r = commit(r, ["unit":Remove.val])
    folio.sync
    items = items.map |item->HisItem| { HisItem(item.ts, n(((Number)item.val).toFloat, null)) }
    verifyRead(r, null, items)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  static HisItem item(DateTime ts, Obj? val)
  {
    HisItem(ts, val)
  }

  static DateTime ts(Str s, TimeZone tz)
  {
    DateTime.fromLocale(s, "YYYY-MM-DD hh:mm", tz)
  }

  Void verifyRead(Dict r, Span? span, HisItem[] expected)
  {
    actual := HisItem[,]
    folio.his.read(r.id, span, null) |item| { actual.add(item) }
    verifyItems(actual, expected)
    if (span == null)
    {
      r = folio.readById(r.id)
      tz := TimeZone.fromStr(r->tz)
      verifyEq(r["hisSize"],  n(actual.size))
      verifyEq(r["hisStart"], actual.first.ts)
      verifyEq(r["hisEnd"],   actual.last.ts)
      verifySame(r["hisStart"]->tz, tz)
      verifySame(r["hisEnd"]->tz, tz)
    }
  }

  Void verifyItems(HisItem[] a, HisItem[] b)
  {
    // echo("#### verifyItems $a.size ?= $b.size")
    min := a.size.min(b.size)
    min.times |i|
    {
      ax := a[i]
      bx := b[i]
      // echo("-- $ax ?= $bx")
      verifyEq(ax, bx)
    }
    verifyEq(a.size, b.size)
  }
}

