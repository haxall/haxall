//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023   Brian Frank   Creation
//

using util
using xeto
using xeto::Dict
using xeto::Lib
using xetoEnv::MDictMerge1
using xetoEnv::MLogRec
using haystack::Ref
using haystack
using axon
using hx

**
** Axon functions for working with xeto specs
**
@Js
const class XetoFuncs
{

//////////////////////////////////////////////////////////////////////////
// Lookup
//////////////////////////////////////////////////////////////////////////

  **
  ** Load or lookup a Xeto library by its string or ref name.  Return
  ** the [dict]`xeto::Lib` representation.  If not found raise
  ** exception or return null based on checked flag.
  **
  ** Examples:
  **   specLib("ph.points")            // load by dotted name
  **   specLib(@lib:ph.points)         // load by lib ref id
  **   specLib("bad.lib.name")         // raises exception if not found
  **   specLib("bad.lib.name", false)  // unchecked returns null
  **
  @Axon static Lib? specLib(Obj name, Bool checked := true)
  {
    if (name is Ref)
    {
      id := name.toStr
      if (!id.startsWith("lib:")) throw ArgErr("Invalid ref format: $id")
      name = id[4..-1]
    }
    return curContext.xeto.lib(name, checked)
  }

  **
  ** List Xeto libraries as a list of their [dict]`xeto::Lib` representation.
  ** Is scope is null then return all installed libs (libs not yet loaded
  ** will not have their metadata).  Otherwise scope must be a filter
  ** expression used to filter the dict representation.
  **
  ** Examples:
  **   specLibs()             // all installed libs
  **   specLibs(loaded)       // only libs loaded into memory
  **
  @Axon static Dict[] specLibs(Expr scope := Literal.nullVal)
  {
    cx := curContext

    Filter? filter := null
    if (scope !== Literal.nullVal)
      filter = scope.evalToFilter(cx)

    return cx.xeto.libs.mapNotNull |Dict lib->Dict?|
    {
      if (filter != null && !filter.matches(lib, cx)) return null
      return lib
    }
  }

  **
  ** Load or lookup a Xeto spec by its string or ref qname.  Return
  ** the [dict]`xeto::Spec` representation.  If not found raise
  ** exception or return null based on checked flag.
  **
  ** Examples:
  **   spec("ph::Meter")         // type string
  **   spec(@ph::Meter)          // type id
  **   spec("sys::Spec.of")      // slot
  **   spec("foo::Bad")          // raises exception if not found
  **   spec("foo::Bad", false)   // unchecked returns null
  **
  @Axon static Spec? spec(Obj qname, Bool checked := true)
  {
    curContext.xeto.spec(qname.toStr, checked)
  }

  **
  ** List Xeto specs as a list of their [dict]`xeto::Spec` representation.
  ** Scope may one of the following:
  **  - null: return all the top-level specs currently in the using scope
  **  - lib: return all the top-level specs declared in given library
  **  - list of lib: all specs in given libraries
  **
  ** A filter may be specified to filter the specs found in the scope.  The
  ** dict representation for filtering supports a "slots" tag on each spec
  ** with a Dict of the effective slots name.  This allows filtering slots
  ** using the syntax 'slots->someName'.
  **
  ** Examples:
  **   specs()                  // specs in using scope
  **   specLib("ph").specs      // specs in a given library
  **   specs(null, abstract)    // filter specs with filter expression
  **   specs(null, slots->ahu)  // filter specs have ahu tag
  **
  @Axon static Spec[] specs(Expr scope := Literal.nullVal, Expr filter := Literal.nullVal)
  {
    cx := curContext

    |Spec->Bool|? filterFunc := null
    if (filter !== Literal.nullVal)
    {
      f := filter.evalToFilter(cx)
      filterFunc = |Spec x->Bool| { f.matches(MDictMerge1(x, "slots", x.slots.toDict), cx) }
    }

    scopeVal := scope.eval(cx)

    if (scopeVal == null) return typesInScope(cx, filterFunc)

    lib := scopeVal as Lib
    if (lib != null)
    {
      specs := lib.types
      if (filterFunc != null) specs = specs.findAll(filterFunc)
      return specs
    }

    list := scopeVal as List
    if (list != null)
    {
      acc := Spec[,]
      list.each |x|
      {
        lib = x as Lib ?: throw ArgErr("Expecting list of Lib: $x [$x.typeof]")
        lib.types.each |spec|
        {
          if (filterFunc != null && !filterFunc(spec)) return
          acc.add(spec)
        }
      }
      return acc
    }

    throw ArgErr("Invalid value for scope: $scopeVal [$scopeVal.typeof]")
  }

  private static Spec[] typesInScope(AxonContext cx, |Spec->Bool|? filter := null)
  {
    acc := Spec[,]
    cx.xeto.eachType |x|
    {
      if (filter != null && !filter(x)) return
      acc.add(x)
    }

    vars := Str:Spec[:]
    cx.varsInScope.each |var|
    {
      x := var as Spec
      if (x == null) return
      if (vars[x.qname] != null) return
      if (filter != null && !filter(x)) return
      vars[x.qname] = x
      acc.add(x)
    }
    return acc
  }

  **
  ** Load or lookup a instance from a Xeto library by its string or ref qname
  ** as a Dict. If not found raise exception or return null based on checked flag.
  **
  ** Examples:
  **   instance("icons::apple")             // qname string
  **   instance(@icons::apple)              // qname Ref id
  **   instance("icons::bad-name")          // raises exception if not found
  **   instance("icons::bad-name", false)   // unchecked returns null
  **
  @Axon static Dict? instance(Obj qname, Bool checked := true)
  {
    curContext.xeto.instance(qname.toStr, checked)
  }

  **
  ** Lookup instances from Xeto libs as a list of dicts.
  **
  ** Scope may one of the following:
  **  - null: all instances from all libs currently in the using scope
  **  - lib: all instances declared in given library
  **  - list of lib: all instances in given libraries
  **
  ** If the filter is null, then it filters the instances from the scope.
  **
  ** Examples:
  **   instances()                  // all instances in scope
  **   specLib("icons").instances   // instances in a given library
  **   instances(null, a and b)     // filter instances with filter expression
  **
  @Axon static Dict[] instances(Expr scope := Literal.nullVal, Expr filter := Literal.nullVal)
  {
    cx := curContext

    Filter? f := null
    if (filter !== Literal.nullVal)
      f = filter.evalToFilter(cx)

    scopeVal := scope.eval(cx)

    if (scopeVal == null)
    {
      return instancesInScope(cx, f)
    }

    lib := scopeVal as Lib
    if (lib != null)
    {
      instances := lib.instances
      if (f != null) instances = instances.findAll |x| { f.matches(x, cx) }
      return instances
    }

    list := scopeVal as List
    if (list != null)
    {
      acc := Dict[,]
      list.each |x|
      {
        lib = x as Lib ?: throw ArgErr("Expecting list of Lib: $x [$x.typeof]")
        lib.instances.each |instance|
        {
          if (f != null && !f.matches(instance, cx)) return
          acc.add(instance)
        }
      }
      return acc
    }

    throw ArgErr("Invalid value for scope: $scopeVal [$scopeVal.typeof]")
  }

  private static Dict[] instancesInScope(AxonContext cx, Filter? filter)
  {
    acc := Dict[,]
    cx.xeto.libs.each |lib|
    {
      lib.instances.each |x|
      {
        if (filter != null && !filter.matches(x, cx)) return
        acc.add(x)
      }
    }
    return acc
  }

  **
  ** Create the default instance for a given spec.
  ** Raise exception if spec is abstract.
  **
  ** The default behavior for dict types is to return a single Dict.
  ** However, if the type has a constrainted query, then an entire graph
  ** can be instantiated via the '{graph}' option in which case a Dict[] is
  ** returned.  In graph mode an 'id' is generated for recs for cross-linking.
  **
  ** Options:
  **   - 'graph': marker tag to instantiate a graph of recs
  **
  ** Examples:
  **   // evaluates to 2000-01-01
  **   instantiate(Date)
  **
  **   // evaluates to dict {equip, vav, hotWaterHeating, ...}
  **   instantiate(G36ReheatVav)
  **
  **   // evaluates to dict[] of vav + points from constrained query
  **   instantiate(G36ReheatVav, {graph})
  **
  @Axon static Obj? instantiate(Spec spec, Dict? opts := null)
  {
    curContext.xeto.instantiate(spec, opts)
  }

//////////////////////////////////////////////////////////////////////////
// Spec Reflection
//////////////////////////////////////////////////////////////////////////

  **
  ** Parent spec which contains given spec and scopes its name.
  ** Returns null for top-level specs within their library.
  **
  ** Examples:
  **   specParent(Str)  >>  sys
  **
  @Axon static Spec? specParent(Spec spec) { spec.parent }

  **
  ** Return simple name of spec.
  **
  ** Examples:
  **   specName(Dict)  >>  "Dict"
  **   specName(Site)  >>  "Site"
  **
  @Axon static Str specName(Spec spec) { spec.name }

  **
  ** Return fully qualified name of the spec:
  **   - Top-level type will return "foo.bar::Baz"
  **   - Slot spec will return "foo.bar::Baz.qux"
  **   - Derived specs will return "derived123::{name}"
  **
  ** Examples:
  **   specQName(Dict)  >>  "sys::Dict"
  **   specQName(Site)  >>  "ph::Site"
  **
  @Axon static Str specQName(Spec spec) { spec.qname }

  **
  ** Data type of the spec.  Returns the spec itself if given a top-level type.
  **
  ** Examples:
  **   specType(Str)                      >>  sys:Str
  **   spec("ph::Equip.equip").specType   >>  sys::Marker
  **
  @Axon static Spec specType(Spec spec) { spec.type }

  **
  ** Base spec from which the given spec directly inherits.
  ** Returns null if spec is 'sys::Obj' itself.
  **
  ** Examples:
  **   specBase(Str)    >>  sys::Scalar
  **   specBase(Meter)  >>  ph::Equip
  **   specType(Equip)  >>  ph::Entity
  **
  @Axon static Spec? specBase(Spec spec) { spec.base }

  **
  ** Get the spec's effective declared meta-data as dict.
  **
  ** Examples:
  **   specMeta(Date)  >>  {sealed, val:2000-01-01, doc:"...", pattern:"..."}
  **
  @Axon static Dict specMeta(Spec spec) { spec.meta }

  **
  ** Get the spec's own declared meta-data as dict.
  **
  ** Examples:
  **   specMetaOwn(Date)  >>  {sealed, val:2000-01-01, doc:"...", pattern:"..."}
  **
  @Axon static Dict specMetaOwn(Spec spec) { spec.metaOwn }

  **
  ** Get the spec's declared children slots as dict of Specs.
  **
  ** Examples:
  **   specSlots(Ahu)  >>  {ahu: Spec}
  **
  @Axon static Dict specSlotsOwn(Spec spec) { spec.slotsOwn.toDict }

  **
  ** Get the effective children slots as a dict of Specs.
  **
  ** Examples:
  **   specSlots(Ahu)  >>  {equip: Spec, points: Spec, ahu: Spec}
  **
  @Axon static Dict specSlots(Spec spec) { spec.slots.toDict }

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

/* TODO
  **
  ** Build an AST tree of dict, lists, and strings of the effective
  ** meta and slots for the given spec.
  **
  ** TODO: the AST format will change
  **
  @Axon static Dict specAst(Spec spec)
  {
    curContext.xeto.genAst(spec, Etc.dict0)
  }

  **
  ** Build an AST tree of dict, lists, and strings of the effective
  ** meta and slots for the given spec.
  **
  ** TODO: the AST format will change
  **
  @Axon static Dict specAstOwn(Spec spec)
  {
    curContext.xeto.genAst(spec, Etc.dict1("own", Marker.val))
  }
*/

//////////////////////////////////////////////////////////////////////////
// If/Fits
//////////////////////////////////////////////////////////////////////////

  **
  ** Return the Xeto spec of the given value.  Raise exception
  ** if value type is not mapped into the data type system.  Also
  ** see `is()` and `fits()`.
  **
  ** Examples:
  **    specOf("hi")                 >>  sys::Str
  **    specOf(@id)                  >>  sys::Ref
  **    specOf({})                   >>  sys::Dict
  **    specOf({spec:@ph::Equip})    >>  ph::Dict
  **
  @Axon static Spec? specOf(Obj? val, Bool checked := true)
  {
    curContext.xeto.specOf(val, checked)
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
  @Axon static Bool specIs(Spec a, Spec b)
  {
    a.isa(b)
  }

  **
  ** Return if spec 'a' fits spec 'b' based on structural typing.
  ** Use `fits()` to check if an instance fits a given type.  Also see
  ** `is()` and `specIs()` to check using nominal typing.
  **
  ** Examples:
  **   specFits(Meter, Equip)    >>  true
  **   specFits(Meter, Point)    >>  false
  **
  @Axon static Bool specFits(Spec a, Spec b)
  {
    curContext.xeto.specFits(a, b, null)
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
  @Axon static Bool _is(Obj? val, Spec spec)
  {
    curContext.xeto.specOf(val).isa(spec)
  }

  **
  ** Given a choice spec, return the most specific choice subtype
  ** implemented by the instance.  If the instance implements zero or more
  ** than one subtype of the choice, then return null or raise an exception
  ** based on the checked flag.  The instance may be anything accepted
  ** by the `toRec()` function.
  **
  ** Example:
  **   choiceOf({discharge, duct}, DuctSection)  >>  DischargeDuct
  **   choiceOf({hot, water}, Fluid)             >>  HotWater
  **
  @Axon static Spec? choiceOf(Obj instance, Spec choice, Bool checked := true)
  {
    curContext.xeto.choice(choice).selection(Etc.toRec(instance), checked)
  }

  **
  ** Return if the given instance fits the spec via structural typing.
  ** Use `specFits()` to check structural typing between two types.
  ** Also see `is()` and `specIs()` to check via nominal typing.  Use
  ** `fitsExplain()` to explain why fits returns true or false.
  **
  ** If the val is a Dict, then the default behavior is to only check
  ** the dict's tags against the given spec.  In this mode all spec query
  ** slots are ignored.  Pass the '{graph}' option to also check
  ** queries to validate the graph of entities.  For example, the graph
  ** option can be used with equip specs to validate required points.
  **
  **
  ** Options:
  **   - 'graph': marker to also check graph of references such as required points
  **
  ** Examples:
  **    fits("foo", Str)               >>  true
  **    fits(123, Str)                 >>  false
  **    fits({equip}, Equip)           >>  true
  **    fits({equip}, Site)            >>  false
  **    fits(vav, MyVavSpec)           >> validate tags only
  **    fits(vav, MyVavSpec, {graph})  >> validate tags and required points
  **
  @Axon static Bool fits(Obj? val, Spec spec, Dict? opts := null)
  {
    cx := curContext
    return cx.xeto.fits(cx, val, spec, opts)
  }

  **
  ** Return a grid explaining why spec 'a' does not fit 'b'.
  ** If 'a' does fit 'b' then return an empty grid.
  **
  @Axon
  static Grid specFitsExplain(Spec a, Spec b)
  {
    gb := GridBuilder().addCol("msg")
    explain := |XetoLogRec rec| { gb.addRow1(rec.msg) }
    opts := Etc.dict1("explain", Unsafe(explain))
    curContext.xeto.specFits(a, b, opts)
    return gb.toGrid
  }

  **
  ** Return grid which explains how data fits the given spec.  This
  ** function takes one or more recs and returns a grid.  For each rec
  ** zero or more rows are returned with an error why the rec does not
  ** fit the given type.  If a rec does fit the type, then zero rows are
  ** returned for that record.
  **
  ** If you pass null for the spec, then each record is fit against
  ** its declared 'spec' tag.  If a given rec is missing a 'spec' tag
  ** then it is reported an error.
  **
  ** See `fits()` for list of options.
  **
  ** Example:
  **    // validate tags on records only
  **    readAll(vav and hotWaterHeating).fitsExplain(G36ReheatVav)
  **
  **    // validate tags and required points and other graph queries
  **    readAll(vav and hotWaterHeating).fitsExplain(G36ReheatVav, {graph})
  **
  @Axon
  static Grid fitsExplain(Obj? recs, Spec? spec, Dict? opts := null)
  {
    cx := curContext
    ns := cx.xeto
    hits := XetoLogRec[,]
    explain := |XetoLogRec rec| { hits.add(rec) }
    opts = Etc.dictSet(opts, "explain", Unsafe(explain))
    gb := GridBuilder().addCol("id").addCol("msg")

    // walk thru each rec
    Etc.toRecs(recs).each |rec, i|
    {
      // reset hits accumulator
      hits.clear

      // lookup record's declared spec if spec param is null
      recSpec := spec
      if (recSpec == null)
      {
        specTag := rec["spec"] as Ref
        if (specTag == null)
        {
          hits.add(MLogRec(LogLevel.err, "Missing 'spec' ref tag", FileLoc.unknown, null))
        }
        else
        {
          recSpec = ns.spec(specTag.id, false)
          if (recSpec == null)
            hits.add(MLogRec(LogLevel.err, "Unknown 'spec' ref: $specTag", FileLoc.unknown, null))
        }
      }

      // call fits explain with this rec
      if (recSpec != null) ns.fits(cx, rec, recSpec, opts)

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
  ** Spec or list of Specs.  If specs argument is omitted, then we match against
  ** all the non-abstract [types]`specs()` currently in scope.  Only the most
  ** specific subtype is returned.
  **
  ** Result is a grid for each input rec with the following columns:
  **   - id: of the input record
  **   - num: number of matches
  **   - specs: list of Spec for all matching specs
  **
  ** See `fits()` for a list of supported fit options.
  **
  ** Example:
  **    readAll(equip).fitsMatchAll
  **
  @Axon
  static Grid fitsMatchAll(Obj? recs, Obj? specs := null, Dict? opts := null)
  {
    // coerce specs to list
    specList := specs as Spec[]
    if (specList == null && specs != null) specList = [(Spec)specs]

    // if specs not specific, get all in scope
    cx := curContext
    dictSpec := cx.xeto.spec("sys::Dict") // TODO - make isDict work for AND types
    if (specList == null)
      specList = typesInScope(cx) |t| { !t.qname.startsWith("sys::") && t.isa(dictSpec) && t.missing("abstract") }

    // walk thru each record add row
    gb := GridBuilder().addCol("id").addCol("num").addCol("specs")
    Etc.toRecs(recs).each |rec|
    {
      matches := doFitsMatchAll(cx, rec, specList, opts)
      gb.addRow([rec.id, Number(matches.size), matches])
    }
    return gb.toGrid
  }

  private static Spec[] doFitsMatchAll(AxonContext cx, Dict rec, Spec[] specs, Dict? opts)
  {
    // first pass is fit each type
    ns := cx.xeto
    matches := specs.findAll |spec| { ns.fits(cx, rec, spec, opts) }

    // second pass is to remove supertypes so we only
    // return the most specific subtype
    best := Spec[,]
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
  ** must be a Spec typed as a 'sys::Query'.  Also see `queryAll`.
  **
  ** Example:
  **   read(point).query(Point.equip)
  **
  @Axon static Dict? query(Obj subject, Spec spec, Bool checked := true)
  {
    cx := curContext
    subjectRec := Etc.toRec(subject)
    hit := cx.xeto.queryWhile(cx, subjectRec, spec, Etc.dict0) |hit| { hit }
    if (hit != null) return hit
    if (checked) throw UnknownRecErr("@$subjectRec.id $spec.qname")
    return null
  }

  **
  ** Evaluate a relationship query and return grid of results.
  ** Subject must be a record id or dict in the database.  Spec
  ** must be a Spec typed as a 'sys::Query'.  Also see `query`.
  **
  ** Options:
  **   - 'limit': max number of recs to return
  **   - 'sort': sort by display name
  ** Example:
  **   read(ahu).queryAll(spec("ph::Equip.points"))
  **
  @Axon static Grid queryAll(Obj subject, Spec spec, Dict? opts := null)
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
    cx.xeto.queryWhile(cx, subjectRec, spec, Etc.dict0) |hit|
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
  **   myAhuPoints: read(ahu).queryNamed(spec("mylib::MyAhu.points"))
  **
  **   // result
  **   {
  **     dat: {dis:"DAT", discharge, air, temp, sensor, ...},
  **     rat: {dis:"RAT", return, air, temp, sensor, ...}
  **   }
  **
  @Axon static Dict queryNamed(Obj subject, Spec spec, Dict? opts := null)
  {
    cx := curContext
    ns := cx.xeto
    subjectRec := Etc.toRec(subject)
    acc := Str:Dict[:]
    ns.queryWhile(cx, subjectRec, spec, Etc.dict0) |hit|
    {
      spec.slots.eachWhile |slot|
      {
        name := slot.name
        if (acc[name] != null) return null // already matched
        if (ns.fits(cx, hit, slot)) return acc[name] = hit
        return null
      }
      return null
    }
    return Etc.dictFromMap(acc)
  }

  ** Current context
  internal static AxonContext curContext()
  {
    AxonContext.curAxon
  }

}

