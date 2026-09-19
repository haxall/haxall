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
    this.ns           = ns
    this.cx           = cx
    this.rules        = ns.validateRules
    this.fidelity     = XetoUtil.optFidelity(opts)
    this.ignoreRefs   = opts.has("ignoreRefs")
    this.ignoreMixins = opts.has("ignoreMixins")
    this.graph        = opts.has("graph")
  }

//////////////////////////////////////////////////////////////////////////
// Entry Points
//////////////////////////////////////////////////////////////////////////

  ** Validate value against spec, or its own spec if null
  ValidateReport validate(Obj? val, Spec? spec)
  {
    // subject validation
    subject := val as Dict
    if (subject != null)
    {
      if (spec == null)
      {
        validateSubject(subject)
      }
      else
      {
        state := ValidateState.makeSubject(this, subject, specx(spec))
        doValidate(state)
      }
      return MValidateReport([subject], items)
    }

    // bare value validation
    spec = specx(spec ?: ns.specOf(val))
    state := ValidateState.makeVal(this, val, spec)
    doValidate(state)
    return MValidateReport(Dict#.emptyList, items)
  }

  ** Validate each subject dict against its declared spec tag
  ValidateReport validateAll(Dict[] subjects)
  {
    subjects.each |s| { validateSubject(s) }
    return MValidateReport(subjects, items)
  }

  ** Validate subject against the spec derived from its spec tag
  private Void validateSubject(Dict subject)
  {
    // fail fast when subject has no spec tag
    specRef := subject["spec"] as Ref
    if (specRef == null)
    {
      state := ValidateState.makeSubject(this, subject, ns.sys.dict)
      rules.missingSpecRef.emit(state)
      return
    }

    // fail fast when specRef cannot be resolved
    spec := ns.spec(specRef.id, false)
    if (spec == null)
    {
      state := ValidateState.makeSubject(this, subject, ns.sys.dict)
      rules.unknownSpecRef.emit(state, Etc.dict1("spec", specRef))
      return
    }

    // run thru standard subject validation
    spec = specx(spec)
    state := ValidateState.makeSubject(this, subject, spec)
    doValidate(state)
  }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  private Void doValidate(ValidateState s)
  {
    // run rules on current state
    run(s)

    // dict must be be checked against spec members
    if (s.dict != null)
    {
      // check spec slots
      s.spec.slots.each |slot|
      {
        validateSlot(s, slot, s.dict[slot.name])
      }

      // check rest of the dict tags against globals
      globals := s.spec.globals
      s.dict.each |v, n|
      {
        global := globals.get(n, false)
        if (global != null) validateSlot(s, global, v)
      }
    }
  }

  private Void run(ValidateState s)
  {
    s.reset
    rules.each |r|
    {
      if (!r.isApplicable(s)) return
      if (s.suppressed(r)) return
      r.check(s)
    }
  }

  private Void validateSlot(ValidateState s, Spec slot, Obj? val)
  {
    s.push(ValidateStateVal(ns, slot.name, val, slot))
    doValidateSlot(s)
    s.pop
  }

  private Void doValidateSlot(ValidateState s)
  {
    // perform intrinsic checks before running all the rules
    if (isMissingSlot(s)) return rules.missingSlot.emit(s)
    if (isInvalidType(s)) return rules.invalidType.emit(s)

    // run thru the standard rules
    doValidate(s)
  }

  private Bool isMissingSlot(ValidateState s)
  {
    if (s.val != null) return false
    if (s.spec.isMaybe || s.spec.isChoice || s.spec.isQuery) return false
    return true
  }

  private Bool isInvalidType(ValidateState s)
  {
    return false // TODO
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Accumulator one item
  Void emit(MValidateItem item) { items.add(item) }

  ** Compute specx once per spec
  Spec specx(Spec spec)
  {
    if (ignoreMixins) return spec
    x := specxCache[spec.qname]
    if (x == null) specxCache[spec.qname] = x = ns.specx(spec)
    return x
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns             // namespace
  const ValidateRules rules       // namespace rule registry
  const XetoFidelity fidelity     // value fidelity level
  const Bool ignoreMixins         // use or ignore mixins
  const Bool ignoreRefs           // check or skip refs targets
  const Bool graph                // run graph query constraints
  XetoContext cx { private set }
  private MValidateItem[] items := [,]
  private Str:Spec specxCache := [:]
}

