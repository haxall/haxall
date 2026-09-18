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
    // build up rule collection
    acc := ValidateRule[,]
    ns.eachInstanceThatIs(ns.spec("sys::ValidateRule")) |x, spec|
    {
      try
      {
        r := ValidateRule.create(ns, x)
        acc.add(r)
      }
      catch (Err e) Console.cur.err("Invalid ValidateRule: $x.id", e)
    }

    // order them by their unless
    this.rules = order(acc)
  }

  private static ValidateRule[] order(ValidateRule[] list)
  {
    // first sort by qname for determinism
    list.sort

    // index by qname; an unless not in the namespace is treated as satisfied
    byQname := Str:ValidateRule[:]
    list.each |x| { byQname[x.qname] = x }

    // add rules in passes so every rule follows the rules its unless
    // references; a pass with no progress means a cycle or self
    // reference, so dump the remainder at the end
    acc := ValidateRule[,] { capacity = list.size }
    added := Str:ValidateRule[:]
    remaining := list
    while (!remaining.isEmpty)
    {
      before := remaining.size
      remaining = remaining.exclude |x|
      {
        if (!x.unless.all |u| { byQname[u.id] == null || added[u.id] != null }) return false
        acc.add(x)
        added[x.qname] = x
        return true
      }
      if (remaining.size == before)
      {
        Console.cur.err("ValidateRule cyclic unless")
        acc.addAll(remaining)
        break
      }
    }
    return acc
  }

  ** All rules in the namespace
  const ValidateRule[] rules

  ** Iterate the rules applicable to the given state
  Void eachApplicable(ValidateState s, |ValidateRule| f)
  {
    // TODO - just all for now
    rules.each(f)
  }

  ** Debug dump
  Void dump(Console con := Console.cur)
  {
    con.group("ValidateRules [$rules.size]")
    rules.each |r| { con.info("$r.id [$r.typeof.qname]") }
    con.groupEnd
  }
}

