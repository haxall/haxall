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
class BoolToStatusBool : HxComp
{
  /* ionc-start */

  virtual Bool in() { get("in") }

  virtual StatusBool out() { get("out") }

  /* ionc-end */

  override Void onExecute() { set("out", StatusBool(in)) }
}

**
** Convert a Number to a StatusNumber
**
class NumberToStatusNumber : HxComp
{
  /* ionc-start */

  virtual Number in() { get("in") }

  virtual StatusNumber out() { get("out") }

  /* ionc-end */

  override Void onExecute() { set("out", StatusNumber(in)) }
}

**
** Convert a Str to a StatusStr
**
class StrToStatusStr : HxComp
{
  /* ionc-start */

  virtual Str in() { get("in") }

  virtual StatusStr out() { get("out") }

  /* ionc-end */
  override Void onExecute() { set("out", StatusStr(in)) }
}

