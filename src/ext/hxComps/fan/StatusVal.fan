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
** Status and scalar value
**
const mixin StatusVal : Dict
{

  ** Get the status flags
  abstract Status status()

  ** Get the scalar value
  abstract Obj val()

  ** <val> {<status>}
  override Str toStr() { "${val} {${status}}"}
}

**************************************************************************
** StatusNumber
**************************************************************************

**
** Status and number value
**
const mixin StatusNumber : StatusVal
{
  ** Constructor
  static new make(Number val := Number.zero, Status status := Status.ok) { MStatusNumber(val, status) }

  ** Get the scalar number value
  abstract Number num()
}

**************************************************************************
** StatusBool
**************************************************************************

**
** Status and boolean value
**
const mixin StatusBool : StatusVal
{
  ** Constructor
  static new make(Bool val := false, Status status := Status.ok) { MStatusBool(val, status) }

  ** Get the scalar value
  abstract Bool bool()
}


**************************************************************************
** StatusStr
**************************************************************************

**
** Status and string value
**
const mixin StatusStr : StatusVal
{
  ** Constructor
  static new make(Str val := "", Status status := Status.ok) { MStatusStr(val, status) }

  ** Get the scalar value
  abstract Str str()
}

**************************************************************************
** MStatusVal
**************************************************************************

** StatusVal implementation
@NoDoc
const abstract class MStatusVal: StatusVal
{

//////////////////////////////////////////////////////////////////////////
// Obj
//////////////////////////////////////////////////////////////////////////

  override Bool equals(Obj? that)
  {
    a := this
    b := that as MStatusVal
    if (b == null) return false
    return a.val == b.val && a.status == b.status
  }

  override Int hash()
  {
    val.hash.xor(status.hash)
  }

  override Int compare(Obj that)
  {
    a := this
    b := that as MStatusVal
    cmp := a.val <=> b.val
    if (cmp != 0) return cmp
    return a.status <=> b.status
  }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str name)
  {
    if (name == "val")    return val
    if (name == "status") return status
    if (name == "spec")   return mySpecRef
    return null
  }
  override Bool has(Str name)
  {
    get(name) != null
  }

  override Bool missing(Str name)
  {
    get(name) == null
  }

  override Void each(|Obj, Str| f)
  {
    f(val,       "val")
    f(status,    "status")
    f(mySpecRef, "spec")
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    Obj? r
    r = f(val,    "val");    if (r != null) return r
    r = f(status, "status"); if (r != null) return r
    return f(mySpecRef, "spec")
  }

  override Obj? trap(Str n, Obj?[]? a := null)
  {
    v := get(n)
    if (v != null) return v
    throw UnknownNameErr(n)
  }

  abstract Ref mySpecRef()

}

**************************************************************************
** MStatusVal Subtypes
**************************************************************************

@NoDoc
const final class MStatusNumber: MStatusVal, StatusNumber
{
  static const Ref specRef := Ref("hx.comps::StatusNumber")
  static new fromDict(Dict d) {make(d["val"] as Number ?: Number.zero, d["status"] as Status ?: Status.ok) }
  new make(Number v, Status s) { this.num = v; this.status = s}
  override Obj val() { num }
  override const Number num
  override const Status status
  override Ref mySpecRef() { specRef }
}

@NoDoc
const final class MStatusBool: MStatusVal, StatusBool
{
  static const Ref specRef := Ref("hx.comps::StatusBool")
  static new fromDict(Dict d) {make(d["val"] as Bool ?: false, d["status"] as Status ?: Status.ok) }
  new make(Bool v, Status s) { this.bool = v; this.status = s}
  override Obj val() { bool }
  override const Bool bool
  override const Status status
  override Ref mySpecRef() { specRef }
}

@NoDoc
const final class MStatusStr: MStatusVal, StatusStr
{
  static const Ref specRef := Ref("hx.comps::StatusStr")
  static new fromDict(Dict d) {make(d["val"] as Str ?: "", d["status"] as Status ?: Status.ok) }
  new make(Str v, Status s) { this.str = v; this.status = s}
  override Obj val() { str }
  override const Str str
  override const Status status
  override Ref mySpecRef() { specRef }
}

