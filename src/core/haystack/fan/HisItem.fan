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

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    v := get(name)
    if (v != null) return v
    throw UnknownNameErr(name)
  }

  override Void each(|Obj, Str| f)
  {
    f(ts, "ts")
    if (val != null) f(val, "val")
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    r := f(ts, "ts");
    if (r != null) return r
    if (val != null) return f(val, "val")
    return null
  }

  override This map(|Obj val, Str name->Obj| f)
  {
    make(f(ts, "ts"), f(val, "val"))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Return a new `HisItem` with the same timestamp as this one, and with
  ** val set to the result of calling 'f' with this item's current val.
  @NoDoc HisItem mapVal(|Obj?->Obj?| f) { make(ts, f(val)) }

//////////////////////////////////////////////////////////////////////////
// Binary Encoding
//////////////////////////////////////////////////////////////////////////

  **
  ** Encode list of history items into a simple but compact binary encoding.
  **
  @NoDoc static Void encode(OutStream out, HisItem[] items)
  {
    [Str:Int]? strMap := null
    tsPrev := 0
    valPrev := null
    float := 0f
    int := 0
    str := ""

    out.writeI2(magic)
    out.writeI2(version)
    out.writeI4(items.size)
    items.each |item|
    {
      // determine how to encode timestamp 8 bytes or 4 byte diff
      ts := item.ts.ticks / 1ms.ticks
      diff := ts - tsPrev
      ts8 := diff > 0x7fff_ffff
      ctrl := ts8 ? ctrlTs8 : ctrlTs4Prev

      // determine how to encode value
      val := item.val
      if (val != valPrev)
      {
        if (val is Number)
        {
          num := (Number)val
          ctrl = ctrl.or(ctrlF8)
          float = num.toFloat
        }
        else if (val is Bool)
        {
          bool := (Bool)val
          ctrl = ctrl.or(bool ? ctrlTrue : ctrlFalse)
        }
        else if (val === NA.val)
        {
          ctrl = ctrl.or(ctrlNA)
        }
        else
        {
          str = val.toStr
          if (strMap == null) strMap = Str:Int[:]
          prevIndex := strMap[str]
          if (prevIndex == null)
          {
            ctrl = ctrl.or(ctrlStr)
            strMap[str] = strMap.size
          }
          else
          {
            ctrl = ctrl.or(ctrlStrPrev)
            int = prevIndex
          }
        }
      }

      // write control byte
      out.write(ctrl)

      // write timestamp
      if (ts8)
        out.writeI8(ts)
      else
        out.writeI4(diff)

      // write value
      switch (ctrl.and(0x0F))
      {
        case ctrlF8:      out.writeF8(float)
        case ctrlStr:     out.writeUtf(str)
        case ctrlStrPrev: out.writeI4(int)
      }

      // keep track of last timestamp/value
      tsPrev = ts
      valPrev = val
    }
  }

  **
  ** Decode from the simple binary encoding.
  **
  @NoDoc static HisItem[] decode(InStream in, TimeZone tz, Unit? unit := null)
  {
    if (in.readU2 != magic) throw IOErr("Invalid magic")
    if (in.readU2 != version) throw IOErr("Invalid version")
    size := in.readU4

    acc := HisItem[,]
    acc.capacity = size
    millis := 0
    prev := null
    Str[]? strMap

    for (i := 0; i<size; ++i)
    {
      // read ctrl byte
      ctrl := in.read

      // decode timestamp
      switch (ctrl.and(0xF0))
      {
        case ctrlTs8:     millis = in.readS8
        case ctrlTs4Prev: millis = millis + in.readU4
        default:          throw IOErr("ts ctrl 0x$ctrl.toHex")
      }
      ts := DateTime.makeTicks(millis * 1ms.ticks, tz)

      // decode value
      Obj? val
      switch (ctrl.and(0x0F))
      {
        case ctrlPrev:    val = prev
        case ctrlFalse:   val = false
        case ctrlTrue:    val = true
        case ctrlNA:      val = NA.val
        case ctrlF8:      val = Number(in.readF8, unit)
        case ctrlStr:     val = in.readUtf; if (strMap == null) strMap = Str[,]; strMap.add(val)
        case ctrlStrPrev: val = strMap[in.readU4]
        default:          throw IOErr("val ctrl 0x$ctrl.toHex")
      }

      acc.add(HisItem(ts, val))
      prev = val
    }

    return acc
  }

  private static const Int magic       := 0x6268 // bh for binary history
  private static const Int version     := 1      // version 1
  private static const Int ctrlTs8     := 0x10   // timestamp is encoding as 8-byte milliseconds since epoch
  private static const Int ctrlTs4Prev := 0x20   // timestamp is 4-byte unsigned integer milliseconds after prev timestamp
  private static const Int ctrlPrev    := 0x00   // use previous value (no further bytes)
  private static const Int ctrlFalse   := 0x01   // value is false (no further bytes)
  private static const Int ctrlTrue    := 0x02   // value is true (no further bytes)
  private static const Int ctrlNA      := 0x03   // value is NA (no further bytes)
  private static const Int ctrlF8      := 0x04   // float 64-bit value (next 8 bytes are floating point number)
  private static const Int ctrlStr     := 0x05   // new string value (next bytes are Java/Fantom UTF-8 string)
  private static const Int ctrlStrPrev := 0x06   // previous string value (next four bytes are index)
}

