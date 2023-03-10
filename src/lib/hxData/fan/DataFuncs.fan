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
    Fitter(curContext).fits(val, type)
  }

  **
  ** Return grid which explains how data fits the given type.  This
  ** function takes one or more recs and returns a grid.  For each rec
  ** zero or more rows are returned with an error why the rec does not
  ** fit the given type.  If a rec does fit the type, then zero rows are
  ** returned for that record.
  **
  ** Example:
  **    readAll(vav and hotWaterHeating).fitsExplain(G36ReheatVav)
  **
  @Axon
  static Grid fitsExplain(Obj? recs, DataSpec type)
  {
    ExplainFitter(curContext).explain(recs, type)
  }

  ** Current context
  internal static HxContext curContext()
  {
    HxContext.curHx
  }

}