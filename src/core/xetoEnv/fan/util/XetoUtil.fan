//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Feb 2023  Brian Frank  Creation
//

using util
using xeto
using haystack::Etc
using haystack::Ref
using haystack::UnknownNameErr

**
** Utility functions
**
@Js
const class XetoUtil
{

//////////////////////////////////////////////////////////////////////////
// Naming
//////////////////////////////////////////////////////////////////////////

  ** Return if valid spec name
  static Bool isSpecName(Str n)
  {
    if (n.isEmpty) return false
    ch := n[0]

    // _123
    if (ch == '_') return n.all |c, i| { i == 0 || c.isDigit }

    // Foo_Bar_123
    if (!ch.isAlpha) return false
    return n.all |c| { c.isAlphaNum || c == '_' }
  }

  ** Return if name is "_" + digits
  static Bool isAutoName(Str n)
  {
    if (n.size < 2 || n[0] != '_' || !n[1].isDigit) return false
    for (i:=2; i<n.size; ++i) if (!n[i].isDigit) return false
    return true
  }

  ** Convert "fooBarBaz" or "FooBarBaz" to "foo.bar.baz".
  static Str camelToDotted(Str name, Int dot := '.')
  {
    s := StrBuf(name.size + 4)
    name.each |char|
    {
      if (char.isUpper)
      {
        if (!s.isEmpty) s.addChar(dot)
        s.addChar(char.lower)
      }
      else
      {
        s.addChar(char)
      }
    }
    return s.toStr
  }

  ** Convert "fooBarBaz" or "FooBarBaz" to "foo-bar-baz".
  static Str camelToDashed(Str name)
  {
    camelToDotted(name, '-')
  }

  ** Convert "foo.bar.baz" to "fooBarBaz"
  static Str dottedToCamel(Str name, Int dot := '.')
  {
    s := StrBuf(name.size)
    capitalize := false
    name.each |char|
    {
      if (char == dot)
        capitalize = true
      else if (capitalize)
        { s.addChar(char.upper); capitalize = false }
      else
        s.addChar(char)
    }
    return s.toStr
  }

  ** Convert "foo-bar-baz" to "fooBarBaz"
  static Str dashedToCamel(Str name)
  {
    dottedToCamel(name, '-')
  }

  ** Convert "foo.bar::Baz" to simple name "Baz" or null if no "::"
  static Str? qnameToName(Str qname)
  {
    colon := qname.indexr(":")
    if (colon == null || colon < 2 || colon+1 >= qname.size || qname[colon-1] != ':') return null
    return qname[colon+1..-1]
  }

  ** Convert "foo.bar::Baz" to lib name "foo.bar" or null if no "::"
  static Str? qnameToLib(Str qname)
  {
    colon := qname.index(":")
    if (colon == null || colon < 1 || colon+2 >= qname.size || qname[colon+1] != ':') return null
    return qname[0..<colon]
  }

//////////////////////////////////////////////////////////////////////////
// Opts
//////////////////////////////////////////////////////////////////////////

  ** Get logging function from options
  static |XetoLogRec|? optLog(Dict? opts, Str name)
  {
    if (opts == null) return null
    x := opts.get(name, null)
    if (x == null) return null
    if (x is Unsafe) x = ((Unsafe)x).val
    if (x is Func) return x
    throw Err("Expecting |XetoLogRec| func for $name.toCode [$x.typeof]")
  }

//////////////////////////////////////////////////////////////////////////
// Is-A
//////////////////////////////////////////////////////////////////////////

  ** Return if a is-a b
  static Bool isa(CSpec a, CSpec b, Bool isTop := true)
  {
    // check if a and b are the same
    if (a === b) return true

    // if A is "maybe" type, then it also matches None
    if (b.isNone && a.isMaybe && isTop) return true

    // if A is sys::And type, then check any of A.ofs is B
    if (a.isBaseAnd)
    {
      ofs := a.cofs
      if (ofs != null && ofs.any |x| { x.cisa(b) }) return true
    }

    // if A is sys::Or type, then check all of A.ofs is B
    if (a.isBaseOr)
    {
      ofs := a.cofs
      if (ofs != null && ofs.all |x| { x.cisa(b) }) return true
    }

    // if B is sys::Or type, then check if A is any of B.ofs
    if (b.isBaseOr)
    {
      ofs := b.cofs
      if (ofs != null && ofs.any |x| { a.cisa(x) }) return true
    }

    // check a's base type
    if (a.cbase != null) return isa(a.cbase, b, false)

    return false
  }

//////////////////////////////////////////////////////////////////////////
// ChoiceOf
//////////////////////////////////////////////////////////////////////////

  ** Implementation of XetoEnv.choiceOf
  static Spec? choiceOf(MEnv env, Dict instance, Spec choice, Bool checked)
  {
    // TODO: need namespace, but for now only use declared lib
    ns := choice.lib
    acc := Spec[,]
    ns.types.each |x|
    {
      if (!x.isa(choice)) return
      if (x.slots.isEmpty) return
      if (hasChoiceMarkers(instance, x)) acc.add(x)
    }

    // TODO: for now just compare on number of tags so that {hot, water}
    // trumps {water}. But that isn't correct because {naturalGas, hot, water}
    // would actually be incorrect with multiple matches
    if (acc.size > 1)
    {
      maxSize := 0
      acc.each |XetoSpec x| { maxSize = maxSize.max(x.m.slots.size) }
      acc = acc.findAll |XetoSpec x->Bool| { x.m.slots.size == maxSize }
    }

    // if exactly one
    if (acc.size == 1) return acc.first

    if (checked)
    {
      if (acc.isEmpty) throw Err("Choice not implemented by instance: $choice")
      else throw Err("Multiple choices implemented by instance: $choice $acc")
    }
    return null
  }

  ** Return if instance has all the given tags of the given choice
  static Bool hasChoiceMarkers(Dict instance, Spec choice)
  {
    r := choice.slots.eachWhile |slot|
    {
      instance.has(slot.name) ? null : "break"
    }
    return r == null
  }

//////////////////////////////////////////////////////////////////////////
// Derive
//////////////////////////////////////////////////////////////////////////

  ** Dervice a new spec from the given base, meta, and map
  static Spec derive(MEnv env, Str name, XetoSpec base, Dict meta, [Str:Spec]? slots)
  {
    // sanity checking
    if (!isSpecName(name)) throw ArgErr("Invalid spec name: $name")
    if (!base.isDict)
    {
      if (slots != null && !slots.isEmpty) throw ArgErr("Cannot add slots to non-dict type: $base")
    }

    spec := XetoSpec()
    m := MDerivedSpec(env, null, env.names.add(name), base, MNameDict(env.names.dictDict(meta)), deriveSlots(env, spec, slots), deriveFlags(base, meta))
    XetoSpec#m->setConst(spec, m)
    return spec
  }

  private static Int deriveFlags(XetoSpec base, Dict meta)
  {
    flags := base.m.flags
    if (meta.has("maybe")) flags = flags.or(MSpecFlags.maybe)
    return flags
  }

  private static MSlots deriveSlots(MEnv env, XetoSpec parent, [Str:Spec]? slotsMap)
  {
    if (slotsMap == null || slotsMap.isEmpty) return MSlots.empty

    derivedMap := slotsMap.map |XetoSpec base, Str name->XetoSpec|
    {
      XetoSpec(MDerivedSpec(env, parent, env.names.add(name), base, base.m.meta, base.m.slots, base.m.flags))
    }

    return MSlots(env.names.dictMap(derivedMap))
  }

//////////////////////////////////////////////////////////////////////////
// Instantiate
//////////////////////////////////////////////////////////////////////////

  ** Instantiate default value of spec
  static Obj? instantiate(MEnv env, XetoSpec spec, Dict opts)
  {
    meta := spec.m.meta
    if (meta.has("abstract") && opts.missing("abstract")) throw Err("Spec is abstract: $spec.qname")

    if (spec.isNone) return null
    if (spec.isScalar || spec.has("val")) return instantiateScalar(env, spec, meta)
    if (spec === env.sys.dict) return env.dict0
    if (spec.isList) return env.list0

    isGraph := opts.has("graph")

    acc := Str:Obj[:]
    acc.ordered = true

    id := opts["id"]
    if (id == null && isGraph) id = Ref.gen
    if (id != null) acc["id"] = id

    acc["dis"] = spec.name

    spec.slots.each |slot|
    {
      if (slot.isMaybe) return
      if (slot.isQuery) return
      if (slot.type === env.sys.ref && slot.name != "enum") return // fill-in siteRef, equipRef, etc
      acc[slot.name] = instantiate(env, slot, opts)
    }

    parent := opts["parent"] as Dict
    if (parent != null && parent["id"] is Ref)
    {
      // TODO: temp hack for equip/point common use case
      parentId := (Ref)parent["id"]
      if (parent.has("equip"))   acc["equipRef"] = parentId
      if (parent.has("site"))    acc["siteRef"]  = parentId
      if (parent.has("siteRef")) acc["siteRef"]  = parent["siteRef"]
    }

    dict := env.dictMap(acc)

    if (opts.has("graph"))
      return instantiateGraph(env, spec, opts, dict)
    else
      return dict
  }

  private static Obj instantiateScalar(MEnv env, XetoSpec spec, Dict meta)
  {
    meta["val"] ?: ""
  }

  private static Dict[] instantiateGraph(MEnv env, XetoSpec spec, Dict opts, Dict dict)
  {
    opts = Etc.dictSet(opts, "parent", dict)
    graph := Dict[,]
    graph.add(dict)

    // recursively add constrained query children
    spec.slots.each |slot|
    {
      if (!slot.isQuery) return
      if (slot.slots.isEmpty) return
      slot.slots.each |x|
      {
        kids := instantiate(env, x.base, opts)
        if (kids isnot List) return
        graph.addAll(kids)
      }
    }

    return graph
  }

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

  ** Generate AST dict tree for entire lib
  static Dict genAstLib(XetoEnv env, Lib lib, Bool isOwn, Dict opts)
  {
    acc := Str:Obj[:]
    acc.ordered = true

    acc["type"] = "sys::Lib"

    lib.meta.each |v, n|
    {
      if (n == "val" && v === env.marker) return
      acc[n] = genAstVal(env, v)
    }

    slots := Str:Obj[:]
    slots.ordered = true
    lib.tops.each |spec|
    {
      slots.add(spec.name, genAstSpec(env, spec, isOwn, opts))
    }
    acc.add("slots", env.dictMap(slots))

    return env.dictMap(acc)
  }

  ** Generate AST dict tree for spec
  static Dict genAstSpec(XetoEnv env, Spec spec, Bool isOwn, Dict opts)
  {
    acc := Str:Obj[:]
    acc.ordered = true

    if (spec.isType)
    {
      if (spec.base != null)  acc["base"] = spec.base.qname
    }
    else
    {
      acc["type"] = spec.type.qname
    }

    Dict meta := isOwn ? spec.metaOwn : spec.meta
    meta.each |v, n|
    {
      if (n == "val" && v === env.marker) return
      acc[n] = genAstVal(env, v)
    }

    if (opts.has("fileloc"))
      acc["fileloc"] = spec.loc.toStr

    slots := isOwn ? spec.slotsOwn : spec.slots
    if (!slots.isEmpty)
    {
      slotsAcc := Str:Obj[:]
      slotsAcc.ordered = true
      slots.each |slot|
      {
        noRecurse := slot.base?.type === slot.base && !slot.isType
        slotsAcc[slot.name] = genAstSpec(env, slot, isOwn || noRecurse, opts)
      }
      acc["slots"] = env.dictMap(slotsAcc)
    }

    return env.dictMap(acc)
  }

  private static Obj genAstVal(XetoEnv env, Obj val)
  {
    if (val is Spec) return val.toStr
    if (val is List)
    {
      return ((List)val).map |x| { genAstVal(env, x) }
    }
    if (val is Dict)
    {
      dict := (Dict)val
      if (dict.isEmpty) return dict
      acc := Str:Obj[:]
      acc.ordered = true
      isList := true // TODO
      ((Dict)val).each |v, n|
      {
        if (!XetoUtil.isAutoName(n)) isList = false
        acc[n] = genAstVal(env, v)
      }
      if (isList) return acc.vals // TODO: should already be a list!
      return env.dictMap(acc)
    }
    return val.toStr
  }
}

