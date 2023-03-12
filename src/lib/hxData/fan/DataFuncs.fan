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

  **
  ** Return the data type of the given value.  Raise exception
  ** if value type is not mapped into the data type system.  Also
  ** see `is()` and `fits()`.
  **
  ** Examples:
  **    typeof("hi")  >>  sys::Str
  **    typeof(@id)   >>  sys::Ref
  **    typeof({})    >>  sys::Dict
  **
  @Axon static DataSpec? _typeof(Obj? val, Bool checked := true)
  {
    AxonContext.curAxon.usings.data.typeOf(val, checked)
  }

  **
  ** Return if value is an instance of the given type.  This
  ** function tests the type based on nominal typing via explicit
  ** inheritance.  If val is itself a type, then we test that
  ** it explicitly inherits from type.  Raise exception if value is
  ** not mapped into the data type system.
  **
  ** Note that dict values will only match the generic 'sys.Dict'
  ** type.  Use `fits()` for structural type matching.
  **
  ** Examples:
  **   is("hi", Str)     >>  true
  **   is("hi", Dict)    >>  false
  **   is({}, Dict)      >>  true
  **   is(Meter, Equip)  >>  true
  **
  @Axon static Bool _is(Obj? val, DataSpec type)
  {
    if (val is DataSpec) return ((DataSpec)val).isa(type)
    cx := AxonContext.curAxon
    return cx.usings.data.typeOf(val).isa(type)
  }

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