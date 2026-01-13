//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** A digital input demultiplexer
**
class DigitalInputDemux : HxComp
{
  /* ionc-start */

  ** The input
  virtual StatusNumber? in() { get("in") }

  virtual Float offset { get {get("offset")} set {set("offset", it)} }

  virtual StatusBool? out1() { get("out1") }

  virtual StatusBool? out2() { get("out2") }

  virtual StatusBool? out3() { get("out3") }

  virtual StatusBool? out4() { get("out4") }

  virtual Float out1Value { get {get("out1Value")} set {set("out1Value", it)} }

  virtual Float out2Value { get {get("out2Value")} set {set("out2Value", it)} }

  virtual Float out3Value { get {get("out3Value")} set {set("out3Value", it)} }

  virtual Float out4Value { get {get("out4Value")} set {set("out4Value", it)} }

  virtual Float deadband { get {get("deadband")} set {set("deadband", it)} }

  /* ionc-end */

  override Void onExecute()
  {
    val := in?.num?.toFloat
    if (val == null)
    {
      set("out1", null)
      set("out2", null)
      set("out3", null)
      set("out4", null)
      return
    }
    else val += offset

    v1 := out1Value
    v2 := out2Value
    v3 := out3Value
    v4 := out4Value

    o1 := false
    o2 := false
    o3 := false
    o4 := false

    status := in.status

    deadband := this.deadband
    if (deadband > 0f) deadband /= 2.0f

    eq := |Float a, Float b->Bool| {
      upper := b + deadband
      lower := b - deadband
      return (upper.approx(a) || upper > a) && (lower.approx(a) || lower < a)
    }

    if (eq(val, v1))
    {
      o1 = true
    }
    else if (eq(val, v1+v2))
    {
      o1 = true
      o2 = true
    }
    else if (eq(val, v1+v3))
    {
      o1 = true
      o3 = true
    }
    else if (eq(val, v1+v4))
    {
      o1 = true
      o4 = true
    }
    else if (eq(val, v1+v2+v3))
    {
      o1 = true
      o2 = true
      o3 = true
    }
    else if (eq(val, v1+v2+v4))
    {
      o1 = true
      o2 = true
      o4 = true
    }
    else if (eq(val, v1+v3+v4))
    {
      o1 = true
      o3 = true
      o4 = true
    }
    else if (eq(val, v1+v2+v3+v4))
    {
      o1 = true
      o2 = true
      o3 = true
      o4 = true
    }
    else if (eq(val, v2))
    {
      o2 = true
    }
    else if (eq(val, v2+v3))
    {
      o2 = true
      o3 = true
    }
    else if (eq(val, v2+v4))
    {
      o2 = true
      o4 = true
    }
    else if (eq(val, v2+v3+v4))
    {
      o2 = true
      o3 = true
      o4 = true
    }
    else if (eq(val, v3))
    {
      o3 = true
    }
    else if (eq(val, v3+v4))
    {
      o3 = true
      o4 = true
    }
    else if (eq(val, v4))
    {
      o4 = true
    }

    set("out1", StatusBool(o1, status))
    set("out2", StatusBool(o2, status))
    set("out3", StatusBool(o3, status))
    set("out4", StatusBool(o4, status))
  }
}

