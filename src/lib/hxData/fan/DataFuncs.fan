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
  ** Return if spec 'a' inherits from spec 'b' based on nominal typing.
  ** This method checks the explicit inheritance hierarchy via `specBase()`.
  ** Use `is()` to check if an instance is of a given type.  Also see
  ** `fits()` and `specFits()` to check using structural typing.
  **
  ** Examples:
  **   specIs(Str, Scalar)     >>  true
  **   specIs(Scalar, Scalar)  >>  false
  **   specIs(Equip, Dict)     >>  true
  **   specIs(Meter, Equip)    >>  true
  **   specIs(Meter, Point)    >>  false
  **
  @Axon static Bool specIs(DataSpec a, DataSpec b)
  {
    a.isa(b)
  }

  **
  ** Return if spec 'a' fits spec 'b' based on structural typing.
  ** Use `fits()` to check if an instance fits a given type.  Also see
  ** `is()` and `specIs()` to check using nominal typing.
  **
  ** Examples:
  **   TODO
  **
  @Axon static Bool specFits(DataSpec a, DataSpec b)
  {
    curContext.usings.data.specFits(a, b, null)
  }

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
    curContext.usings.data.typeOf(val, checked)
  }

  **
  ** Return if the given instance inherits from the spec via nominal
  ** typing.  Use `specIs()` to check nominal typing between two types.
  ** Also see `fits()` and `specFits()` to check via structural typing.
  **
  ** Note that dict values will only match the generic 'sys.Dict'
  ** type.  Use `fits()` for structural type matching.
  **
  ** Examples:
  **   is("hi", Str)       >>  true
  **   is("hi", Dict)      >>  false
  **   is({}, Dict)        >>  true
  **   is({equip}, Equip)  >>  false
  **   is(Str, Spec)       >>  true
  **
  @Axon static Bool _is(Obj? val, DataSpec spec)
  {
    curContext.usings.data.typeOf(val).isa(spec)
  }

  **
  ** Return if the given instance fits the spec via structural typing.
  ** Use `specFits()` to check structural typing between two types.
  ** Also see `is()` and `specIs()` to check via nominal typing.
  **
  ** Examples:
  **    fits("foo", Str)      >>  true
  **    fits(123, Str)        >>  false
  **    fits({equip}, Equip)  >>  true
  **    fits({equip}, Site)   >>  false
  **
  @Axon static Bool fits(Obj? val, DataSpec spec)
  {
    curContext.usings.data.fits(val, spec, null)
  }

  **
  ** Return a grid explaining why spec 'a' does not fit 'b'.
  ** If 'a' does fit 'b' then return an empty grid.
  **
  @Axon
  static Grid specFitsExplain(DataSpec a, DataSpec b)
  {
    gb := GridBuilder().addCol("msg")
    explain := |DataLogRec rec| { gb.addRow1(rec.msg) }
    opts := ["explain": explain]
    curContext.usings.data.specFits(a, b, opts)
    return gb.toGrid
  }

  **
  ** Return grid which explains how data fits the given spec.  This
  ** function takes one or more recs and returns a grid.  For each rec
  ** zero or more rows are returned with an error why the rec does not
  ** fit the given type.  If a rec does fit the type, then zero rows are
  ** returned for that record.
  **
  ** Example:
  **    readAll(vav and hotWaterHeating).fitsExplain(G36ReheatVav)
  **
  @Axon
  static Grid fitsExplain(Obj? recs, DataSpec spec)
  {
    cx := curContext
    dataEnv := cx.usings.data
    hits := DataLogRec[,]
    explain := |DataLogRec rec| { hits.add(rec) }
    opts := ["explain": explain]
    gb := GridBuilder().addCol("id").addCol("msg")

    // walk thru each rec
    Etc.toRecs(recs).each |rec, i|
    {
      // reset hits accumulator
      hits.clear

      // call fits explain with this rec
      dataEnv.fits(rec, spec, opts)

      // if we had hits, then add to our result grid
      if (!hits.isEmpty)
      {
        id := rec["id"] as Ref ?: Ref("_$i")
        gb.addRow2(id, hits.size == 1 ? "1 error" : "$hits.size errors")
        hits.each |hit| { gb.addRow2(id, hit.msg) }
      }
    }

    return gb.toGrid
  }

  ** Current context
  internal static HxContext curContext()
  {
    HxContext.curHx
  }

}