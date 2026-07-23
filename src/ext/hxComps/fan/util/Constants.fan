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
@Gen
class BoolConst : HxComp
{
  @Gen virtual StatusBool? out { get {get("out")} set {set("out", it)} }
}

**
** Number constant
**
@Gen
class NumberConst : HxComp
{
  @Gen virtual StatusNumber? out { get {get("out")} set {set("out", it)} }
}

**
** Str constant
**
@Gen
class StrConst : HxComp
{
  @Gen virtual StatusStr? out { get {get("out")} set {set("out", it)} }
}

