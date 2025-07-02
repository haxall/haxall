//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jan 2023  Brian Frank  Creation
//

using util
using xeto

**
** Fitter
**
@Js
internal class Fitter
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, XetoContext cx, Dict opts, Bool failFast := true)
  {
    this.ns = ns
    this.failFast = failFast
    this.opts = opts
    this.isGraph = opts.has("graph")
    this.ignoreRefs = opts.has("ignoreRefs")
    this.checkVal = CheckVal(opts)
    this.cx = cx
  }

//////////////////////////////////////////////////////////////////////////
// Spec Fits
//////////////////////////////////////////////////////////////////////////

  Bool specFits(Spec a, Spec b)
  {
    // if a is nonimally typed as b, then definitely fits
    if (a.isa(b)) return true

    // scalars are fit only by their nominal types
    if (a.isScalar) return a.type.isa(b.type)

    // dicts are fit by structural typing
    if (b.isDict)
    {
      if (!a.isDict) return false
      return specFitsStruct(a, b)
    }

    // no joy
    return explainInvalidType(b, a)
  }

  private Bool specFitsStruct(Spec a, Spec b)
  {
    r := b.slots.eachWhile |bslot|
    {
      aslot := a.slot(bslot.name, false)
      if (aslot == null) return "nofit"
      return specFits(aslot, bslot) ? null : "nofit"
    }
    return r == null
  }

//////////////////////////////////////////////////////////////////////////
// Instance Fits
//////////////////////////////////////////////////////////////////////////

  Bool valFits(Obj? val, Spec spec)
  {
    // get type for value
    valType := ns.specOf(val, false)
    if (valType == null)
      return explainNoType(val)

    // check dict using structural typing
    if (val is Dict && spec.isa(ns.sys.dict))
    {
      this.curId = ((Dict)val).get("id") as Ref
      return fitsStruct(val, spec)
    }

    // check list using structural typing
    if (val is List && spec.isa(ns.sys.list))
      return fitsList(val, spec)

    // check that type matches
    if (!valTypeFits(spec.type, valType, val))
      return explainInvalidType(spec, valType)

    // check value against spec meta
    fits := true
    checkVal.check((CSpec)spec, val) |msg|
    {
      fits = explainValErr(spec, msg)
    }
    if (!fits) return false

    // ref targets
    if (spec.isRef || spec.isMultiRef || val is Ref)
    {
      if (!checkRefTarget(spec, val)) return false
    }

    return true
  }

  private Bool valTypeFits(Spec type, Spec valType, Obj val)
  {
    // check if fits by nominal typing
    if (valType.isa(type)) return true

    // if type is a non-sys scalar, then allow string
    if (type.isScalar && valType.qname == "sys::Str" && allowStrScalar(type)) return true

    // MultiRef may be either Ref or Ref[]
    if (type.isMultiRef)
    {
      if (val is Ref) return true
      if (val is List) return ((List)val).all |x| { x is Ref }
    }

    return false
  }

  private Bool allowStrScalar(Spec type)
  {
    // don't allow strings for any sys types that have fantom types
    if (type.lib.isSys)
    {
      // although we have Unit/TimeZone, in Haystack we just use Str
      if (type.name == "Unit" || type.name == "TimeZone" || type.name == "Filter") return true
      return false
    }

    return true
  }

  private Bool fitsStruct(Dict dict, Spec type)
  {
    slots := type.slots
    if (type.isChoice && slots.isEmpty) return false

    matchFail := false  // did we have any failed matches
    matchSucc := 0      // num of success matches
    matchId   := false
    slots.each |slot|
    {
      match := fitsSlot(dict, slot)
      if (match == null) return // null means we just skipped optional slot
      if (match) { matchSucc++; if (slot.name == "id") matchId = true }
      else matchFail = true
      if (failFast && matchFail) return
    }

    // we don't consider only Entity.id a valid match
    if (matchSucc == 1 && matchId) matchSucc = 0

    // check values that don't have slot defs
    dict.each |v, n|
    {
      // if there is a slot we already checked it above
      if (slots.has(n)) return

      // check value
      push(n)
      try
      {
        // check globals
        if (!checkSlotAgainstGlobals(type, n, v)) matchFail = true

        // check non slot
        if (!checkNonSlotVal(type, n, v)) matchFail = true
      }
      finally
      {
        pop
      }
    }

    // must have no fails
    if (matchFail) return false

    // must have at least one success unless type is sys::Dict itself
    return matchSucc > 0 || type === ns.sys.dict
  }

  private Bool? fitsSlot(Dict dict, Spec slot)
  {
    push(slot.name)
    try
    {
      slotType := slot.type

      if (slotType.isChoice) return fitsChoice(dict, slot)

      if (slotType.isQuery) return fitsQuery(dict, slot)

      val := dict.get(slot.name, null)

      if (val == null)
      {
        if (slot.isMaybe) return null
        return explainMissingSlot(slot)
      }

      return valFits(val, slot)
    }
    finally
    {
      pop
    }
  }

  private Bool fitsList(Obj?[] list, Spec spec)
  {
    // always check spec meta
    fits := true
    checkVal.check((CSpec)spec, list) |err|
    {
      fits = explainValErr(spec, err)
    }

    // if no item type, then it fits!
    of := spec.of(false)
    while (of != null && XetoUtil.isAutoName(of.name))
      of = of?.base
    if (of == null) return fits

    // check every item
    list.each |v|
    {
      if (v == null)
      {
        if (!of.isMaybe)
         fits = explainValErr(spec, "List type cannot contain nulls")
      }
      else
      {
        valType := ns.specOf(v, false)
        if (valType == null)
          fits = explainValErr(spec, "List item type is '$of', item type is unknown [$v.typeof]")
        else if (!valType.isa(of))
          fits = explainValErr(spec, "List item type is '$of', item type is '$valType'")
      }
    }
    return fits
  }

  private Bool checkSlotAgainstGlobals(Spec spec, Str name, Obj val)
  {
    global := ns.global(name, false)
    if (global == null) return true

    return valFits(val, global)
  }

  private Bool checkNonSlotVal(Spec spec, Str name, Obj val)
  {
    if (val is Ref && name != "id" && name != "spec")
      return doCheckRefTarget(spec, null, val)

    return true
  }

  private Bool? fitsChoice(Dict dict, Spec slot)
  {
    selection := XetoSpec[,]
    cslot := (CSpec)slot
    MChoice.findSelections(ns, cslot, dict, selection)
    Str? err := null
    MChoice.validate(cslot, selection) |msg| { err = msg }
    if (err == null) return true
    return explainChoiceErr(slot, err)
  }

  private Bool? fitsQuery(Dict dict, Spec query)
  {
    // don't check queries if not fitting graph
    if (!isGraph) return null

    // if no constraints then no additional checking required
    if (query.slots.isEmpty) return null

    // run the query to get matching extent
    Dict[]? extent
    try
    {
      extent = Query(ns, cx, opts).query(dict, query)
    }
    catch (Err e)
    {
      echo("ERROR: fitsQuery: $query\n$e")
      return null
    }

    // use query.of as explain name
    ofDis := query.of(false)?.name ?: query.name

    // make sure each constraint has exactly one match
    match := true
    query.slots.eachWhile |constraint|
    {
      match = fitQueryConstraint(dict, ofDis, extent, constraint) && match
      if (failFast && !match) return "break"
      return null
    }

    return match
  }

  private Bool fitQueryConstraint(Dict rec, Str ofDis, Dict[] extent, Spec constraint)
  {
    matches := Dict[,]
    extent.each |x|
    {
      if (Fitter(ns, cx, opts).valFits(x, constraint)) matches.add(x)
    }

    if (matches.size == 1) return true

    if (matches.size == 0)
    {
      if (constraint.isMaybe) return true
      return explainMissingQueryConstraint(ofDis, constraint)
    }

    return explainAmbiguousQueryConstraint(ofDis, constraint, matches)
  }

  private Bool checkRefTarget(Spec spec, Obj val)
  {
    // don't check if ignoreRefs option specified
    if (ignoreRefs) return true

    // don't do this for id
    if (spec.name == "id") return true

    // expected target type
    of := spec.of(false)

    // Ref value
    if (val is Ref) return doCheckRefTarget(spec, of, val)

    // List of Refs value
    if (val is List)
    {
      result := true
      ((List)val).each |x|
      {
        ref := x as Ref
        if (ref == null)
        {
          explainValErr(spec, "Expect Ref in List<of:Ref>: $x [$x.typeof]")
          result = false
        }
        else
        {
          xok := doCheckRefTarget(spec, of, ref)
          if (!xok) result = false
        }
      }
      return result
    }

    return explainValErr(spec, "Expecting Ref or List<of:Ref>: $val [$val.typeof]")
  }

  private Bool doCheckRefTarget(Spec spec, Spec? of, Ref ref)
  {
    Dict? target := null
    if(ref.id.contains("::"))
    {
      // read spec/instance
      target = ns.spec(ref.id, false)
      if (target == null)
        target = ns.instance(ref.id, false)
    }
    else
    {
      // read from context
      target = cx.xetoReadById(ref)
    }
    if (target == null)
    {
      if (ignoreRefs) return true
      return explainValErr(spec, "Unresolved ref @$ref.id")
    }

    if (of != null)
    {
      targetSpecRef := target["spec"] as Ref
      if (targetSpecRef == null)
        return explainValErr(spec, "Ref target missing spec tag: @$ref.id")

      // short circuit if qnames match exactly (useful for testing too)
      if (targetSpecRef.id == of.qname) return true

      // resolve target spec (allow testing code to fall thru to next check)
      targetSpec := ns.spec(targetSpecRef.id, false)
      if (targetSpec == null && !targetSpecRef.id.startsWith("temp"))
        return explainValErr(spec, "Ref target spec not found: '$targetSpecRef'")

      // check target type
      if (targetSpec == null || !targetSpec.isa(of))
        return explainValErr(spec, "Ref target must be '$of.qname', target is '$targetSpecRef'")
    }

    return true
  }

//////////////////////////////////////////////////////////////////////////
// Slots
//////////////////////////////////////////////////////////////////////////

  ** Currently in a slot?
  Bool inSlot() { !slotStack.isEmpty }

  ** Current slot name or null
  Str? slotName() { slotStack.peek }

  ** Push slot onto the stack
  Void push(Str slotName) { slotStack.push(slotName) }

  ** Pop slot from stack
  Void pop() { slotStack.pop }

//////////////////////////////////////////////////////////////////////////
// Lint Explain
//////////////////////////////////////////////////////////////////////////

  virtual Bool explainNoType(Obj? val) { false }

  virtual Bool explainInvalidType(Spec spec, Spec valType) { false }

  virtual Bool explainMissingSlot(Spec slot) { false }

  virtual Bool explainMissingQueryConstraint(Str ofDis, Spec constraint) { false }

  virtual Bool explainAmbiguousQueryConstraint(Str ofDis, Spec constraint, Dict[] matches) { false }

  virtual Bool explainValErr(Spec slot, Str msg) { false }

  virtual Bool explainChoiceErr(Spec slot, Str msg) { false }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  Ref? curId
  private const MNamespace ns
  private const Bool failFast
  private const Dict opts
  private const Bool isGraph
  private const Bool ignoreRefs
  private const CheckVal checkVal
  private XetoContext cx
  private Str[] slotStack := [,]
}

**************************************************************************
** ExplainFitter
**************************************************************************

@Js
internal class ExplainFitter : Fitter
{
  new make(MNamespace ns, XetoContext cx, Dict opts, |XetoLogRec| cb)
    : super(ns, cx, opts, false)
  {
    this.cb = cb
  }

  override Bool explainNoType(Obj? val)
  {
    log("Value not mapped to data type [${val?.typeof}]")
  }

  override Bool explainInvalidType(Spec spec, Spec valType)
  {
    type := spec.type
    if (spec.isGlobal)
      log("Global slot type is '$type', value type is '$valType'")
    else if (inSlot)
      log("Slot type is '$type', value type is '$valType'")
    else
      log("Type '$valType' does not fit '$type'")
    return false
  }

  override Bool explainMissingSlot(Spec slot)
  {
    if (slot.type.isMarker)
      return log("Missing required marker")
    else
      return log("Missing required slot")
  }

  override Bool explainMissingQueryConstraint(Str ofDis, Spec constraint)
  {
    log("Missing required $ofDis: " + constraintToDis(constraint))
  }

  override Bool explainAmbiguousQueryConstraint(Str ofDis, Spec constraint, Dict[] matches)
  {
    log("Ambiguous match for $ofDis: " + constraintToDis(constraint) + " [" + recsToDis(matches) + "]")
  }

  override Bool explainValErr(Spec slot, Str msg)
  {
    log(msg)
  }

  override Bool explainChoiceErr(Spec slot, Str msg)
  {
    log(msg)
  }

  private Bool log(Str msg)
  {
    if (inSlot) msg = "Slot '$slotName': $msg"
    cb(XetoLogRec(LogLevel.err, curId, msg, FileLoc.unknown, null))
    return false
  }

  private Str constraintToDis(Spec constraint)
  {
    n := constraint.name
    if (XetoUtil.isAutoName(n)) return constraint.type.qname
    return n
  }

  private Str recsToDis(Dict[] recs)
  {
    s := StrBuf()
    recs.sort |a, b| { a["id"] <=> b["id"] }
    for (i := 0; i<recs.size; ++i)
    {
      rec := recs[i]
      str := "@" + rec->id
      dis := ((Dict)rec).dis
      if (dis != null) str += " $dis.toCode"
      s.join(str, ", ")
      if (s.size > 50 && i+1<recs.size)
        return s.add(", ${recs.size - i - 1} more ...").toStr
    }
    return s.toStr
  }

  private |XetoLogRec| cb
}

