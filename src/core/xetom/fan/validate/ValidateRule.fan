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
  ** Construct the rule for one ValidateRule instance.  The check is
  ** whatever implements the rule: a func which tags itself with this
  ** rule's id, otherwise a Fantom class named "Validate" plus the
  ** capitalized rule name in the pod bound to the rule's lib, so
  ** 'acme.rules::customCheck' binds to 'ValidateCustomCheck' in the pod
  ** bound to 'acme.rules'.  A rule nothing implements loads unbound so
  ** it stays visible in the registry instead of disappearing.
  static ValidateRule create(Namespace ns, Dict instance, Spec? func := null)
  {
    init := ValidateRuleInit(instance, ns)
    if (func != null) return ValidateFuncRule(init, func)
    type := findType(init.id)
    return type == null ? ValidateUnboundRule(init) : type.make([init])
  }

  ** Reflect the check class for a rule id or null if none
  private static Type? findType(Ref id)
  {
    qname := id.id
    colon := qname.index("::")
    if (colon == null) return null

    pod := podFor(qname[0..<colon])
    if (pod == null) return null

    name := StrBuf(8 + qname.size - colon - 2).add("Validate")
      .addChar(qname[colon+2].upper).addRange(qname, colon+3..-1)
    return pod.type(name.toStr, false)
  }

  ** Pod which implements a lib's rules.  The sys and ph rules live here
  ** in xetom: both are Project Haystack libs which cannot name a Fantom
  ** pod, and neither registers a lib binding in the xeto.bindings index.
  private static Pod? podFor(Str lib)
  {
    if (lib == "sys" || lib == "ph") return ValidateRule#.pod
    podName := SpecBindings.cur.libToPod(lib)
    return podName == null ? null : Pod.find(podName, false)
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

  ** Does this rule have a check implementation
  virtual Bool isBound() { true }

  ** Qualified name of what implements the check, or null if unbound
  virtual Str? impl() { typeof.qname }

  ** Is this rule applicable to a position with the given spec.  A rule
  ** runs where the spec is one of its 'on' types; the check itself then
  ** narrows on the constraint meta it enforces.  Must be a pure function
  ** of spec since ValidateRules caches the result per spec.
  virtual Bool isApplicable(Spec spec)
  {
    on.any |x| { spec.isa(x) }
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
** ValidateUnboundRule
**************************************************************************

**
** ValidateUnboundRule is a rule declared without a check implementation.
** It never runs, but stays in the registry so tooling can see that the
** rule is defined and unbound rather than missing.
**
@Js
internal const class ValidateUnboundRule : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Bool isBound() { false }
  override Str? impl() { null }
  override Bool isApplicable(Spec spec) { false }
  override Void onCheck(ValidateState s) {}
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

