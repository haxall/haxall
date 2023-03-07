//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//

using util
using data
using haystack

**
** AbstractDataTest
**
@Js
class AbstractDataTest : Test
{

  DataEnv env() { DataEnv.cur }

  DataLib compileLib(Str s) { env.compileLib(s) }

  Obj? compileData(Str s) { env.compileData(s) }

//////////////////////////////////////////////////////////////////////////
// HaystackTest (TODO)
//////////////////////////////////////////////////////////////////////////

  static Number? n(Num? val, Obj? unit := null)
  {
    if (val == null) return null
    if (unit is Str) unit = Number.loadUnit(unit)
    return Number(val.toFloat, unit)
  }

  static const Marker m := Marker.val

  Void verifyDictEq(DataDict a, Obj bx)
  {
    b := env.dict(bx)
    bnames := Str:Str[:]; b.each |v, n| { bnames[n] = n }

    a.each |v, n|
    {
      try
      {
        verifyValEq(v, b[n])
      }
      catch (TestErr e)
      {
        echo("TAG FAILED: $n")
        throw e
      }
      bnames.remove(n)
    }
    verifyEq(bnames.size, 0, bnames.keys.toStr)
  }


  Void verifyValEq(Obj? a, Obj? b)
  {
    //if (a is Ref && b is Ref)   return verifyRefEq(a, b)
    //if (a is List && b is List) return verifyListEq(a, b)
    if (a is Dict && b is Dict) return verifyDictEq(a, b)
    //if (a is Grid && b is Grid) return verifyGridEq(a, b)
    //if (a is Buf && b is Buf)   return verifyBufEq(a, b)
    verifyEq(a, b)
  }

}