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
** Boolean constant
**
class BoolConst : HxComp
{
  /* ionc-start */

  virtual StatusBool? out { get {get("out")} set {set("out", it)} }

  /* ionc-end */
}

**
** Number constant
**
class NumberConst : HxComp
{
  /* ionc-start */

  virtual StatusNumber? out { get {get("out")} set {set("out", it)} }

  /* ionc-end */
}

**
** Str constant
**
class StrConst : HxComp
{
  /* ionc-start */

  virtual StatusStr? out { get {get("out")} set {set("out", it)} }

  /* ionc-end */
}

