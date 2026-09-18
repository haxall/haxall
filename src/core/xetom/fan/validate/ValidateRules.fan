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
** ValidateRules indexes the ValidateRule instances of a namespace.
** Rules are registered on a spec via their 'on' ref: constraint rules
** on the meta spec they enforce such as "sys::Spec.maxVal", structural
** rules on the type they check.
**
@Js
const class ValidateRules
{
  ** Build registry from all ValidateRule instances in namespace
  new make(MNamespace ns)
  {
    byRule := Str:ValidateRule[:]
    byOn   := Str:ValidateRule[][:]
    ns.eachInstanceThatIs(ns.spec("sys::ValidateRule")) |x, spec|
    {
      try
      {
        r := ValidateRule(x)
        byRule[r.qname] = r
        if (r.on == null) return
        onId := r.on.id
        byOn[onId] = (byOn[onId] ?: ValidateRule[,]).add(r)
      }
      catch (Err e) Console.cur.err("Invalid ValidateRule: $x.id", e)
    }
    this.byRule = byRule
    this.byOn   = byOn
  }

  ** Lookup rule by qname such as "sys::overMaxVal"
  ValidateRule? rule(Str qname, Bool checked := true)
  {
    r := byRule[qname]
    if (r != null) return r
    if (checked) throw UnknownNameErr("ValidateRule: $qname")
    return null
  }

  ** Lookup rules registered on given spec qname
  ValidateRule[] on(Str qname)
  {
    byOn[qname] ?: ValidateRule#.emptyList
  }

  private const Str:ValidateRule byRule  // rule qname -> rule
  private const Str:ValidateRule[] byOn  // on target qname -> rules
}

**************************************************************************
** ValidateRule
**************************************************************************

**
** ValidateRule wraps one sys::ValidateRule instance dict
**
@Js
const class ValidateRule
{
  new make(Dict instance)
  {
    this.instance = instance
    this.id       = instance.id
    this.on       = instance["on"] as Ref
    this.level    = ValidateLevel.fromStr(instance["level"]?.toStr ?: "err")
    this.msg      = instance["msg"] as Str ?: id.id
  }

  const Dict instance         // instance dict definition
  const Ref id                // qualified id such as "sys::overMaxVal"
  const Ref? on               // spec this rule is registered on
  const ValidateLevel level   // diagnostic level
  const Str msg               // message template

  ** Rule id as qname string
  Str qname() { id.id }

  ** Render msg template with given args scope
  Str render(Dict args) { Etc.macro(msg, args) }

  override Str toStr() { qname }
}

