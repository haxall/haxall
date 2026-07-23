//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Mar 2025  Matthew Giannini  Creation
//

using haystack
using xeto

**
** Variable bound to a point rec
**
@Gen
abstract class PointVar : EntityVar
{
  @Gen virtual Ref? bindSpec { get {get("bindSpec")} set {set("bindSpec", it)} }
}

**
** The base spec for point inputs. Outputs the current value of the bound point.
**
@Gen
abstract class PointInput : PointVar
{
  @Gen virtual StatusVal? curVal() { get("curVal") }

  override StatusVal? bindOut() { this.curVal }

  override Void onChange(CompChangeEvent e)
  {
    if (e.name == "val") onChangeVal(e.newVal)
  }

  private Void onChangeVal(Dict? rec)
  {
    recCurVal     := rec?.get("curVal")
    StatusVal? sv := null
    if (recCurVal != null)
    {
      status := Status.fromCurStatus(rec["curStatus"])
      switch (recCurVal.typeof)
      {
        case Number#: sv = StatusNumber(recCurVal, status)
        case Bool#:   sv = StatusBool(recCurVal, status)
        case Str#:    sv = StatusStr(recCurVal, status)
        default:      sv = null
      }
    }

    this.set("curVal", sv)
  }
}

**
** Number point input
**
@Gen
class NumberPointInput : PointInput
{
  @Gen override StatusNumber? curVal() { get("curVal") }
}

**
** Bool point input
**
@Gen
class BoolPointInput : PointInput
{
  @Gen override StatusBool? curVal() { get("curVal") }
}

**
** Str point input
**
@Gen
class StrPointInput : PointInput
{
  @Gen override StatusStr? curVal() { get("curVal") }
}

**
** The base spec for point outputs. Writes its input value to the bound point.
**
@Gen
abstract class PointOutput : PointVar
{
  @Gen virtual StatusVal? in() { get("in") }

  ** bindToCurVal: Marker?
  @Gen virtual Int? bindToWriteLevel { get {get("bindToWriteLevel")} set {set("bindToWriteLevel", it)} }

  override StatusVal? bindOut() { this.in }
}

class NumberPointOutput : PointOutput
{
  StatusNumber? statusNumber() { in }
}

class BoolPointOutput : PointOutput
{
  StatusBool? statusBool() { in }
}

class StrPointOutput : PointOutput
{
  StatusStr? statusStr() { in }
}

