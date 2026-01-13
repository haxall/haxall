//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Aug 2025  Matthew Giannini  Creation
//

abstract class Select : HxComp
{
  /* ionc-start */

  ** The index of the input to select. If the value is greater than 'numInputs'
  ** then the maximum active input will be selected.
  virtual StatusNumber? select { get {get("select")} set {set("select", it)} }

  ** Input A
  virtual StatusVal? inA() { get("inA") }

  ** Input B
  virtual StatusVal? inB() { get("inB") }

  ** Input C
  virtual StatusVal? inC() { get("inC") }

  ** Input D
  virtual StatusVal? inD() { get("inD") }

  ** Input E
  virtual StatusVal? inE() { get("inE") }

  ** Input F
  virtual StatusVal? inF() { get("inF") }

  ** Input G
  virtual StatusVal? inG() { get("inG") }

  ** Input H
  virtual StatusVal? inH() { get("inH") }

  ** Input I
  virtual StatusVal? inI() { get("inI") }

  ** Input J
  virtual StatusVal? inJ() { get("inJ") }

  ** The out slot is set to the selected input
  virtual StatusVal? out() { get("out") }

  ** If true, then inputs are indexed by zero (0). If false,
  ** inputs are indexed by 1, and any select <= 1 will select the
  ** first input.
  virtual Bool zeroBasedSelect { get {get("zeroBasedSelect")} set {set("zeroBasedSelect", it)} }

  ** The number of inputs that are active for selection.
  virtual Int numInputs { get {get("numInputs")} set {set("numInputs", it)} }

  /* ionc-end */

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
** A Bool select
**
class BoolSelect : Select
{
  /* ionc-start */

  ** Input A
  override StatusStr? inA() { get("inA") }

  ** Input B
  override StatusStr? inB() { get("inB") }

  ** Input C
  override StatusStr? inC() { get("inC") }

  ** Input D
  override StatusStr? inD() { get("inD") }

  ** Input E
  override StatusStr? inE() { get("inE") }

  ** Input F
  override StatusStr? inF() { get("inF") }

  ** Input G
  override StatusStr? inG() { get("inG") }

  ** Input H
  override StatusStr? inH() { get("inH") }

  ** Input I
  override StatusStr? inI() { get("inI") }

  ** Input J
  override StatusStr? inJ() { get("inJ") }

  /* ionc-end */
}

**
** A Number select
**
class NumberSelect : Select
{
  /* ionc-start */

  ** Input A
  override StatusNumber? inA() { get("inA") }

  ** Input B
  override StatusNumber? inB() { get("inB") }

  ** Input C
  override StatusNumber? inC() { get("inC") }

  ** Input D
  override StatusNumber? inD() { get("inD") }

  ** Input E
  override StatusNumber? inE() { get("inE") }

  ** Input F
  override StatusNumber? inF() { get("inF") }

  ** Input G
  override StatusNumber? inG() { get("inG") }

  ** Input H
  override StatusNumber? inH() { get("inH") }

  ** Input I
  override StatusNumber? inI() { get("inI") }

  ** Input J
  override StatusNumber? inJ() { get("inJ") }

  /* ionc-end */
}

**
** A Str select
**
class StrSelect : Select
{
  /* ionc-start */

  ** Input A
  override StatusStr? inA() { get("inA") }

  ** Input B
  override StatusStr? inB() { get("inB") }

  ** Input C
  override StatusStr? inC() { get("inC") }

  ** Input D
  override StatusStr? inD() { get("inD") }

  ** Input E
  override StatusStr? inE() { get("inE") }

  ** Input F
  override StatusStr? inF() { get("inF") }

  ** Input G
  override StatusStr? inG() { get("inG") }

  ** Input H
  override StatusStr? inH() { get("inH") }

  ** Input I
  override StatusStr? inI() { get("inI") }

  ** Input J
  override StatusStr? inJ() { get("inJ") }

  /* ionc-end */
}

