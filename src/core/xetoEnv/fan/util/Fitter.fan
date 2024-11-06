//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jan 2023  Brian Frank  Creation
//

using util
using xeto
using haystack::Dict

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
    return explainNoFit(a, b)
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

  Bool valFits(Obj? val, Spec type)
  {
    // get type for value
    valType := ns.specOf(val, false)
    if (valType == null) return explainNoType(val)

    // check structurally typing
    if (val is Dict && type.isa(ns.sys.dict))
      return fitsStruct(val, type)

    // check enums
    if (type.isEnum && val is Str) return fitsEnum(val, type)

    // check nominal typing
    if (valType.isa(type)) return true

    return explainNoFit(valType, type)
  }

  private Bool fitsEnum(Str val, Spec enum)
  {
    // first match slot name without key
    slot := enum.slot(val, false)
    if (slot != null && slot.meta.missing("key")) return true

    // iterate slots to find key
    r := enum.slots.eachWhile |x|
    {
      x.meta["key"] as Str == val ? "found": null
    }
    return r != null
  }

  private Bool fitsStruct(Dict dict, Spec type)
  {
    slots := type.slots
    if (type.isChoice && slots.isEmpty) return false


    matchFail := false  // did we have any failed matches
    matchSucc := false  // did we have any success matches
    slots.each |slot|
    {
      match := fitsSlot(dict, slot)
      if (match == null) return // null means we just skipped optional slot
      if (match) matchSucc = true
      else matchFail = true
      if (failFast && matchFail) return false
    }

    // must have no fails
    if (matchFail) return false

    // must have at least one success unless type is sys::Dict itself
    return matchSucc || type === ns.sys.dict
  }

  private Bool? fitsSlot(Dict dict, Spec slot)
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

    valFits := Fitter(ns, cx, opts).valFits(val, slotType)
    if (!valFits) return explainInvalidSlotType(val, slot)

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
    extent := Query(ns, cx, opts).query(dict, query)

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

//////////////////////////////////////////////////////////////////////////
// Lint Explain
//////////////////////////////////////////////////////////////////////////

  virtual Bool explainNoType(Obj? val) { false }

  virtual Bool explainNoFit(Spec valType, Spec type) { false }

  virtual Bool explainMissingSlot(Spec slot) { false }

  virtual Bool explainInvalidSlotType(Obj val, Spec slot) { false }

  virtual Bool explainMissingQueryConstraint(Str ofDis, Spec constraint) { false }

  virtual Bool explainAmbiguousQueryConstraint(Str ofDis, Spec constraint, Dict[] matches) { false }

  virtual Bool explainChoiceErr(Spec slot, Str msg) { false }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const MNamespace ns
  private const Bool failFast
  private const Dict opts
  private const Bool isGraph
  private XetoContext cx
}

**************************************************************************
** ExplainFitter
**************************************************************************

@Js
internal class ExplainFitter : Fitter
{
  new make(MNamespace ns,  XetoContext cx, Dict opts, |XetoLogRec| cb)
    : super(ns, cx, opts, false)
  {
    this.cb = cb
  }

  override Bool explainNoType(Obj? val)
  {
    log("Value not mapped to data type [${val?.typeof}]")
  }

  override Bool explainNoFit(Spec valType, Spec type)
  {
    log("Type '$valType' does not fit '$type'")
  }

  override Bool explainMissingSlot(Spec slot)
  {
    if (slot.type.isMarker)
      return log("Missing required marker '$slot.name'")
    else
      return log("Missing required slot '$slot.name'")
  }

  override Bool explainMissingQueryConstraint(Str ofDis, Spec constraint)
  {
    log("Missing required $ofDis: " + constraintToDis(constraint))
  }

  override Bool explainAmbiguousQueryConstraint(Str ofDis, Spec constraint, Dict[] matches)
  {
    log("Ambiguous match for $ofDis: " + constraintToDis(constraint) + " [" + recsToDis(matches) + "]")
  }

  override Bool explainInvalidSlotType(Obj val, Spec slot)
  {
    log("Slot '$slot.name': Slot type is '$slot.type', value type is '${val.typeof}'")
  }

  override Bool explainChoiceErr(Spec slot, Str msg)
  {
    log(msg)
  }

  private Bool log(Str msg)
  {
    cb(MLogRec(LogLevel.err, msg, FileLoc.unknown, null))
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

