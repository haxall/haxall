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
** Base class with common implementation for these conversions
**
abstract class StatusValToVal : HxComp
{
  StatusVal? statusVal() { get("in") }
  private Obj nullVal() { get("whenNull") }
  override Void onExecute() { set("out", statusVal?.val ?: nullVal) }
}

**
** Convert a StatusBool to a Bool value
**
class StatusBoolToBool : StatusValToVal
{
  /* ionc-start */

  virtual StatusBool? in() { get("in") }

  virtual Bool out() { get("out") }

  ** When 'in' is null, set out to this value.
  virtual Bool whenNull { get {get("whenNull")} set {set("whenNull", it)} }

  /* ionc-end */
}

**
** Convert a StatusNumber to a Number
**
class StatusNumberToNumber : StatusValToVal
{
  /* ionc-start */

  virtual StatusNumber? in() { get("in") }

  virtual Number out() { get("out") }

  ** When 'in' is null, set out to this value.
  virtual Number whenNull { get {get("whenNull")} set {set("whenNull", it)} }

  /* ionc-end */
}

