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
    this.rules    = ns.validateRules
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
    subject := val as Dict
    if (spec == null) spec = ns.specOf(val)
    if (subject != null)
    {
      state := ValidateState.makeSubject(this, subject, spec)
      doValidate(state)
      return MValidateReport([subject], items)
    }
    else
    {
      state := ValidateState.makeVal(this, val, spec)
      doValidate(state)
      return MValidateReport(Dict#.emptyList, items)
    }
  }

  ** Validate each subject dict against its declared spec tag
  ValidateReport validateAll(Dict[] subjects)
  {
    subjects.each |s|
    {
      state := ValidateState.makeSubject(this, s, ns.specOf(s))
      doValidate(state)
    }
    return MValidateReport(subjects, items)
  }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  private Void doValidate(ValidateState s)
  {
    // run rules on current state
    rules.eachApplicable(s) |rule| { rule.check(s) }

    // dict must be be checked against spec members
    if (s.dict != null)
    {
      // check spec slots
      s.spec.slots.each |slot|
      {
        doValidateSlot(s, slot, s.dict[slot.name])
      }

      // check rest of the dict tags against globals
      globals := s.spec.globals
      s.dict.each |v, n|
      {
        global := globals.get(n, false)
        if (global != null) doValidateSlot(s, global, v)
      }
    }
  }

  private Void doValidateSlot(ValidateState s, Spec slot, Obj? val)
  {
    s.push(ValidateStateVal(slot.name, val, slot))
    doValidate(s)
    s.pop
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Accumulator one item
  Void emit(MValidateItem item) { items.add(item) }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns             // namespace
  const ValidateRules rules       // namespace rule registry
  const ValidateRefs refs         // ref target checking mode
  const Bool graph                // run graph query constraints
  const XetoFidelity fidelity     // value fidelity level
  const Bool failFast             // stop at first error
  XetoContext cx { private set }  // context
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

