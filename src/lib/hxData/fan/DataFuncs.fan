//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023   Brian Frank   Creation
//

using data
using haystack
using axon
using hx

**
** Axon functions for working with data type system
**
const class DataFuncs
{

  ** Return if the given value fits the type.  This function tests
  ** the type based on either nominally or structural typing.  Also
  ** see `is()` that tests strictly by nominal typing.
  **
  ** Examples:
  **    fits("foo", Str)      >>  true
  **    fits(123, Str)        >>  false
  **    fits({equip}, Equip)  >>  true
  **    fits({equip}, Site)   >>  false
  @Axon static Bool fits(Obj? val, DataSpec type)
  {
    DataSpec x := val as DataSpec ?: DataEnv.cur.typeOf(val)
    return x.isa(type)
  }

}