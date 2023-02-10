//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Feb 2009  Brian Frank  Creation
//   21 Jun 2009  Brian Frank  Rework for new tag design
//    9 Mar 2009  Brian Frank  Refactor for 3.0
//

**
** HisItem is a timestamp/value pair.
**
@Js
const final class HisItem : Dict
{

  ** Construct timestamp/value pair.
  new make(DateTime ts, Obj? val)
  {
    this.ts = ts
    this.val = val
  }

  ** Timestamp of the history record.
  const DateTime ts

  ** Value at the timestamp.
  const Obj? val

  ** Equality is based on timestamp and value.
  override Bool equals(Obj? that)
  {
    x := that as HisItem
    if (x == null) return false
    return ts == x.ts && val == x.val
  }

  ** Hash code is based on timestamp and value.
  override Int hash() { ts.hash.xor(val?.hash ?: 0) }

  ** Ordering is based on timestamp.
  override Int compare(Obj that) { ts <=> ((HisItem)that).ts }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str name, Obj? def := null)
  {
    if (name == "ts")  return ts
    if (name == "val") return val
    return def
  }

  override Bool has(Str name) { name == "ts" || name == "val" }

  override Bool missing(Str name) { !has(name) }

  override Void each(|Obj, Str| f)
  {
    f(ts, "ts")
    if (val != null) f(val, "val")
  }

  override Obj? eachWhile(|Obj, Str->Obj?| f)
  {
    r := f(ts, "ts");
    if (r == null) return r
    if (val != null) return f(val, "val")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Return a new `HisItem` with the same timestamp as this one, and with
  ** val set to the result of calling 'f' with this item's current val.
  @NoDoc HisItem mapVal(|Obj?->Obj?| f) { make(ts, f(val)) }

}