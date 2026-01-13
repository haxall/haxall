//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Mar 2025  Matthew Giannini  Creation
//

using haystack
using xeto

abstract class PointVar : EntityVar
{
  /* ionc-start */

  virtual Ref? bindSpec { get {get("bindSpec")} set {set("bindSpec", it)} }

  /* ionc-end */
}

abstract class PointInput : PointVar
{
  /* ionc-start */

  virtual StatusVal? curVal() { get("curVal") }

  /* ionc-end */

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

class NumberPointInput : PointInput
{
  /* ionc-start */

  override StatusNumber? curVal() { get("curVal") }

  /* ionc-end */
}

class BoolPointInput : PointInput
{
  /* ionc-start */

  override StatusBool? curVal() { get("curVal") }

  /* ionc-end */
}

class StrPointInput : PointInput
{
  /* ionc-start */

  override StatusStr? curVal() { get("curVal") }

  /* ionc-end */
}

abstract class PointOutput : PointVar
{
  /* ionc-start */

  virtual StatusVal? in() { get("in") }

  ** bindToCurVal: Marker?
  virtual Int? bindToWriteLevel { get {get("bindToWriteLevel")} set {set("bindToWriteLevel", it)} }

  /* ionc-end */

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

