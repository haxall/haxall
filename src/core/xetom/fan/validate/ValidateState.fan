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
** ValidateState captures context for a given rule to execute
**
@Js
class ValidateState
{

//////////////////////////////////////////////////////////////////////////
// Constructors
//////////////////////////////////////////////////////////////////////////

  ** Constructor for top level subject
  protected new makeSubject(Validator validator, Dict subject, Spec spec, FileLoc loc := FileLoc.unknown)
  {
    this.validator   = validator
    this.ns          = validator.ns
    this.subject     = subject
    this.reflect     = ns.reflect(subject, spec)
    this.subjectSpec = spec
    this.loc         = loc
    this.root        = ValidateStateVal(validator, null, subject, spec)
    this.cur         = root
  }

  ** Constructor for top level non dict value
  protected new makeVal(Validator validator, Obj? val, Spec spec, FileLoc loc := FileLoc.unknown)
  {
    this.validator   = validator
    this.ns          = validator.ns
    this.subject     = Etc.dict0
    this.reflect     = ns.reflect(subject, spec)
    this.subjectSpec = spec
    this.loc         = loc
    this.root        = ValidateStateVal(validator, null, val, spec)
    this.cur         = root
  }

//////////////////////////////////////////////////////////////////////////
// Subject
//////////////////////////////////////////////////////////////////////////

  ** Namespace of validation run
  const Namespace ns

  ** Subject
  const Dict subject

  ** Subject spec we are validating against
  const Spec subjectSpec

  ** Reflection of subject
  const ReflectDict reflect

  ** File location if applicable
  const FileLoc loc

//////////////////////////////////////////////////////////////////////////
// Current Value
//////////////////////////////////////////////////////////////////////////

  ** Current value
  Obj? val() { cur.val }

  ** Current value as dict
  Dict? dict() { cur.dict }

  ** Current value as number
  Number? num() { cur.num }

  ** Spec of the current position: the subject spec at subject
  ** level, or the member spec when positioned on a slot value
  Spec spec() { cur.spec }

  ** Actual type of current value or null if unmapped
  Spec? valType() { cur.valType }

  ** Current value as list when positioned on a list typed slot
  Obj?[]? list() { cur.list }

  ** Parameterized item type when positioned on a list typed slot
  Spec? listOf() { cur.listOf }

  ** Fidelity level of this validation run
  XetoFidelity fidelity() { validator.fidelity }

  ** Enclosing dict of the current slot value or null at subject level
  Dict? parentDict()
  {
    if (stack.isEmpty) return null
    return stack.size == 1 ? root.dict : stack[-2].dict
  }

  ** Refs of the current Ref or MultiRef value paired with their
  ** resolved targets.  Empty when the value is not refs, when
  ** positioned on the id slot, or when ignoreRefs is opted in.
  ValidateRef[] refs() { cur.refs }

  ** Read the rec targeted by a Ref tag of the current dict, or null if
  ** the tag is missing, is not a Ref, or does not resolve.  Used by rules
  ** which must compare a rec against another rec it points to.  Targets
  ** are resolved once per validation run.
  Dict? readRef(Str name)
  {
    ref := dict?.get(name) as Ref
    if (ref == null) return null
    return validator.resolveRef(ref).target
  }

  ** Read the recs targeted by a Ref or MultiRef tag of the current dict.
  ** Unresolved refs are skipped, so the result may be shorter than the
  ** tag's own list; empty when the tag is missing or holds no refs.
  Dict[] readRefs(Str name)
  {
    v := dict?.get(name)
    if (v is Ref)
    {
      target := validator.resolveRef(v).target
      return target == null ? Dict#.emptyList : [target]
    }
    list := v as List
    if (list == null) return Dict#.emptyList
    return list.mapNotNull |x->Dict?|
    {
      x is Ref ? validator.resolveRef(x).target : null
    }
  }

  ** Constraint matches when positioned on a query slot with the
  ** graph option enabled, or null otherwise.  The extent is queried
  ** and matched once for the query rules.
  ValidateQueryMatch[]? queryMatches { internal set }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Emit a validation item for the current state and rule
  Void emit(Dict args := Etc.dict0)
  {
    r := rule ?: throw Err("Not in ValidateRule.check")
    fired.add(r.id)
    validator.emit(MValidateItem(r, this, args))
  }

  ** Emit a validation item against a slot of the current dict instead of
  ** the current position.  A rule registered on a type reports where the
  ** problem is: a rule on an entity spec fires once at the entity, but
  ** flags the offending tag so tools can highlight that form field.  The
  ** item takes its slot path, value, and spec from the slot, so '$val'
  ** and the other msg vars resolve against it.
  **
  ** The name may be any tag of the current dict; a tag without a declared
  ** slot reports against the value with the dict's own spec.
  Void emitOn(Str name, Dict args := Etc.dict0)
  {
    dict := this.dict ?: throw Err("Not positioned on a dict")
    slot := spec.member(name, false) ?: spec
    push(ValidateStateVal(validator, name, dict.get(name), slot))
    try
      emit(args)
    finally
      pop
  }

  ** Emit a validation item for the current state and rule
  Void emitRule(ValidateRule rule, Dict args := Etc.dict0)
  {
    this.rule = rule
    emit(args)
    this.rule = null
  }

  ** Is rule suppressed because an unless rule fired on current value
  internal Bool suppressed(ValidateRule rule)
  {
    !rule.unless.isEmpty && rule.unless.any |u| { fired.contains(u) }
  }

  ** Clear fired rules when walk positions on a new value
  internal Void reset() { fired.clear }

  ** Current slot path in the subject or null if not applicable
  Str? slotPath()
  {
    s := StrBuf()
    stack.each |x| { s.joinNotNull(x.name, ".") }
    return s.isEmpty ? null : s.toStr
  }

  internal Void push(ValidateStateVal x)
  {
    stack.push(x)
    cur = x
  }

  internal Void pop()
  {
    stack.pop
    cur = stack.peek ?: root
  }

//////////////////////////////////////////////////////////////////////////
// Private Fields
//////////////////////////////////////////////////////////////////////////

  private Validator validator
  private const ValidateStateVal root
  private ValidateStateVal[] stack := [,]
  private ValidateStateVal cur
  private Ref[] fired := [,]         // rules fired on current value
  internal ValidateRule? rule        // rule currently in check
}

**************************************************************************
** ValidateRef
**************************************************************************

** ValidateRef pairs a ref value with its resolved target
@Js
const class ValidateRef
{
  internal new make(Ref ref, Dict? target)
  {
    this.ref    = ref
    this.target = target
  }

  const Ref ref       // ref value
  const Dict? target  // resolved target or null if unresolved

  override Str toStr() { ref.toStr }
}

**************************************************************************
** ValidateQueryMatch
**************************************************************************

** ValidateQueryMatch pairs one query constraint with its extent matches
@Js
const class ValidateQueryMatch
{
  internal new make(Spec constraint, Dict[] matches)
  {
    this.constraint = constraint
    this.matches    = matches
  }

  const Spec constraint  // query constraint slot
  const Dict[] matches   // extent records matching the constraint

  override Str toStr() { constraint.toStr }
}

**************************************************************************
** ValidateStateVal
**************************************************************************

@Js
internal const class ValidateStateVal
{
  new make(Validator validator, Str? name, Obj? val, Spec spec)
  {
    this.name    = name
    this.val     = val
    this.spec    = spec
    this.valType = validator.ns.specOf(val, false)
    this.refs    = validator.resolveRefs(spec, val)

    // specific value types
    this.dict = val as Dict
    if (dict == null)
    {
      this.num = val as Number
      if (spec.type.isList)
      {
        this.list = val as List
        if (list != null) this.listOf = XetoUtil.ofType(spec, false)
      }
    }
  }

  const Str? name           // slot name or null for root subject
  const Obj? val            // current value
  const Dict? dict          // val as Dict
  const Number? num         // val as Number
  const Spec spec           // current value spec
  const Spec? valType       // actual type of val or null if unmapped
  const ValidateRef[] refs  // resolved ref or ref[]
  const Obj?[]? list        // val as List when spec is a list type
  const Spec? listOf        // parameterized item type when list
}

