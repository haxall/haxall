//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Aug 2020  Brian Frank  Creation
//

using xeto
using haystack

**
** MFilterInference provides the standard inference engine for
** filter queries.  This support class is designed to be used by
** HaystackContext instances to lazily build and cache the
** expensive lookup tables transiently.
**
** This is pulled out into a helper class because its very expensive
** to build a full descendants list without blowing up the cache
** data structures of MNamespace.
**
@NoDoc @Js
class MFilterInference : FilterInference
{
  ** Constructor
  new make(DefNamespace ns) { this.ns = ns }

  ** Return if subject is-a type - if the given symbol
  ** implements the term or any of is descendants
  override Bool isA(Dict subject, Symbol symbol)
  {
    // most calls will use the same symbol since they are
    // iterating the same filter over many entities; so optimize
    // to use the last symbol handler
    if (cur?.symbol == symbol) return cur.matches(subject)

    // lookup entry for given symbol, lazily create
    cur = cache.find |x| { x.symbol == symbol }
    if (cur == null)
    {
      cur = MFilterInferenceSymbol(ns, symbol)
      cache.add(cur)
    }
    return cur.matches(subject)
  }

  private const DefNamespace ns
  private MFilterInferenceSymbol? cur
  private MFilterInferenceSymbol[] cache := [,]
}

**************************************************************************
** MFilterInferenceSymbol
**************************************************************************

@Js
internal class MFilterInferenceSymbol
{
  ** Construct support instance for given namespace and def
  new make(DefNamespace ns, Symbol symbol)
  {
    this.symbol = symbol
    this.descendants = findDescendants(ns, symbol)
  }

  private static Symbol[] findDescendants(DefNamespace ns, Symbol symbol)
  {
    // lookup def and if not found we just use symbol itself
    def := ns.def(symbol.toStr, false)
    if (def == null) return [symbol]

    // each call to subtypes forces a full iteration of the namespace
    // for every iteration, so its crazy expensive; however to do one
    // iteration with inheritance would force loading and caching the
    // inheritance list for every single def
    acc := Str:Symbol[:]
    doFindDescendants(acc, ns, def)
    return acc.vals
  }

  private static Void doFindDescendants(Str:Symbol acc, DefNamespace ns, Def def)
  {
    key := def.symbol.toStr
    if (acc.containsKey(key)) return
    acc[key] = def.symbol
    ns.subtypes(def).each |kid| { doFindDescendants (acc, ns, kid) }
  }

  Bool matches(Dict subject)
  {
    descendants.any |symbol| { symbol.hasTerm(subject) }
  }

  const Symbol symbol
  private Symbol[] descendants
}

