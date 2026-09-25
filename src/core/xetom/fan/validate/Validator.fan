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

  ** The compiler passes its own depends scoped rules registry; the
  ** runtime defaults to the full namespace registry
  new make(MNamespace ns, XetoContext cx, Dict opts, ValidateRules? rules := null)
  {
    this.ns           = ns
    this.cx           = cx
    this.opts         = opts
    this.rules        = rules ?: ns.validateRules
    this.fidelity     = XetoUtil.optFidelity(opts)
    this.ignoreRefs   = opts.has("ignoreRefs")
    this.ignoreMixins = opts.has("ignoreMixins")
    this.ignoreMissingSlots   = opts.has("ignoreMissingSlots")
    this.ignoreUnresolvedRefs = opts.has("ignoreUnresolvedRefs")
    this.graph        = opts.has("graph")
    this.strSpec      = ns.sys.str
    this.numberSpec   = ns.sys.number
    this.multiRefSpec = ns.sys.multiRef
    this.resolveSpecFunc = |Str q->Spec?| { resolveSpec(q) }
  }

//////////////////////////////////////////////////////////////////////////
// Entry Points
//////////////////////////////////////////////////////////////////////////

  ** Validate value against spec, or its own spec if null; the compiler
  ** passes the source file location to carry into reported items
  ValidateReport validate(Obj? val, Spec? spec, FileLoc loc := FileLoc.unknown)
  {
    // subject validation
    subject := val as Dict
    if (subject != null)
    {
      if (spec == null)
      {
        validateSubject(subject, loc)
      }
      else
      {
        state := ValidateState.makeSubject(this, subject, specx(spec), loc)
        doValidate(state)
      }
      return MValidateReport([subject], items)
    }

    // bare value validation runs the slot level intrinsics too
    spec = specx(spec ?: ns.specOf(val))
    state := ValidateState.makeVal(this, val, spec, loc)
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
  private Void validateSubject(Dict subject, FileLoc loc := FileLoc.unknown)
  {
    // fail fast when subject has no spec tag
    specRef := subject["spec"] as Ref
    if (specRef == null)
    {
      state := ValidateState.makeSubject(this, subject, ns.sys.dict, loc)
      rules.missingSpecRef.emit(state)
      return
    }

    // fail fast when specRef cannot be resolved
    spec := resolveSpec(specRef.id)
    if (spec == null)
    {
      state := ValidateState.makeSubject(this, subject, ns.sys.dict, loc)
      rules.unknownSpecRef.emit(state, Etc.dict1("spec", specRef))
      return
    }

    // run thru standard subject validation
    spec = specx(spec)
    state := ValidateState.makeSubject(this, subject, spec, loc)
    doValidate(state)
  }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  private Void doValidate(ValidateState s)
  {
    // run rules on current state
    run(s)

    // recurse list items as frames typed by the item type
    if (s.list != null) return validateItems(s)

    // dict must be be checked against spec members
    if (s.dict != null)
    {
      // check spec slots
      s.spec.slots.each |slot|
      {
        validateSlot(s, slot.name, slot, s.dict[slot.name])
      }
      members := s.spec.members

      // check rest of the dict tags: members chain resolves globals
      // after slots; unknown tags with ref values get their targets
      // checked for existence, and scalar wrappers are checked against
      // the spec they name for themselves.  Dicts under unknown tags
      // are open content and pass - running entity rules on such
      // fragments would be far stricter than a self consistency check.
      // The id and spec tag names are reserved and exempt.
      s.dict.each |v, n|
      {
        if (s.spec.slots.has(n)) return // walked as declared slot above
        member := members.get(n, false)
        if (member != null) return validateSlot(s, member.name, member, v)
        if (n == "id" || n == "spec") return
        if (isUnknownRefs(v)) return validateSlot(s, n, v is List ? multiRefSpec : ns.sys.ref, v)
        if (v is Scalar)
        {
          sp := specOf(v)
          if (sp != null) validateSlot(s, n, specx(sp), v)
        }
      }
    }
  }

  private Void run(ValidateState s)
  {
    s.reset
    rules.eachApplicable(s) |r|
    {
      if (s.suppressed(r)) return
      r.check(s)
    }
  }

  ** Validate each list item against the parameterized item type;
  ** null items are reported by the listNullItem rule at list level
  private Void validateItems(ValidateState s)
  {
    of := s.listOf
    if (of == null) return
    ofx := specx(of)
    s.list.each |v, i|
    {
      if (v != null) validateSlot(s, i.toStr, ofx, v)
    }
  }

  ** Is unknown tag value a Ref or list of Refs to target check
  private static Bool isUnknownRefs(Obj? v)
  {
    if (v is Ref) return true
    list := v as List
    return list != null && !list.isEmpty && list.all |x| { x is Ref }
  }

  private Void validateSlot(ValidateState s, Str name, Spec spec, Obj? val)
  {
    s.push(ValidateStateVal(this, name, val, spec))
    doValidateSlot(s)
    s.pop
  }

  private Void doValidateSlot(ValidateState s)
  {
    // choice slots are validated against the parent dict's markers
    if (s.spec.isChoice) return run(s)

    // query slots are validated against the graph extent
    if (s.spec.isQuery) return doValidateQuery(s)

    // perform intrinsic checks before running all the rules
    if (isMissingSlot(s)) return rules.missingSlot.emit(s)
    if (s.val == null) return // absent maybe slot
    if (s.valType == null) return rules.unknownType.emit(s)
    if (!isValidType(s)) return rules.invalidType.emit(s, Etc.dict1("expecting", expecting(s)))

    // run thru the standard rules
    doValidate(s)
  }

  ** Choice and query slots never reach here; see doValidateSlot
  private Bool isMissingSlot(ValidateState s)
  {
    !ignoreMissingSlots && s.val == null && !s.spec.isMaybe
  }

  private Bool isValidType(ValidateState s)
  {
    type    := s.spec.type
    val     := s.val
    valType := s.valType

    // if it fits by direct nominal typing
    if (valType.isa(type)) return true

    // haystack fidelity scalars may be their erased type; at full
    // fidelity scalars must be their mapped Fantom type or xeto::Scalar
    if (isErased(type)) return valType.isa(haystackType(type))

    // a dict without a spec tag is checked as a standard dict against
    // the declared slot type, but only when that type is itself a dict
    if (s.dict != null && s.dict.missing("spec") && type.isDict) return true

    // MultiRef may be either Ref or Ref[]
    if (type.isMultiRef)
    {
      if (val is Ref) return true
      if (val is List) return ((List)val).all |x| { x is Ref }
    }

    // invalid type
    return false
  }

  ** Expected types for invalidType message including haystack erasure
  private Str expecting(ValidateState s)
  {
    type := s.spec.type
    erased := isErased(type) ? haystackType(type) : type
    return erased === type ? "'$type.qname'" : "'$type.qname' or '$erased.qname'"
  }

  ** Is type a scalar erased by haystack fidelity
  private Bool isErased(Spec type) { fidelity.isHaystack && type.isScalar }

  ** Haystack encoding of scalar type: Int/Float/Duration erase
  ** to Number, haystack kinds are themselves, all others Str
  private Spec haystackType(Spec type)
  {
    if (type.isa(numberSpec)) return numberSpec
    if (type.isHaystack) return type
    return strSpec
  }

  private Void doValidateQuery(ValidateState s)
  {
    // graph queries are opt-in and only checked when constrained
    if (!graph) return
    query := s.spec
    if (query.slots.isEmpty) return
    subject := s.parentDict
    if (subject == null) return

    // run query to get extent; errors leave the query unchecked
    Dict[]? extent
    try
      extent = Query(ns, cx, opts).query(subject, query)
    catch (Err e)
      return

    // recs anchored on a constraint by their spec tag match it alone;
    // the rest are free to match unclaimed constraints structurally
    claims := Str:Dict[][:]
    free := Dict[,]
    extent.each |x|
    {
      c := anchorOf(x, query)
      if (c == null) free.add(x)
      else claims.getOrAdd(c.name) { Dict[,] }.add(x)
    }

    // compute matches per constraint once for the query rules
    acc := ValidateQueryMatch[,]
    query.slots.each |c|
    {
      matches := claims[c.name] ?: free.findAll |x| { fits(x, c) }
      acc.add(ValidateQueryMatch(c, matches))
    }
    s.queryMatches = acc
    run(s)
    s.queryMatches = null
  }

  ** Constraint of query which rec's spec tag names directly or thru
  ** an override in a subtype query.  This is nominal only: sibling
  ** constraints with equal tags are computed sugar subtypes of each
  ** other, so isa would bind the rec to all of them
  private Spec? anchorOf(Dict x, Spec query)
  {
    for (t := specOf(x); t != null; t = t.base)
    {
      c := query.slots.get(t.name, false)
      if (c != null && c.qname == t.qname) return c
    }
    return null
  }

  ** Does extent rec fit the query constraint which is anonymous
  ** sugar; spec resolution goes thru the specOf hook
  private Bool fits(Dict x, Spec c)
  {
    t := specOf(x)
    return t != null && XetoUtil.fits(t, x, c)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Accumulator one item
  Void emit(MValidateItem item)
  {
    items.add(item)
    onEmit(item)
  }

  ** Compute specx once per spec; the ignoreMixins opt skips mixin
  ** composition here, which the compiler requires since specx
  ** enumerates a namespace still under construction
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
        target = (Dict?)resolveSpec(ref.id) ?: resolveInstance(ref.id)
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

  ** Choice subtypes computed once per validation run
  internal Obj[] choiceSubtypes(Spec spec)
  {
    x := choiceCache[spec.type.qname]
    if (x == null) choiceCache[spec.type.qname] = x = MChoice.findChoiceSubtypes(cns, spec)
    return x
  }

//////////////////////////////////////////////////////////////////////////
// Compiler Hooks
//////////////////////////////////////////////////////////////////////////

  ** Hook when new item is emitted
  virtual Void onEmit(MValidateItem item) {}

  ** Resolution hooks: the compiler overrides these to overlay the lib
  ** under compile, which is not in the namespace yet.  Everything the
  ** engine resolves by qname or value funnels through here.

  ** Resolve spec qname to its spec or null
  virtual Spec? resolveSpec(Str qname) { ns.spec(qname, false) }

  ** Resolve instance qname to its dict or null
  virtual Dict? resolveInstance(Str qname) { ns.instance(qname, false) }

  ** Map value to its actual spec or null if unmapped; all qname
  ** resolution funnels thru resolveSpec
  Spec? specOf(Obj? val) { XetoUtil.specOf(ns.sys, val, resolveSpecFunc) }

  ** Namespace for type enumeration such as choice subtype discovery;
  ** the compiler substitutes its AST aware namespace
  virtual CNamespace cns() { ns }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns             // namespace
  const ValidateRules rules       // namespace rule registry
  const XetoFidelity fidelity     // value fidelity level
  const Bool ignoreRefs           // check or skip refs targets
  const Bool ignoreMixins         // skip mixin composition in specx
  const Bool ignoreMissingSlots   // skip missing slot checks (compiler)
  const Bool ignoreUnresolvedRefs // skip unresolved ref checks (compiler)
  const Bool graph                // run graph query constraints
  const Dict opts                 // raw options for engine plumbing
  const Spec strSpec              // spec for sys::Str
  const Spec numberSpec           // spec for sys::Number
  const Spec multiRefSpec         // spec for sys::MultiRef
  XetoContext cx { private set }
  private |Str->Spec?| resolveSpecFunc
  private MValidateItem[] items := [,]
  private Str:Spec specxCache := [:]
  private Str:ValidateRef refCache := [:]
  private Str:Obj[] choiceCache := [:]
}

