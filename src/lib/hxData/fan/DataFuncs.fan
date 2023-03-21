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

//////////////////////////////////////////////////////////////////////////
// Lookup
//////////////////////////////////////////////////////////////////////////

  **
  ** Load or lookup a DataSpec by its qname.  If not found
  ** raise exception or return null based on checked flag.
  **
  ** Examples:
  **   spec("ph.points")         // library
  **   spec("ph::Meter")         // type
  **   spec("sys::Spec.of")      // slot
  **   spec("foo::Bar", false)   // type unchecked
  **
  @Axon static data::DataSpec? spec(Str qname, Bool checked := true)
  {
    curContext.usings.data.spec(qname, checked)
  }

  **
  ** List all the data types currently in scope.  Result is a list of DataType.
  **
  @Axon static DataType[] types()
  {
    typesInScope(curContext, null).sort
  }

  private static DataType[] typesInScope(HxContext cx, |DataType->Bool|? filter := null)
  {
    acc := DataType[,]
    cx.usings.list.each |lib|
    {
      lib.slotsOwn.each |x|
      {
        if (filter != null && !filter(x)) return
        acc.add(x)
      }
    }
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Spec Reflection
//////////////////////////////////////////////////////////////////////////

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

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

  **
  ** Build an AST tree of dict, lists, and strings of the effective
  ** meta and slots for the given spec.
  **
  @Axon static DataDict specAst(DataSpec spec)
  {
    doSpecAst(spec, false)
  }

  **
  ** Build an AST tree of dict, lists, and strings of the effective
  ** meta and slots for the given spec.
  **
  @Axon static DataDict specAstOwn(DataSpec spec)
  {
    doSpecAst(spec, true)
  }

  private static DataDict doSpecAst(DataSpec spec, Bool isOwn)
  {
    acc := Str:Obj[:]
    acc.ordered = true

    if (spec.base.type === spec.type)
      acc["type"] = spec.type.qname
    else
      acc["base"] = spec.base.qname

    DataDict meta := isOwn ? spec.own : spec
    meta.each |v, n|
    {
      if (n == "val" && v == Marker.val) return
      acc[n] = specAstVal(v)
    }

    slots := isOwn ? spec.slotsOwn : spec.slots
    if (!slots.isEmpty)
    {
      slotsAcc := Str:Obj[:]
      slotsAcc.ordered = true
      slots.each |slot|
      {
        slotsAcc[slot.name] = doSpecAst(slot, isOwn)
      }
      acc["slots"] = Etc.dictFromMap(slotsAcc)
    }

    return Etc.dictFromMap(acc)
  }

  private static Obj specAstVal(Obj val)
  {
    if (val is DataSpec) return val.toStr
    if (val is List) return ((List)val).map |x| { specAstVal(x) }
    if (val is Dict) return Etc.dictMap(val) |x| { specAstVal(x) }
    return val.toStr
  }

//////////////////////////////////////////////////////////////////////////
// If/Fits
//////////////////////////////////////////////////////////////////////////

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
    cx := curContext
    return cx.usings.data.fits(cx, val, spec, null)
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
    opts := Etc.dict1("explain", Unsafe(explain))
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
    opts := Etc.dict1("explain", Unsafe(explain))
    gb := GridBuilder().addCol("id").addCol("msg")

    // walk thru each rec
    Etc.toRecs(recs).each |rec, i|
    {
      // reset hits accumulator
      hits.clear

      // call fits explain with this rec
      dataEnv.fits(cx, rec, spec, opts)

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

  **
  ** Match dict recs against specs to find all the specs that fit.  The recs
  ** argument can be anything accepted by `toRecList()`.  Specs must be a
  ** list of DataSpecs.  If specs argument is omitted, then we match against
  ** all the non-abstract [types]`types()` currently in scope.  Only the most
  ** specific subtype is returned.
  **
  ** Result is a grid for each input rec with the following columns:
  **   - id: of the input record
  **   - num: number of matches
  **   - specs: list of DataSpec for all matching specs
  **
  ** Example:
  **    readAll(equip).fitsMatchAll
  **
  @Axon
  static Grid fitsMatchAll(Obj? recs, DataSpec[]? specs := null)
  {
    // if specs not specific, get all in scope
    cx := curContext
    if (specs == null)
      specs = typesInScope(cx) |t| { t.lib.qname != "sys" && t.isDict && t.missing("abstract") }

    // walk thru each record add row
    gb := GridBuilder().addCol("id").addCol("num").addCol("specs")
    Etc.toRecs(recs).each |rec|
    {
      matches := doFitsMatchAll(cx, rec, specs)
      gb.addRow([rec.id, Number(matches.size), matches])
    }
    return gb.toGrid
  }

  private static DataType[] doFitsMatchAll(HxContext cx, Dict rec, DataSpec[] specs)
  {
    // first pass is fit each type
    env := cx.usings.data
    matches := specs.findAll |spec| { env.fits(cx, rec, spec) }

    // second pass is to remove supertypes so we only
    // return the most specific subtype
    best := DataSpec[,]
    matches.each |spec|
    {
      // check if this type has subtypes in our match list
      hasSubtypes := matches.any |x| { x !== spec && x.isa(spec) }

      // add it to our best accumulator only if no subtypes
      if (!hasSubtypes) best.add(spec)
    }

    // return most specific matches sorted
    return best.sort
  }

//////////////////////////////////////////////////////////////////////////
// Query
//////////////////////////////////////////////////////////////////////////

  **
  ** Evaluate a relationship query and return record dict.  If no matches
  ** found throw UnknownRecErr or return null based on checked flag.
  ** If there are multiple matches it is indeterminate which one is
  ** returned.  Subject must be a record id or dict in the database.  Spec
  ** must be a DataSpec typed as a 'sys::Query'.  Also see `queryAll`.
  **
  ** Example:
  **   read(point).query(Point.equip)
  **
  @Axon static Dict? query(Obj subject, DataSpec spec, Bool checked := true)
  {
    cx := curContext
    subjectRec := Etc.toRec(subject)
    hit := cx.usings.data.queryWhile(cx, subjectRec, spec, Etc.dict0) |hit| { hit }
    if (hit != null) return hit
    if (checked) throw UnknownRecErr("@$subjectRec.id $spec.qname")
    return null
  }

  **
  ** Evaluate a relationship query and return grid of results.
  ** Subject must be a record id or dict in the database.  Spec
  ** must be a DataSpec typed as a 'sys::Query'.  Also see `query`.
  **
  ** Options:
  **   - 'limit': max number of recs to return
  **   - 'sort': sort by display name
  ** Example:
  **   read(ahu).queryAll(Equip.points)
  **
  @Axon static Grid queryAll(Obj subject, DataSpec spec, Dict? opts := null)
  {
    // options
    limit := Int.maxVal
    sort := false
    if (opts != null && !opts.isEmpty)
    {
      limit = (opts["limit"] as Number)?.toInt ?: limit
      sort = opts.has("sort")
    }

    // query
    cx := curContext
    acc := Dict[,]
    subjectRec := Etc.toRec(subject)
    cx.usings.data.queryWhile(cx, subjectRec, spec, Etc.dict0) |hit|
    {
      acc.add(hit)
      if (acc.size >= limit) return "break"
      return null
    }

    // return grid result
    if (sort) Etc.sortDictsByDis(acc)
    return Etc.makeDictsGrid(null, acc)
  }

  **
  ** Evaluate a relationship query and return the named constraints
  ** as a dict.  The query slot names are the dict names and the matching
  ** record dicts are the dict values. Missing matches are silently ignored
  ** and ambiguous matches return an indeterminate record.
  **
  ** Example:
  **   // spec
  **   MyAhu: Equip {
  **     points: {
  **       dat: DischargeAirTempSensor
  **       rat: DischargeAirTempSensor
  **     }
  **   }
  **
  **   // axon
  **   myAhuPoints: read(ahu).queryNamed(MyAhu.points)
  **
  **   // result
  **   {
  **     dat: {dis:"DAT", discharge, air, temp, sensor, ...},
  **     rat: {dis:"RAT", return, air, temp, sensor, ...}
  **   }
  **
  @Axon static Dict queryNamed(Obj subject, DataSpec spec, Dict? opts := null)
  {
    cx := curContext
    env := cx.usings.data
    subjectRec := Etc.toRec(subject)
    acc := Str:Dict[:]
    cx.usings.data.queryWhile(cx, subjectRec, spec, Etc.dict0) |hit|
    {
      spec.slots.eachWhile |slot|
      {
        name := slot.name
        if (acc[name] != null) return null // already matched
        if (env.fits(cx, hit, slot)) return acc[name] = hit
        return null
      }
      return null
    }
    return Etc.dictFromMap(acc)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Current context
  internal static HxContext curContext()
  {
    HxContext.curHx
  }

}