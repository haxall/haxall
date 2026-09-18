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
    this.root        = ValidateStateVal(null, subject, spec)
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
    this.root        = ValidateStateVal(null, val, spec)
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

  ** Current value or null if at the subject level
  Spec spec() { cur.spec }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Emit a validation item for the current state and rule
  Void emit(Dict args := Etc.dict0)
  {
    validator.emit(MValidateItem(rule ?: Err("Not in ValidateRule.check"), this, args))
  }

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
  internal ValidateRule? rule
}

**************************************************************************
** ValidateStateVal
**************************************************************************

@Js
internal const class ValidateStateVal
{
  new make(Str? name, Obj? val, Spec spec)
  {
    this.name = name
    this.val  = val
    this.spec = spec
    this.dict = val as Dict
    if (dict == null)
    {
      this.num = val as Number
    }
  }

  const Str? name     // slot name or null for root subject
  const Obj? val      // current value
  const Dict? dict    // val as Dict
  const Number? num   // val as Number
  const Spec spec     // current value spec
}

