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
** ValidateRules is the ValidateRule instances of a namespace ordered so
** that every rule follows the rules its 'unless' names.  Rules declare
** the types they apply to via their 'on' refs; the engine short circuits
** on those types rather than running every rule at every position.
**
@Js
const class ValidateRules
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Build registry from all ValidateRule instances in namespace
  new make(MNamespace ns) : this.makeLibs(ns, ns.libs) {}

  ** Build registry from ValidateRule instances in given libs.  Compiler
  ** passes a lib's depends, so this ctor must use only lib  only lookups.
  new makeLibs(Namespace ns, Lib[] libs)
  {
    // funcs with validateRule meta tag
    funcs := findFuncs(libs)

    // build up rule collection
    ruleSpec := ns.spec("sys::ValidateRule")
    list := ValidateRule[,]
    map  := Str:ValidateRule[:]
    libs.each |lib|
    {
      lib.instances.each |x|
      {
        specRef := x["spec"] as Ref
        if (specRef == null) return
        spec := ns.spec(specRef.id, false)
        if (spec == null || !spec.isa(ruleSpec)) return
        try
        {
          r := ValidateRule.create(ns, x, funcs[x.id.id])
          list.add(r)
          map.add(r.qname, r)
        }
        catch (Err e) Console.cur.err("Invalid ValidateRule: $x.id", e)
      }
    }

    // order them by their unless, and get special constants
    this.rules = order(list, map)
    this.missingSpecRef = map.getChecked("sys::missingSpecRef")
    this.unknownSpecRef = map.getChecked("sys::unknownSpecRef")
    this.missingSlot    = map.getChecked("sys::missingSlot")
    this.invalidType    = map.getChecked("sys::invalidType")
    this.unknownType    = map.getChecked("sys::unknownType")
  }

  ** Map rule qname to the func which implements it.  Two funcs claiming
  ** the same rule is ambiguous, so neither is used.
  private static Str:Spec findFuncs(Lib[] libs)
  {
    acc := Str:Spec[:]
    dups := Str[,]
    libs.each |lib|
    {
      lib.funcs.each |f|
      {
        rule := f.meta["validateRule"] as Ref
        if (rule == null) return
        if (acc[rule.id] != null) dups.add(rule.id)
        acc[rule.id] = f
      }
    }
    dups.each |id|
    {
      Console.cur.err("Multiple funcs implement ValidateRule: $id")
      acc.remove(id)
    }
    return acc
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

  ** Iterate the rules applicable to the state's current position in
  ** registry order, so a rule always follows the rules its unless names
  Void eachApplicable(ValidateState s, |ValidateRule| f)
  {
    rules.each |r| { if (r.isApplicable(s)) f(r) }
  }

  internal const ValidateIntrinsicRule missingSpecRef
  internal const ValidateIntrinsicRule unknownSpecRef
  internal const ValidateIntrinsicRule missingSlot
  internal const ValidateIntrinsicRule invalidType
  internal const ValidateIntrinsicRule unknownType

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

