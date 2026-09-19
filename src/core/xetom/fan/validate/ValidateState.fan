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
    this.root        = ValidateStateVal(ns, null, subject, spec)
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
    this.root        = ValidateStateVal(ns, null, val, spec)
    this.cur         = root
  }

//////////////////////////////////////////////////////////////////////////
// Subject
//////////////////////////////////////////////////////////////////////////

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
  private const Namespace ns
  private const ValidateStateVal root
  private ValidateStateVal[] stack := [,]
  private ValidateStateVal cur
  private Ref[] fired := [,]         // rules fired on current value
  internal ValidateRule? rule        // rule currently in check
}

**************************************************************************
** ValidateStateVal
**************************************************************************

@Js
internal const class ValidateStateVal
{
  new make(Namespace ns, Str? name, Obj? val, Spec spec)
  {
    this.name    = name
    this.val     = val
    this.spec    = spec
    this.valType = ns.specOf(val, false)
    this.dict    = val as Dict
    if (dict == null)
    {
      this.num = val as Number
    }
  }

  const Str? name      // slot name or null for root subject
  const Obj? val       // current value
  const Dict? dict     // val as Dict
  const Number? num    // val as Number
  const Spec spec      // current value spec
  const Spec? valType  // actual type of val or null if unmapped
}

