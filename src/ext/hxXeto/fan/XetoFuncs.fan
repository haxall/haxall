//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023   Brian Frank   Creation
//

using util
using xeto
using xetom
using haystack
using axon
using hx

**
** Axon functions for working with xeto specs
**
@Js @Gen
const class XetoFuncs
{

//////////////////////////////////////////////////////////////////////////
// Lookup
//////////////////////////////////////////////////////////////////////////

  ** Load or lookup a Xeto library by its string or ref name.  Return
  ** the [dict](fan.xeto::Lib) representation.  If not found raise
  ** exception or return null based on checked flag.
  **
  ** Examples:
  **
  **     specLib("ph.points")            // load by dotted name
  **     specLib(@lib:ph.points)         // load by lib ref id
  **     specLib("bad.lib.name")         // raises exception if not found
  **     specLib("bad.lib.name", false)  // unchecked returns null
  @Api @Axon static Lib? specLib(Obj name, Bool checked := true)
  {
    if (name is Ref)
    {
      id := name.toStr
      if (!id.startsWith("lib:")) throw ArgErr("Invalid ref format: $id")
      name = id[4..-1]
    }
    return curContext.ns.lib(name, checked)
  }

  ** List Xeto libraries as a list of their [dict](fan.xeto::Lib) representation.
  ** Is scope is null then return all installed libs (libs not yet loaded
  ** will not have their metadata).  Otherwise scope must be a filter
  ** expression used to filter the dict representation.
  **
  ** Examples:
  **
  **     specLibs()             // all installed libs
  **     specLibs(loaded)       // only libs loaded into memory
  @Api @Axon static Dict[] specLibs(Expr filterExpr := Literal.nullVal)
  {
    cx := curContext

    Filter? filter := null
    if (filterExpr !== Literal.nullVal)
      filter = filterExpr.evalToFilter(cx)

    return cx.ns.libs.mapNotNull |Dict lib->Dict?|
    {
      if (filter != null && !filter.matches(lib, cx)) return null
      return lib
    }
  }

  ** Load or lookup a Xeto spec by its string or ref qname.  Return
  ** the [dict](fan.xeto::Spec) representation.  If not found raise
  ** exception or return null based on checked flag.
  **
  ** NOTE: returns the same Spec instance as returned by [fan.xeto::Namespace].
  ** The spec meta is modeled using full fidelity and *not* haystack fidelity.
  ** Use [specMeta()] to normalize to haystack fidelity for use inside Axon.
  **
  ** Examples:
  **
  **     spec("ph::Meter")         // type string
  **     spec(@ph::Meter)          // type id
  **     spec("sys::Spec.of")      // slot
  **     spec("foo::Bad")          // raises exception if not found
  **     spec("foo::Bad", false)   // unchecked returns null
  @Api @Axon static Spec? spec(Obj qname, Bool checked := true)
  {
    curContext.ns.spec(qname.toStr, checked)
  }

  ** List Xeto specs as a list of their [dict](fan.xeto::Spec) representation.
  ** Scope may one of the following:
  **  - null: return all the top-level specs currently in the using scope
  **  - lib: return all the top-level specs declared in given library
  **  - list of lib: all specs in given libraries
  **
  ** A filter may be specified to filter the specs found in the scope.  The
  ** dict representation for filtering supports a "slots" tag on each spec
  ** with a Dict of the effective slots name.  This allows filtering slots
  ** using the syntax `slots->someName`.
  **
  ** NOTE: returns the same Spec instances as returned by [fan.xeto::Namespace].
  ** The spec meta is modeled using full fidelity and *not* haystack fidelity.
  ** Use [specMeta()] to normalize to haystack fidelity for use inside Axon.
  **
  ** Examples:
  **
  **     specs()                  // specs in using scope
  **     specLib("ph").specs      // specs in a given library
  **     specs(null, abstract)    // filter specs with filter expression
  **     specs(null, slots->ahu)  // filter specs have ahu tag
  @Api @Axon static Spec[] specs(Expr scope := Literal.nullVal, Expr filter := Literal.nullVal)
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
      specs := lib.types.list
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
    cx.ns.eachType |x|
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

  ** Load or lookup a instance from a Xeto library by its string or ref qname
  ** as a Dict. If not found raise exception or return null based on checked flag.
  **
  ** NOTE: this function returns the instance using Haystack level fidelity
  **
  ** Examples:
  **
  **     instance("icons::apple")             // qname string
  **     instance(@icons::apple)              // qname Ref id
  **     instance("icons::bad-name")          // raises exception if not found
  **     instance("icons::bad-name", false)   // unchecked returns null
  @Api @Axon static Dict? instance(Obj qname, Bool checked := true)
  {
    XetoUtil.toHaystack(curContext.ns.instance(qname.toStr, checked))
  }

  ** Lookup instances from Xeto libs as a list of dicts.
  **
  ** Scope may one of the following:
  **  - null: all instances from all libs currently in the using scope
  **  - lib: all instances declared in given library
  **  - list of lib: all instances in given libraries
  **
  ** If the filter is null, then it filters the instances from the scope.
  **
  ** NOTE: this function returns the instances using Haystack level fidelity
  **
  ** Examples:
  **
  **     instances()                  // all instances in scope
  **     specLib("icons").instances   // instances in a given library
  **     instances(null, a and b)     // filter instances with filter expression
  @Api @Axon static Dict[] instances(Expr scope := Literal.nullVal, Expr filter := Literal.nullVal)
  {
    doInstances(scope, filter).map |x->Dict| { XetoUtil.toHaystack(x) }
  }

  private static Dict[] doInstances(Expr scope := Literal.nullVal, Expr filter := Literal.nullVal)
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
    cx.ns.libs.each |lib|
    {
      lib.instances.each |x|
      {
        if (filter != null && !filter.matches(x, cx)) return
        acc.add(x)
      }
    }
    return acc
  }

  ** Create the default instance for a given spec.
  ** Raise exception if spec is abstract.
  **
  ** The default behavior for dict types is to return a single Dict.
  ** However, if the type has a constrainted query, then an entire graph
  ** can be instantiated via the `{graph}` option in which case a `Dict[]` is
  ** returned.  In graph mode an `id` is generated for recs for cross-linking.
  **
  ** Also see [fan.xeto::Namespace.instantiate].
  **
  ** NOTE: this function forces the `haystack` option to force all
  ** non-Haystack scalars to be simple strings.
  **
  ** Options:
  **   - `graph`: marker tag to instantiate a graph of recs
  **   - `abstract`: marker to supress error if spec is abstract
  **
  ** Examples:
  **
  **     // evaluates to 2000-01-01
  **     instantiate(Date)
  **
  **     // evaluates to dict {equip, vav, hotWaterHeating, ...}
  **     instantiate(G36ReheatVav)
  **
  **     // evaluates to dict[] of vav + points from constrained query
  **     instantiate(G36ReheatVav, {graph})
  @Api @Axon static Obj? instantiate(Spec spec, Dict? opts := null)
  {
    curContext.ns.instantiate(spec, Etc.dictSet(opts, "haystack", Marker.val))
  }

//////////////////////////////////////////////////////////////////////////
// Spec Reflection
//////////////////////////////////////////////////////////////////////////


  ** Compute the extended type spec by merging all meta and slots from
  ** mixins.  This call can be quite expensive; so cache and reuse the
  ** result for your operation.
  **
  ** Examples:
  **
  **     specx(Site)
  @Api @Axon static Spec specx(Spec spec)
  {
    curContext.ns.specx(spec)
  }

  ** Parent spec which contains given spec and scopes its name.
  ** Returns null for top-level specs within their library.
  **
  ** Examples:
  **
  **     specParent(Str)  >>  sys
  @Api @Axon static Spec? specParent(Spec spec) { spec.parent }

  ** Return simple name of spec.
  **
  ** Examples:
  **
  **     specName(Dict)  >>  "Dict"
  **     specName(Site)  >>  "Site"
  @Api @Axon static Str specName(Spec spec) { spec.name }

  ** Return fully qualified name of the spec:
  **   - Top-level type will return "foo.bar::Baz"
  **   - Slot spec will return "foo.bar::Baz.qux"
  **   - Derived specs will return "derived123::{name}"
  **
  ** Examples:
  **
  **     specQName(Dict)  >>  "sys::Dict"
  **     specQName(Site)  >>  "ph::Site"
  @Api @Axon static Str specQName(Spec spec) { spec.qname }

  ** Data type of the spec.  Returns the spec itself if given a top-level type.
  **
  ** Examples:
  **
  **     specType(Str)                      >>  sys:Str
  **     spec("ph::Equip.equip").specType   >>  sys::Marker
  @Api @Axon static Spec specType(Spec spec) { spec.type }

  ** Base spec from which the given spec directly inherits.
  ** Returns null if spec is `sys::Obj` itself.
  **
  ** Examples:
  **
  **     specBase(Str)    >>  sys::Scalar
  **     specBase(Meter)  >>  ph::Equip
  **     specType(Equip)  >>  ph::Entity
  @Api @Axon static Spec? specBase(Spec spec) { spec.base }

  ** Get the spec's effective declared meta-data as dict.
  **
  ** NOTE: this function returns the meta using haystack level fidelity
  **
  ** Examples:
  **
  **     specMeta(Date)  >>  {sealed, val:2000-01-01, doc:"...", pattern:"..."}
  @Api @Axon static Dict specMeta(Spec spec) { XetoUtil.toHaystack(spec.meta) }

  ** Get the spec's own declared meta-data as dict.
  **
  ** NOTE: this function returns the meta using haystack level fidelity
  **
  ** Examples:
  **
  **     specMetaOwn(Date)  >>  {sealed, val:2000-01-01, doc:"...", pattern:"..."}
  @Api @Axon static Dict specMetaOwn(Spec spec) { XetoUtil.toHaystack(spec.metaOwn) }

//////////////////////////////////////////////////////////////////////////
// Members
//////////////////////////////////////////////////////////////////////////

  ** Get the spec's declared children slots and globals as dict of Specs.
  **
  ** Examples:
  **
  **     specMembersOwn(Ahu)
  @Api @Axon static Dict specMembersOwn(Spec spec) { spec.membersOwn.toDict }

  ** Get the effective children slots and globals as a dict of Specs.
  **
  ** Examples:
  **
  **     specMembers(Ahu)
  @Api @Axon static Dict specMembers(Spec spec) { spec.members.toDict }

  ** Get the effective child slot or global member.
  **
  ** Examples:
  **
  **     specMember(Ahu, "equipRef")
  @Api @Axon static Dict? specMember(Spec spec, Str name, Bool checked := true) { spec.member(name, checked) }

  ** Get the spec's declared children slots as dict of Specs.
  **
  ** Examples:
  **
  **     specSlotsOwn(Ahu)
  @Api @Axon static Dict specSlotsOwn(Spec spec) { spec.slotsOwn.toDict }

  ** Get the effective children slots as a dict of Specs.
  **
  ** Examples:
  **
  **     specSlots(Ahu)
  @Api @Axon static Dict specSlots(Spec spec) { spec.slots.toDict }

  ** Get the effective child slot.
  **
  ** Examples:
  **
  **     specSlot(Ahu, "equipRef")
  @Api @Axon static Dict? specSlot(Spec spec, Str name, Bool checked := true) { spec.slot(name, checked) }

  ** Get the spec's declared children globals as dict of Specs.
  **
  ** Examples:
  **
  **     specGlobalsOwn(Ahu)
  @Api @Axon static Dict specGlobalsOwn(Spec spec) { spec.globalsOwn.toDict }

  ** Get the effective children globals as a dict of Specs.
  **
  ** Examples:
  **
  **     specGlobals(Ahu)
  @Api @Axon static Dict specGlobals(Spec spec) { spec.globals.toDict }

  ** Get the effective global slot.
  **
  ** Examples:
  **
  **     specGlobal(Ahu, "equipRef")
  @Api @Axon static Dict? specGlobal(Spec spec, Str name, Bool checked := true) { spec.globals.get(name, checked) }

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
  @Api @Axon static Dict specAst(Spec spec)
  {
    curContext.xeto.genAst(spec, Etc.dict0)
  }

  **
  ** Build an AST tree of dict, lists, and strings of the effective
  ** meta and slots for the given spec.
  **
  ** TODO: the AST format will change
  **
  @Api @Axon static Dict specAstOwn(Spec spec)
  {
    curContext.xeto.genAst(spec, Etc.dict1("own", Marker.val))
  }
*/

//////////////////////////////////////////////////////////////////////////
// Is
//////////////////////////////////////////////////////////////////////////

  ** Return the Xeto spec of the given value.  Raise exception
  ** if value type is not mapped into the data type system.  Also
  ** see [is()] and [fits()].
  **
  ** Examples:
  **
  **      specOf("hi")                 >>  sys::Str
  **      specOf(@id)                  >>  sys::Ref
  **      specOf({})                   >>  sys::Dict
  **      specOf({spec:@ph::Equip})    >>  ph::Dict
  @Api @Axon static Spec? specOf(Obj? val, Bool checked := true)
  {
    curContext.ns.specOf(val, checked)
  }

  ** Return if spec `a` inherits from spec `b` based on nominal typing.
  ** This method checks the explicit inheritance hierarchy via [specBase()].
  ** Use [is()] or [fits()] to check if an instance is of a given type.
  **
  ** Examples:
  **
  **     specIs(Str, Scalar)     >>  true
  **     specIs(Equip, Scalar)   >>  false
  **     specIs(Equip, Dict)     >>  true
  **     specIs(Meter, Equip)    >>  true
  **     specIs(Meter, Point)    >>  false
  @Api @Axon static Bool specIs(Spec a, Spec b)
  {
    a.isa(b)
  }

  ** Return if the value is a member of the spec.  A value fits if its
  ** spec is the given spec or a subtype.  A dict also fits a sugar spec
  ** if it fits the sugar's nominal anchor and has every constraint tag.
  ** Fits never checks required slots or queries; use [validate()] for
  ** that.  Also see [is()] to check strictly via nominal typing.
  **
  ** Examples:
  **
  **     fits("foo", Str)                                  >>  true
  **     fits({spec:@ph::Ahu}, Equip)                      >>  true
  **     fits({spec:@ph.points::DuctFanRunCmd, discharge},
  **          DischargeFanRunCmd)                          >>  true
  @Api @Axon static Bool fits(Obj? val, Spec spec)
  {
    curContext.ns.fits(val, spec)
  }

  ** Given a choice spec, return the most specific choice subtype
  ** implemented by the instance.  If the instance implements zero or more
  ** than one subtype of the choice, then return null or raise an exception
  ** based on the checked flag.  The instance may be anything accepted
  ** by the [toRec()] function.
  **
  ** Example:
  **
  **     choiceOf({discharge, duct}, DuctSection)  >>  DischargeDuct
  **     choiceOf({hot, water}, Fluid)             >>  HotWater
  @Api @Axon static Spec? choiceOf(Obj instance, Spec choice, Bool checked := true)
  {
    curContext.ns.choice(choice).selection(Etc.toRec(instance), checked)
  }

  ** Validate recs or a bare value and return a grid of the
  ** validation items.  A dict, ref, grid, or list of dicts/refs is
  ** coerced to recs via [toRecList()] and each rec is validated
  ** against the given spec, or against its declared 'spec' tag when
  ** the spec is null; a rec missing the tag reports a
  ** 'sys::missingSpecRef' item.  Any other value validates against
  ** the spec as a bare value, such as one scalar against its slot
  ** spec.  Values are always checked at haystack fidelity.
  **
  ** Options:
  **   - `graph`: marker to also check graph of references such as required points
  **   - `ignoreRefs`: marker to not validate if refs exist or match target spec
  **   - `ignoreUnresolvedRefs`: marker to skip unresolved refs, but still
  **     check the target type of refs that do resolve
  **   - `ignoreMissingSlots`: marker to skip missing required slot checks
  **
  ** The result grid has a row per validation item:
  **   - `subject`: id of the subject rec or null if not applicable
  **   - `slot`: dotted slot path within the subject or null if
  **     positioned on the subject itself
  **   - `level`: "err" or "warn"
  **   - `rule`: ref to the 'sys::ValidateRule' instance
  **   - `msg`: display message
  **   - `val`: offending value when applicable
  **
  ** Grid meta has `numErrs` and `numWarns`.
  **
  ** Examples:
  **
  **      readAll(equip).validate                >> validate against each rec's spec tag
  **      readAll(vav).validate(G36ReheatVav)    >> validate against explicit spec
  **      readAll(equip).validate(null, {graph}) >> also validate required points
  **      validate(123, Str)                     >> validate a bare value
  @Api @Axon static Grid validate(Obj? val, Spec? spec := null, Dict? opts := null)
  {
    ns := curContext.ns
    opts = Etc.dictSet(opts, "haystack", Marker.val) // force haystack level fidelity

    // dicts, refs, and grids validate as recs; anything else is a
    // bare value validated against the spec
    isRecs := val is Dict || val is Ref || val is Grid ||
              (val is List && ((List)val).all |x| { x is Dict || x is Ref })
    ValidateReport[]? reports
    if (!isRecs)
    {
      reports = [ns.validate(val, spec, opts)]
    }
    else
    {
      recList := Etc.toRecs(val)
      reports = spec == null ?
        [ns.validateAll(recList, opts)] :
        recList.map |rec->ValidateReport| { ns.validate(rec, spec, opts) }
    }

    numErrs := 0; numWarns := 0
    gb := GridBuilder()
      .addCol("subject").addCol("slot").addCol("level").addCol("rule").addCol("msg").addCol("val")
    reports.each |report|
    {
      numErrs += report.numErrs; numWarns += report.numWarns
      report.items.each |item|
      {
        gb.addRow([item.subjectId, item.slot, item.level.name, item.rule, item.msg, item.val])
      }
    }
    gb.setMeta(Etc.dict2("numErrs", Number(numErrs), "numWarns", Number(numWarns)))
    return gb.toGrid
  }

  ** Debug the validation rules of the current namespace.  Returns a grid
  ** with a row per `sys::ValidateRule` instance in the order the engine
  ** runs them, which is always after the rules named by their 'unless'.
  **
  ** The result grid has a row per rule:
  **   - `rule`: ref to the 'sys::ValidateRule' instance
  **   - `on`: types the rule applies to; the engine only runs the rule
  **     where the value's spec is one of them
  **   - `unless`: rules which suppress this one when they fire first
  **   - `level`: "err" or "warn"
  **   - `msg`: message template
  **   - `impl`: qname of what implements the check - a func or a native
  **     type - or null if the rule is unimplemented and so never runs
  **
  ** Examples:
  **
  **      validateRules()                              >> all rules in order
  **      validateRules.findAll(r => r.missing("impl"))  >> declared but unbound
  @Api @Axon static Grid validateRules()
  {
    gb := GridBuilder()
      .addCol("rule").addCol("on").addCol("unless")
      .addCol("level").addCol("msg").addCol("impl")
    ((MNamespace)curContext.ns).validateRules.each |r|
    {
      gb.addRow([r.id, r.on.map |Spec x->Ref| { x.id }, r.unless,
                 r.level.name, r.msg, r.impl])
    }
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Query
//////////////////////////////////////////////////////////////////////////

  ** Evaluate a relationship query and return record dict.  If no matches
  ** found throw UnknownRecErr or return null based on checked flag.
  ** If there are multiple matches it is indeterminate which one is
  ** returned.  Subject must be a record id or dict in the database.  Spec
  ** must be a Spec typed as a `sys::Query`.  Also see [queryAll()].
  **
  ** Example:
  **
  **     read(point).query(spec("ph::Point.equips"))
  @Api @Axon static Dict? query(Obj subject, Spec spec, Bool checked := true)
  {
    cx := curContext
    subjectRec := Etc.toRec(subject)
    hit := cx.ns.queryWhile(subjectRec, spec, Etc.dict0) |hit| { hit }
    if (hit != null) return hit
    if (checked) throw UnknownRecErr("@$subjectRec.id $spec.qname")
    return null
  }

  ** Evaluate a relationship query and return grid of results.
  ** Subject must be a record id or dict in the database.  Spec
  ** must be a Spec typed as a `sys::Query`.  Also see [query()].
  **
  ** Options:
  **   - `limit`: max number of recs to return
  **   - `sort`: sort by display name
  ** Example:
  **
  **     read(ahu).queryAll(spec("ph::Equip.points"))
  @Api @Axon static Grid queryAll(Obj subject, Spec spec, Dict? opts := null)
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
    cx.ns.queryWhile(subjectRec, spec, Etc.dict0) |hit|
    {
      acc.add(hit)
      if (acc.size >= limit) return "break"
      return null
    }

    // return grid result
    if (sort) Etc.sortDictsByDis(acc)
    return Etc.makeDictsGrid(null, acc)
  }

  ** Evaluate a relationship query and return the named constraints
  ** as a dict.  The query slot names are the dict names and the matching
  ** record dicts are the dict values. Missing matches are silently ignored
  ** and ambiguous matches return an indeterminate record.
  **
  ** Example:
  **
  **     // spec
  **     MyAhu: Equip {
  **       points: {
  **         dat: DischargeAirTempSensor
  **         rat: DischargeAirTempSensor
  **       }
  **     }
  **
  **     // axon
  **     myAhuPoints: read(ahu).queryNamed(spec("mylib::MyAhu.points"))
  **
  **     // result
  **     {
  **       dat: {dis:"DAT", discharge, air, temp, sensor, ...},
  **       rat: {dis:"RAT", return, air, temp, sensor, ...}
  **     }
  @Api @Axon static Dict queryNamed(Obj subject, Spec spec, Dict? opts := null)
  {
    cx := curContext
    ns := cx.ns
    subjectRec := Etc.toRec(subject)
    acc := Str:Dict[:]
    ns.queryWhile(subjectRec, spec, Etc.dict0) |hit|
    {
      spec.slots.eachWhile |slot|
      {
        name := slot.name
        if (acc[name] != null) return null // already matched
        if (ns.fits(hit, slot)) return acc[name] = hit
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

