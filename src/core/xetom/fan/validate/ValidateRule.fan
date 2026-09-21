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
    init  := ValidateRuleInit(instance, ns)
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
  const Spec[] on             // types this rule applies to
  const Ref[] unless          // skip when any of these rules fired on same value
  const ValidateLevel level   // diagnostic level
  const Str msg               // message template

  ** Rule id as qname string
  Str qname() { id.id }

  ** Return qname
  override Str toStr() { qname }

  ** Is this rule applicable to the state's current position.  A rule runs
  ** where the position's spec is one of its 'on' types; the check itself
  ** then narrows on the constraint meta it enforces.
  virtual Bool isApplicable(ValidateState s)
  {
    on.any |x| { s.spec.isa(x) }
  }

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
  new make(Dict instance, Namespace ns)
  {
    this.instance = instance
    this.id       = instance.id
    this.ns       = ns
  }

  const Dict instance

  const Ref id

  private const Namespace ns

  ** Types this rule applies to; an unresolved ref is skipped so one bad
  ** target cannot silently widen the rule to every position
  Spec[] on()
  {
    refs("on").mapNotNull |r->Spec?| { ns.spec(r.id, false) }
  }

  Str msg() { instance["msg"] as Str ?: id.toStr }

  ValidateLevel level()
  {
    s := instance["level"]
    if (s != null) return ValidateLevel.fromStr(s.toStr)
    return ValidateLevel.err
  }

  Ref[] unless() { refs("unless") }

  ** Decode a MultiRef tag which may be a single Ref or list of Refs
  private Ref[] refs(Str name)
  {
    v := instance[name]
    if (v is Ref) return Ref[v]
    if (v is List) return ((List)v).map |x->Ref| { x }
    return Ref#.emptyList
  }

}

