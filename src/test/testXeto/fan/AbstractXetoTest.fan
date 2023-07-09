//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//

using util
using xeto
using xeto::Dict
using xeto::Lib
using haystack

**
** AbstractXetoTest
**
@Js
class AbstractXetoTest : HaystackTest
{

  XetoEnv env() { XetoEnv.cur }

  Lib compileLib(Str s) { env.compileLib(s) }

  Obj? compileData(Str s) { env.compileData(s) }

}