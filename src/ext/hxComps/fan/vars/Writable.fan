//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Sep 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class NumberPoint : HxComp
{
  /* ionc-start */

  virtual StatusNumber? out() { get("out") }

  /* ionc-end */
}

class NumberWritable : NumberPoint
{
  /* ionc-start */

  virtual StatusNumber? in1() { get("in1") }

  virtual StatusNumber? in2() { get("in2") }

  virtual StatusNumber? in3() { get("in3") }

  virtual StatusNumber? in4() { get("in4") }

  virtual StatusNumber? in5() { get("in5") }

  virtual StatusNumber? in6() { get("in6") }

  virtual StatusNumber? in7() { get("in7") }

  virtual StatusNumber? in8() { get("in8") }

  virtual StatusNumber? in9() { get("in9") }

  virtual StatusNumber? in10() { get("in10") }

  virtual StatusNumber? in11() { get("in11") }

  virtual StatusNumber? in12() { get("in12") }

  virtual StatusNumber? in13() { get("in13") }

  virtual StatusNumber? in14() { get("in14") }

  virtual StatusNumber? in15() { get("in15") }

  virtual StatusNumber? in16() { get("in16") }

  virtual StatusNumber? fallback { get {get("fallback")} set {set("fallback", it)} }

  /* ionc-end */

  override Void onExecute()
  {
    prio := (1..16).eachWhile |i| { get("in${i}") }
    if (prio == null) prio = this.fallback
    set("out", prio)
  }

}

