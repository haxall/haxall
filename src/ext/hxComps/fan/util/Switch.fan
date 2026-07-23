//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Aug 2025  Matthew Giannini  Creation
//

using xeto

**
** A switch selects one of two inputs based on the current value of the `inSwitch` slot.
**
@Gen
abstract class ValSwitch : HxComp
{
  ** If true, then the output is set to `inTrue`. Otherwise it is set to `inFalse`
  @Gen virtual StatusBool? inSwitch() { get("inSwitch") }

  ** The output value when `inSwitch` is true
  @Gen virtual StatusVal? inTrue() { get("inTrue") }

  ** The output value when `inSwitch` is false
  @Gen virtual StatusVal? inFalse() { get("inFalse") }

  ** The output
  @Gen virtual StatusVal? out() { get("out") }

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
** Bool switch
**
@Gen
class BoolSwitch : ValSwitch
{
  ** If true, then the output is set to `inTrue`. Otherwise it is set to `inFalse`
  @Gen override StatusBool? inSwitch() { get("inSwitch") }

  ** The output value when `inSwitch` is true
  @Gen override StatusBool? inTrue() { get("inTrue") }

  ** The output value when `inSwitch` is false
  @Gen override StatusBool? inFalse() { get("inFalse") }

  ** The output
  @Gen override StatusBool? out() { get("out") }
}

**
** Number switch
**
@Gen
class NumberSwitch : ValSwitch
{
  ** If true, then the output is set to `inTrue`. Otherwise it is set to `inFalse`
  @Gen override StatusBool? inSwitch() { get("inSwitch") }

  ** The output value when `inSwitch` is true
  @Gen override StatusNumber? inTrue() { get("inTrue") }

  ** The output value when `inSwitch` is false
  @Gen override StatusNumber? inFalse() { get("inFalse") }

  ** The output
  @Gen override StatusNumber? out() { get("out") }
}

**
** Str switch
**
@Gen
class StrSwitch : ValSwitch
{
  ** If true, then the output is set to `inTrue`. Otherwise it is set to `inFalse`
  @Gen override StatusBool? inSwitch() { get("inSwitch") }

  ** The output value when `inSwitch` is true
  @Gen override StatusStr? inTrue() { get("inTrue") }

  ** The output value when `inSwitch` is false
  @Gen override StatusStr? inFalse() { get("inFalse") }

  ** The output
  @Gen override StatusStr? out() { get("out") }
}

