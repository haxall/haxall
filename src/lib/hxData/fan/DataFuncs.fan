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
  ** Library which contains the given data type.  Raise exception
  ** if type is not a direct type spec of a library.
  **
  ** Examples:
  **   specLib(Str)    >>  sys
  **   specLib(Equip)  >>  ph
  **
  @Axon static data::DataLib specLib(DataType type) { type.lib }

  **
  ** Parent spec which contains given spec and scopes its name.
  ** Returns null for libs and derived specs.
  **
  ** Examples:
  **   specParent(Str)  >>  sys
  **
  @Axon static DataSpec? specParent(DataSpec spec) { spec.parent }

  **
  ** Return simple name of spec.  Returns empty string spec is a library.
  **
  ** Examples:
  **   specName(Dict)  >>  "Dict"
  **   specName(Site)  >>  "Site"
  **
  @Axon static Str specName(DataSpec spec) { spec.name }

  **
  ** Return fully qualified name of the spec:
  **   - DataLib will return "foo.bar"
  **   - DataType will return "foo.bar::Baz"
  **   - DataType slots will return "foo.bar::Baz.qux"
  **   - Derived specs will return "derived123::{name}"
  **
  ** Examples:
  **   specQName(Dict)  >>  "sys::Dict"
  **   specQName(Site)  >>  "ph::Site"
  **
  @Axon static Str specQName(DataSpec spec) { spec.qname }

  **
  ** Data type of the spec.  Returns the spec itself if it is a DataType.
  **
  ** Examples:
  **   specType(Str)    >>  sys:Str
  **   specType(Dict)   >>  sys::Dict
  **   specType(Point)  >>  sys::Point
  **
  @Axon static DataType specType(DataSpec spec) { spec.type }

  **
  ** Base spec from which the given spec directly inherits.
  ** Returns null if spec is 'sys::Obj' itself.
  **
  ** Examples:
  **   specBase(Str)    >>  sys::Scalar
  **   specBase(Meter)  >>  ph::Equip
  **   specType(Equip)  >>  ph::Entity
  **
  @Axon static DataSpec? specBase(DataSpec spec) { spec.base }

  **
  ** Get the spec's own declared meta-data as dict.  The effective
  ** meta-data dict is the spec itself.
  **
  ** Examples:
  **   specMetaOwn(Date)  >>  {sealed, val:2000-01-01, doc:"...", pattern:"..."}
  **
  @Axon static DataDict specMetaOwn(DataSpec spec) { spec.own }

  **
  ** Get the spec's declared children slots as dict of DataSpecs.
  **
  ** Examples:
  **   specSlots(Ahu)  >>  {ahu: DataSpec}
  **
  @Axon static DataDict specSlotsOwn(DataSpec spec) { spec.slotsOwn.toDict }

  **
  ** Get the effective children slots as a dict of DataSpecs.
  **
  ** Examples:
  **   specSlots(Ahu)  >>  {equip: DataSpec, points: DataSpec, ahu: DataSpec}
  **
  @Axon static DataDict specSlots(DataSpec spec) { spec.slots.toDict }

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