//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Helpers for the continuous component tests
**
abstract class ContinuousCompTest : HxCompTest
{
  static const DateTime t0 := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** Mount c under the root and run f in a simulated context at t0
  Void sim(Comp c, |SimulatedCompContext| f)
  {
    SimulatedCompContext(cs, t0).asCur |cx|
    {
      cs.root.add(c)
      f(cx)
    }
  }

  ** t0 plus s seconds
  static DateTime at(Float s) { t0 + Duration((s * 1e9f).round.toInt) }

  static Void setN(Comp c, Str slot, Float? v, Status s := Status.ok)
  {
    c.set(slot, v == null ? null : StatusNumber(Number(v), s))
  }

  static Void setIn(Comp c, Float? v, Status s := Status.ok) { setN(c, "in", v, s) }

  ** Verify `out` is within tol of the expected value, with the status
  Void verifyOut(Comp c, Float expected, Float tol := 1e-9f, Status status := Status.ok, Str msg := "")
  {
    o := c.get("out") as StatusNumber
    if (o == null) fail("$msg: out is null")
    verify((expected - o.num.toFloat).abs <= tol, "$msg: expected $expected, got $o")
    verifyEq(o.status, status, msg)
  }

  ** Verify `out` is NaN with fault
  Void verifyNaNFault(Comp c)
  {
    o := c.get("out") as StatusNumber
    verifyNotNull(o)
    verify(o.num.toFloat.isNaN && o.status.isFault, "expected NaN {fault}, got $o")
  }

  static Status stale() { Status.ok.set(Status.stale) }
  static Status alarm() { Status.ok.set(Status.alarm) }
  static Status fault() { Status.ok.set(Status.fault) }
}
