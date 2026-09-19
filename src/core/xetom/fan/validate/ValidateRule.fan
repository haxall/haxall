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
** ValidateRule wraps one sys::ValidateRule instance dict
**
@Js
abstract const class ValidateRule
{
  ** Factory - right now only support built in rules
  static ValidateRule create(Namespace ns, Dict instance)
  {
    init  := ValidateRuleInit(instance)
    qname := init.id.id
    colon := qname.index(":")
    type  := StrBuf(14 + qname.size - colon).add("ValidateSys").addChar(qname[colon+2].upper).addRange(qname, colon+3..-1)
    return ValidateRule#.pod.type(type.toStr).make([init])
  }

  protected new make(ValidateRuleInit init)
  {
    this.instance = init.instance
    this.id       = init.id
    this.on       = init.on
    this.unless   = init.unless
    this.level    = init.level
    this.msg      = init.msg
  }

  const Dict instance         // instance dict definition
  const Ref id                // qualified id such as "sys::overMaxVal"
  const Ref? on               // spec this rule is registered on
  const Ref[] unless          // skip when any of these rules fired on same value
  const ValidateLevel level   // diagnostic level
  const Str msg               // message template

  ** Rule id as qname string
  Str qname() { id.id }

  ** Return qname
  override Str toStr() { qname }

  ** Is the given rule applicable to the state
  virtual Bool isApplicable(ValidateState s) { true }

  ** Run rule against given state
  Void check(ValidateState state)
  {
    state.rule = this
    onCheck(state)
    state.rule = null
  }

  ** Run rule against given state
  abstract Void onCheck(ValidateState state)
}

**************************************************************************
** ValidateRuleInit
**************************************************************************

@Js
const class ValidateRuleInit
{
  new make(Dict instance) { this.instance = instance; this.id = instance.id }

  const Dict instance

  const Ref id

  Ref? on() { instance["on"] as Ref }

  Str msg() { instance["msg"] as Str ?: id.toStr }

  ValidateLevel level()
  {
    s := instance["level"]
    if (s != null) return ValidateLevel.fromStr(s.toStr)
    return ValidateLevel.err
  }

  Ref[] unless()
  {
    v := instance["unless"]
    if (v is Ref) return Ref[v]
    if (v is List) return ((List)v).map |x->Ref| { x }
    return Ref#.emptyList
  }

}

