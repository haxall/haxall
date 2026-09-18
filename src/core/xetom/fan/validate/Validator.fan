//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Sep 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** Validator is the new validation engine designed to replace Fitter.
** Skeleton: the walk and rule dispatch are scaffolded end to end with
** most checks stubbed; overMaxVal is implemented as the tracer.
**
@Js
class Validator
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, XetoContext cx, Dict opts)
  {
    this.ns       = ns
    this.cx       = cx
    this.rules    = ValidateRules(ns)
    this.refs     = ValidateRefs.fromStr(opts["refs"] as Str ?: "conform")
    this.graph    = opts.has("graph")
    this.fidelity = XetoUtil.optFidelity(opts)
    this.failFast = opts.has("failFast")
  }

//////////////////////////////////////////////////////////////////////////
// Entry Points
//////////////////////////////////////////////////////////////////////////

  ** Validate value against spec, or its own spec if null
  ValidateReport validate(Obj? val, Spec? spec)
  {
    subject = val as Dict ?: Etc.dict0
    if (spec == null) spec = ns.specOf(val)
    validateVal(val, spec)
    return MValidateReport([subject], items)
  }

  ** Validate each subject dict against its declared spec tag
  ValidateReport validateAll(Dict[] subjects)
  {
    subjects.each |s| { validateSubject(s) }
    return MValidateReport(subjects, items)
  }

  private Void validateSubject(Dict x)
  {
    subject = x
    specRef := x["spec"] as Ref
    if (specRef == null) return emit(rule("sys::missingSpecRef"), Etc.dict0)
    spec := ns.spec(specRef.id, false)
    if (spec == null) return emit(rule("sys::unresolvedRef"), Etc.dict1("ref", specRef))
    validateVal(x, spec)
  }

//////////////////////////////////////////////////////////////////////////
// Walk
//////////////////////////////////////////////////////////////////////////

  private Void validateVal(Obj? val, Spec spec)
  {
    // TODO: type conformance (invalidType, unknownType)
    if (val is Dict) return validateDict(val, spec)
    if (val is List) return validateList(val, spec)
    validateScalar(val, spec)
  }

  private Void validateDict(Dict dict, Spec spec)
  {
    // TODO: choices, queries, globals, undeclared tags, sugar constraints
    ns.specx(spec).slots.each |slot| { validateSlot(dict, slot) }
  }

  private Void validateSlot(Dict dict, Spec slot)
  {
    if (slot.type.isChoice || slot.type.isQuery) return // TODO

    val := dict.get(slot.name)
    if (val == null)
    {
      if (!slot.isMaybe) emit(rule("sys::missingSlot"), Etc.dict1("slotName", slot.name))
      return
    }

    push(slot.name)
    validateVal(val, slot)
    pop
  }

  private Void validateList(Obj?[] list, Spec spec)
  {
    // TODO: listNullItem, listItemType, size constraints
    checkMeta(spec, list)
  }

  private Void validateScalar(Obj? val, Spec spec)
  {
    // TODO: enum, pattern, invariant, refs
    checkMeta(spec, val)
  }

//////////////////////////////////////////////////////////////////////////
// Rule Dispatch
//////////////////////////////////////////////////////////////////////////

  ** Dispatch rules registered on each constraint meta tag present
  private Void checkMeta(Spec spec, Obj? val)
  {
    spec.meta.each |v, n|
    {
      rules.on("sys::Spec.$n").each |r| { dispatch(r, spec, val) }
    }
  }

  ** Bound Fantom implementations keyed by rule qname
  private Void dispatch(ValidateRule rule, Spec spec, Obj? val)
  {
    switch (rule.qname)
    {
      case "sys::overMaxVal": checkOverMaxVal(rule, spec, val)
      // TODO: remaining built-in rules; Axon rules via XetoContext hook
    }
  }

//////////////////////////////////////////////////////////////////////////
// Checks
//////////////////////////////////////////////////////////////////////////

  private Void checkOverMaxVal(ValidateRule rule, Spec spec, Obj? val)
  {
    max := spec.meta["maxVal"] as Number
    x := val as Number
    if (max == null || x == null) return
    if (max.unit != null && max.unit != x.unit) return // maxValUnit's check
    if (x > max) emit(rule, Etc.dictx("val", x, "maxVal", max))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Emit item for rule with msg rendered from args
  private Void emit(ValidateRule rule, Dict args)
  {
    items.add(MValidateItem(
      rule.id, rule.level, subject, slotPath, rule.render(args), args["val"]))
  }

  private ValidateRule rule(Str qname) { rules.rule(qname) }

  private Str? slotPath() { slotStack.isEmpty ? null : slotStack.join(".") }

  private Void push(Str name) { slotStack.push(name) }

  private Void pop() { slotStack.pop }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const MNamespace ns
  private const ValidateRules rules
  private const ValidateRefs refs      // ref target checking mode
  private const Bool graph             // run graph query constraints
  private const XetoFidelity fidelity  // value fidelity level
  private const Bool failFast          // stop at first error
  private XetoContext cx
  private Dict subject := Etc.dict0
  private Str[] slotStack := [,]
  private MValidateItem[] items := [,]
}

**************************************************************************
** ValidateRefs
**************************************************************************

** Ref target checking mode
@Js
enum class ValidateRefs
{
  none,     // do not check ref targets
  exists,   // check ref targets resolve
  conform   // check ref targets resolve and fit their 'of' type
}
