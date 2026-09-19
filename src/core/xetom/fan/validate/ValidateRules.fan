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

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Build registry from all ValidateRule instances in namespace
  new make(MNamespace ns)
  {
    // build up rule collection
    list := ValidateRule[,]
    map  := Str:ValidateRule[:]
    ns.eachInstanceThatIs(ns.spec("sys::ValidateRule")) |x, spec|
    {
      try
      {
        r := ValidateRule.create(ns, x)
        list.add(r)
        map.add(r.qname, r)
      }
      catch (Err e) Console.cur.err("Invalid ValidateRule: $x.id", e)
    }

    // order them by their unless, and get special constants
    this.rules = order(list, map)
    this.missingSpecRef = map.getChecked("sys::missingSpecRef")
    this.unknownSpecRef = map.getChecked("sys::unknownSpecRef")
    this.missingSlot    = map.getChecked("sys::missingSlot")
    this.invalidType    = map.getChecked("sys::invalidType")
  }

  private static ValidateRule[] order(ValidateRule[] list, Str:ValidateRule map)
  {
    // first sort by qname for determinism
    list.sort

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
        if (!x.unless.all |u| { map[u.id] == null || added[u.id] != null }) return false
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

//////////////////////////////////////////////////////////////////////////
// Rules
//////////////////////////////////////////////////////////////////////////

  const ValidateRule[] rules

  Void each(|ValidateRule| f) { rules.each(f) }

  internal const ValidateIntrinsicRule missingSpecRef
  internal const ValidateIntrinsicRule unknownSpecRef
  internal const ValidateIntrinsicRule missingSlot
  internal const ValidateIntrinsicRule invalidType

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  Void dump(Console con := Console.cur)
  {
    con.group("ValidateRules [$rules.size]")
    rules.each |r| { con.info("$r.id [$r.typeof.qname]") }
    con.groupEnd
  }
}

