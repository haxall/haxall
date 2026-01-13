//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Sep 2024  Brian Frank  Creation
//

using xeto
using haystack

**
** StatusTest
**
class StatusTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Status
//////////////////////////////////////////////////////////////////////////

  Void testStatus()
  {
    // ok
    verifyStatus(Status.ok, [,])

    // fromName
    names.each |n|
    {
      verifyStatus(Status.fromName(n), [n])
    }

    // constants
    verifyStatus(Status.alarm,      ["alarm"])
    verifyStatus(Status.disabled,   ["disabled"])
    verifyStatus(Status.down,       ["down"])
    verifyStatus(Status.fault,      ["fault"])
    verifyStatus(Status.overridden, ["overridden"])
    verifyStatus(Status.stale,      ["stale"])
    verifyStatus(Status.unacked,    ["unacked"])

    // fromCurStatus
    verifySame(Status.fromCurStatus("ok"), Status.ok)
    verifySame(Status.fromCurStatus("down"), Status.down)
    verifySame(Status.fromCurStatus("disabled"), Status.disabled)
    verifySame(Status.fromCurStatus("fault"), Status.fault)
    verifySame(Status.fromCurStatus("unknown"), Status.down)
    verifySame(Status.fromCurStatus("remoteDown"), Status.down)
    verifySame(Status.fromCurStatus("remoteDisabled"), Status.disabled)
    verifySame(Status.fromCurStatus("remoteFault"), Status.fault)
    verifySame(Status.fromCurStatus("remoteUnknown"), Status.down)
    verifySame(Status.fromCurStatus(null), Status.fault)
    verifySame(Status.fromCurStatus("foo"), Status.fault)

    // set and clear
    x := Status.alarm.set(Status.down)
    verifyStatus(x, ["alarm", "down"])
    x = Status.unacked.set(x)
    verifyStatus(x, ["alarm", "down", "unacked"])
    x = x.clear(Status.down)
    verifyStatus(x, ["alarm", "unacked"])
    x = x.set(Status.fault).set(Status.stale).set(Status.unacked)
    verifyStatus(x, ["alarm","fault", "stale", "unacked"])
    x = x.clear(Status.fault.set(Status.stale))
    verifyStatus(x, ["alarm", "unacked"])

    // merge
    a := Status.alarm.set(Status.down)
    b := Status.fault.set(Status.unacked)
    verifyStatus(a.merge(b), ["alarm", "down", "fault", "unacked"])

    // XetoFactory
    verifyStatus(parse("Status {}"), [,])
    verifyStatus(parse("Status { fault }"), ["fault"])
    verifyStatus(parse("Status { fault, alarm }"), ["fault", "alarm"])
    verifyStatus(parse("Status { fault, alarm, ignore }"), ["fault", "alarm"])
  }

  Void verifyStatus(Status s, Str[] tags)
  {
    // echo("--> $s")
    verifyEq(s.isOk,    tags.isEmpty)

    verifyEq(s.isAlarm,      tags.contains("alarm"))
    verifyEq(s.isDisabled,   tags.contains("disabled"))
    verifyEq(s.isDown,       tags.contains("down"))
    verifyEq(s.isFault,      tags.contains("fault"))
    verifyEq(s.isOverridden, tags.contains("overridden"))
    verifyEq(s.isStale,      tags.contains("stale"))
    verifyEq(s.isUnacked,    tags.contains("unacked"))
    verifyEq(!s.isValid,     tags.containsAny(["disabled","down","fault","stale"]))

    names.each |n|
    {
      has := tags.contains(n)
      verifyEq(s.get(n), has ? Marker.val : null)
      verifyEq(s.has(n), has)
      verifyEq(s.missing(n), !has)
      if (has) verifyEq(s.trap(n), Marker.val)
      else verifyErr(UnknownNameErr#) { s.trap(n) }
    }

    expectDict := Str:Obj["spec":Ref("hx.comps::Status")]
    tags.each |n| { expectDict[n] = Marker.val }
    verifyDictEq(s, expectDict)
  }

  const Str[] names := ["alarm", "disabled", "down", "fault", "overridden", "stale", "unacked"]

//////////////////////////////////////////////////////////////////////////
// StatusVals
//////////////////////////////////////////////////////////////////////////

  Void testStatusNumber()
  {
    v := n(123, "kW")
    s := Status.ok
    x := StatusNumber(v, s)
    verifySame(x.val, v)
    verifySame(x.num, v)
    verifySame(x.status, s)
    verifyStatusVal(x, v, s, "StatusNumber")
    verifyEq(x, StatusNumber(v, s))
    verifyStatusVal(parse("StatusNumber {}"), n(0f), Status.ok, "StatusNumber")
    verifyStatusVal(parse("StatusNumber { val:78kW }"), n(78, "kW"), Status.ok, "StatusNumber")
    verifyStatusVal(parse("StatusNumber { val:78kW, status:{fault,unacked} }"), n(78, "kW"),
      Status.fault.set(Status.unacked), "StatusNumber")
  }

  Void testStatusBool()
  {
    v := true
    s := Status.alarm.set(Status.unacked)
    x := StatusBool(v, s)
    verifySame(x.val, v)
    verifySame(x.bool, v)
    verifySame(x.status, s)
    verifyStatusVal(x, v, s, "StatusBool")
    verifyEq(x, StatusBool(v, s))
    verifyStatusVal(parse("StatusBool {}"), false, Status.ok, "StatusBool")
    verifyStatusVal(parse("StatusBool { val:\"true\" }"), true, Status.ok, "StatusBool")
    verifyStatusVal(parse("StatusBool { status:{fault,unacked} }"), false,
      Status.fault.set(Status.unacked), "StatusBool")
  }

  Void testStatusStr()
  {
    v := "hi"
    s := Status.fault
    x := StatusStr(v, s)
    verifySame(x.val, v)
    verifySame(x.str, v)
    verifySame(x.status, s)
    verifyStatusVal(x, v, s, "StatusStr")
    verifyEq(x, StatusStr(v, s))
    verifyStatusVal(parse("StatusStr {}"), "", Status.ok, "StatusStr")
    verifyStatusVal(parse("StatusStr { val:\"hi\" }"), "hi", Status.ok, "StatusStr")
    verifyStatusVal(parse("StatusStr { status:{fault,unacked} }"), "",
      Status.fault.set(Status.unacked), "StatusStr")
  }

  Void verifyStatusVal(StatusVal x, Obj v, Status s, Str specName)
  {
    verifyEq(x.val, v)
    verifySame(x.status, s)

    verifyEq(x->val, v)
    verifySame(x->status, s)

    expectDict := Str:Obj["spec":Ref("hx.comps::$specName"), "val":v, "status":s]
    verifyDictEq(x, expectDict)
  }

//////////////////////////////////////////////////////////////////////////
// Comp
//////////////////////////////////////////////////////////////////////////

  Void testComp()
  {
    spec := ns.spec("hx.comps::Multiply")
    verifyEq(spec.binding.type, Multiply#)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  once Namespace ns()
  {
    XetoEnv.cur.createNamespaceFromNames(["hx.comps"])
  }

  Obj parse(Str xeto)
  {
    x := this.ns.io.readXeto(xeto)
    // echo("parse $xeto => $x [$x.typeof]")
    return x
  }

}

