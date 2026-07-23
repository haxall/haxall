//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Aug 2025  Matthew Giannini  Creation
//

using xeto

**
** A select sets its output to one of its inputs based on the
** current value of the `select` slot.
**
@Gen
abstract class ValSelect : HxComp
{
  ** The index of the input to select. If the value is greater than `numInputs`
  ** then the maximum active input will be selected.
  @Gen virtual StatusNumber? select { get {get("select")} set {set("select", it)} }

  ** Input A
  @Gen virtual StatusVal? inA() { get("inA") }

  ** Input B
  @Gen virtual StatusVal? inB() { get("inB") }

  ** Input C
  @Gen virtual StatusVal? inC() { get("inC") }

  ** Input D
  @Gen virtual StatusVal? inD() { get("inD") }

  ** Input E
  @Gen virtual StatusVal? inE() { get("inE") }

  ** Input F
  @Gen virtual StatusVal? inF() { get("inF") }

  ** Input G
  @Gen virtual StatusVal? inG() { get("inG") }

  ** Input H
  @Gen virtual StatusVal? inH() { get("inH") }

  ** Input I
  @Gen virtual StatusVal? inI() { get("inI") }

  ** Input J
  @Gen virtual StatusVal? inJ() { get("inJ") }

  ** The out slot is set to the selected input
  @Gen virtual StatusVal? out() { get("out") }

  ** If true, then inputs are indexed by zero (0). If false,
  ** inputs are indexed by 1, and any select <= 1 will select the
  ** first input.
  @Gen virtual Bool zeroBasedSelect { get {get("zeroBasedSelect")} set {set("zeroBasedSelect", it)} }

  ** The number of inputs that are active for selection.
  @Gen virtual Int numInputs { get {get("numInputs")} set {set("numInputs", it)} }

  override Void onExecute()
  {
    index := this.select?.num?.toInt
    if (index == null) return set("out", null)

    if (zeroBasedSelect) ++index
    index = index.max(1).min(numInputs)

    val := selectInput(index)
    // TODO:FIXIT - should we merge in status from select slot? if so we
    // need a generic way (API) on StatusVal to merge in status and get new instance
    set("out", val)
  }

  private StatusVal? selectInput(Int index)
  {
    switch (index)
    {
      case 1:  return inA
      case 2:  return inB
      case 3:  return inC
      case 4:  return inD
      case 5:  return inE
      case 6:  return inF
      case 7:  return inG
      case 8:  return inH
      case 9:  return inI
      case 10: return inJ
      default: return null
    }
  }

}

**
** Bool select
**
@Gen
class BoolSelect : ValSelect
{
  ** Input A
  @Gen override StatusStr? inA() { get("inA") }

  ** Input B
  @Gen override StatusStr? inB() { get("inB") }

  ** Input C
  @Gen override StatusStr? inC() { get("inC") }

  ** Input D
  @Gen override StatusStr? inD() { get("inD") }

  ** Input E
  @Gen override StatusStr? inE() { get("inE") }

  ** Input F
  @Gen override StatusStr? inF() { get("inF") }

  ** Input G
  @Gen override StatusStr? inG() { get("inG") }

  ** Input H
  @Gen override StatusStr? inH() { get("inH") }

  ** Input I
  @Gen override StatusStr? inI() { get("inI") }

  ** Input J
  @Gen override StatusStr? inJ() { get("inJ") }
}

**
** Number select
**
@Gen
class NumberSelect : ValSelect
{
  ** Input A
  @Gen override StatusNumber? inA() { get("inA") }

  ** Input B
  @Gen override StatusNumber? inB() { get("inB") }

  ** Input C
  @Gen override StatusNumber? inC() { get("inC") }

  ** Input D
  @Gen override StatusNumber? inD() { get("inD") }

  ** Input E
  @Gen override StatusNumber? inE() { get("inE") }

  ** Input F
  @Gen override StatusNumber? inF() { get("inF") }

  ** Input G
  @Gen override StatusNumber? inG() { get("inG") }

  ** Input H
  @Gen override StatusNumber? inH() { get("inH") }

  ** Input I
  @Gen override StatusNumber? inI() { get("inI") }

  ** Input J
  @Gen override StatusNumber? inJ() { get("inJ") }
}

**
** Str select
**
@Gen
class StrSelect : ValSelect
{
  ** Input A
  @Gen override StatusStr? inA() { get("inA") }

  ** Input B
  @Gen override StatusStr? inB() { get("inB") }

  ** Input C
  @Gen override StatusStr? inC() { get("inC") }

  ** Input D
  @Gen override StatusStr? inD() { get("inD") }

  ** Input E
  @Gen override StatusStr? inE() { get("inE") }

  ** Input F
  @Gen override StatusStr? inF() { get("inF") }

  ** Input G
  @Gen override StatusStr? inG() { get("inG") }

  ** Input H
  @Gen override StatusStr? inH() { get("inH") }

  ** Input I
  @Gen override StatusStr? inI() { get("inI") }

  ** Input J
  @Gen override StatusStr? inJ() { get("inJ") }
}

