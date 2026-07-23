//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Convert a Bool value to a StatusBool
**
@Gen
class BoolToStatusBool : HxComp
{
  @Gen virtual Bool in() { get("in") }

  @Gen virtual StatusBool out() { get("out") }

  override Void onExecute() { set("out", StatusBool(in)) }
}

**
** Convert a Number to a StatusNumber
**
@Gen
class NumberToStatusNumber : HxComp
{
  @Gen virtual Number in() { get("in") }

  @Gen virtual StatusNumber out() { get("out") }

  override Void onExecute() { set("out", StatusNumber(in)) }
}

**
** Convert a Str to a StatusStr
**
@Gen
class StrToStatusStr : HxComp
{
  @Gen virtual Str in() { get("in") }

  @Gen virtual StatusStr out() { get("out") }

  override Void onExecute() { set("out", StatusStr(in)) }
}

