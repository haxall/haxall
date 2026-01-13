//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Aug 2025  Matthew Giannini  Creation
//

**
** A switch selectes one of two inputs based on the current value of the 'inSwitch' slot.
**
abstract class Switch : HxComp
{
  /* ionc-start */

  ** If true, then the output is set to 'inTrue'. Otherwise it is set to 'inFalse'
  virtual StatusBool? inSwitch() { get("inSwitch") }

  ** The output value when 'inSwitch' is true
  virtual StatusVal? inTrue() { get("inTrue") }

  ** The output value when 'inSwitch' is false
  virtual StatusVal? inFalse() { get("inFalse") }

  ** The output
  virtual StatusVal? out() { get("out") }

  /* ionc-end */

  override Void onExecute()
  {
    if (inSwitch == null) return set("out", null)

    StatusVal? selected
    if (inSwitch.status.isValid)
    {
      selected = inSwitch.bool ? inTrue : inFalse
    }
    else
    {
      selected = out
    }
    set("out", selected)
  }
}

**
** A Bool switch
**
class BoolSwitch : Switch
{
  /* ionc-start */

  ** If true, then the output is set to 'inTrue'. Otherwise it is set to 'inFalse'
  override StatusBool? inSwitch() { get("inSwitch") }

  ** The output value when 'inSwitch' is true
  override StatusBool? inTrue() { get("inTrue") }

  ** The output value when 'inSwitch' is false
  override StatusBool? inFalse() { get("inFalse") }

  ** The output
  override StatusBool? out() { get("out") }

  /* ionc-end */
}

**
** A Number switch
**
class NumberSwitch : Switch
{
  /* ionc-start */

  ** If true, then the output is set to 'inTrue'. Otherwise it is set to 'inFalse'
  override StatusBool? inSwitch() { get("inSwitch") }

  ** The output value when 'inSwitch' is true
  override StatusNumber? inTrue() { get("inTrue") }

  ** The output value when 'inSwitch' is false
  override StatusNumber? inFalse() { get("inFalse") }

  ** The output
  override StatusNumber? out() { get("out") }

  /* ionc-end */
}

**
** A Str switch
**
class StrSwitch : Switch
{
  /* ionc-start */

  ** If true, then the output is set to 'inTrue'. Otherwise it is set to 'inFalse'
  override StatusBool? inSwitch() { get("inSwitch") }

  ** The output value when 'inSwitch' is true
  override StatusStr? inTrue() { get("inTrue") }

  ** The output value when 'inSwitch' is false
  override StatusStr? inFalse() { get("inFalse") }

  ** The output
  override StatusStr? out() { get("out") }

  /* ionc-end */
}

