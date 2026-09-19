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
** Xeto validation engine
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
    this.strSpec      = ns.sys.str
    this.numberSpec   = ns.sys.number
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

    // bare value validation runs the slot level intrinsics too
    spec = specx(spec ?: ns.specOf(val))
    state := ValidateState.makeVal(this, val, spec)
    doValidateSlot(state)
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
    s.push(ValidateStateVal(this, slot.name, val, slot))
    doValidateSlot(s)
    s.pop
  }

  private Void doValidateSlot(ValidateState s)
  {
    // choice slots are validated against the parent dict's markers
    if (s.spec.isChoice) return run(s)

    // perform intrinsic checks before running all the rules
    if (isMissingSlot(s)) return rules.missingSlot.emit(s)
    if (s.val == null) return // absent maybe slot
    if (s.valType == null) return rules.unknownType.emit(s)
    if (!isValidType(s)) return rules.invalidType.emit(s)

    // run thru the standard rules
    doValidate(s)
  }

  private Bool isMissingSlot(ValidateState s)
  {
    if (s.val != null) return false
    if (s.spec.isMaybe || s.spec.isChoice || s.spec.isQuery) return false
    return true
  }

  private Bool isValidType(ValidateState s)
  {
    type    := s.spec.type
    val     := s.val
    valType := s.valType

    // haystack fidelity has special scalar restrictions; at full
    // fidelity scalars must be their mapped Fantom type or xeto::Scalar
    if (fidelity.isHaystack && type.isScalar)
    {
      // haystack fidelity erases Int/Float/Duration to plain Number
      if (type.isa(numberSpec)) return s.num != null

      // if built-in haystack kind then must match exactly
      if  (type.isHaystack) return valType === type

      // otherwise all non-haystack scalars must map to string
      return valType === strSpec
    }

    // a dict without a spec tag is checked as a standard dict
    // against the declared slot type
    if (s.dict != null && s.dict.missing("spec")) return true

    // if it fits by direct nominal typing
    if (valType.isa(type)) return true

    // MultiRef may be either Ref or Ref[]
    if (type.isMultiRef)
    {
      if (val is Ref) return true
      if (val is List) return ((List)val).all |x| { x is Ref }
    }

    // invalid type
    return false
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

  ** Resolve ref target once per validation run
  internal ValidateRef resolveRef(Ref ref)
  {
    x := refCache[ref.id]
    if (x == null)
    {
      Dict? target
      if (ref.id.contains("::"))
      {
        target = (Dict?)ns.spec(ref.id, false) ?: ns.instance(ref.id, false)
      }
      else
      {
        target = cx.xetoReadById(ref)
      }
      refCache[ref.id] = x = ValidateRef(ref, target)
    }
    return x
  }

  ** Map value to list of ValidateRef
  internal ValidateRef[] resolveRefs(Spec spec, Obj? v)
  {
    if (ignoreRefs || spec.name == "id") return ValidateRef#.emptyList
    if (v is Ref) return [resolveRef(v)]
    if (v is List && spec.isMultiRef)
    {
      acc := ValidateRef[,]
      ((List)v).each |x| { if (x is Ref) acc.add(resolveRef(x)) }
      return acc
    }
    return ValidateRef#.emptyList
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
  const Spec strSpec              // spec for sys::Str
  const Spec numberSpec           // spec for sys::Number
  XetoContext cx { private set }
  private MValidateItem[] items := [,]
  private Str:Spec specxCache := [:]
  private Str:ValidateRef refCache := [:]
}

