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
internal const class XetoUtil
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
  static Bool isa(XetoSpec a, XetoSpec b, Bool isTop)
  {
    // check if a and b are the same
    if (a === b) return true

    // if A is "maybe" type, then it also matches None
    if (b.isNone && a.isMaybe && isTop) return true

    // if A is sys::And type, then check any of A.ofs is B
    if (isAnd(a))
    {
      ofs := ofs(a, false)
      if (ofs != null && ofs.any |x| { x.isa(b) }) return true
    }

    // if A is sys::Or type, then check all of A.ofs is B
    if (isOr(a))
    {
      ofs := ofs(a, false)
      if (ofs != null && ofs.all |x| { x.isa(b) }) return true
    }

    // if B is sys::Or type, then check if A is any of B.ofs
    if (isOr(b))
    {
      ofs := ofs(b, false)
      if (ofs != null && ofs.any |x| { a.isa(x) }) return true
    }

    // check a's base type
    if (a.base != null) return isa(a.base, b, false)

    return false
  }

  static Bool isNone(XetoSpec x)  { x === x.m.env.sys.none }

  static Bool isAnd(XetoSpec x) { x.base === x.m.env.sys.and }

  static Bool isOr(XetoSpec x) { x.base === x.m.env.sys.or  }

  static Bool isCompound(XetoSpec x) { (isAnd(x) || isOr(x)) && ofs(x, false) != null }

  static Spec[]? ofs(XetoSpec x, Bool checked)
  {
    val := x.m.metaOwn.get("ofs", null) as Spec[]
    if (val != null) return val
    if (checked) throw UnknownNameErr("Missing 'ofs' meta: $x.qname")
    return null
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
    m := MDerivedSpec(env, name, base, meta, deriveSlots(env, spec, slots), deriveFlags(base, meta))
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
      XetoSpec(MSpec(FileLoc.synthetic, parent, name, base, base.type, base.m.meta, env.dict0, MSlots.empty, MSlots.empty, base.m.flags))
    }

    return MSlots(derivedMap)
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
    if (spec.isScalar) return meta["val"] ?: ""
    if (spec === env.sys.dict) return env.dict0
    if (spec.isList) return env.list0

    isGraph := opts.has("graph")

    acc := Str:Obj[:]
    acc.ordered = true

    if (isGraph) acc["id"] = Ref.gen
    acc["dis"] = spec.name

    spec.slots.each |slot|
    {
      if (slot.isMaybe) return
      if (slot.isQuery) return
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


  **
  ** Generate AST dict tree
  **
  static Dict genAst(XetoEnv env, Spec spec, Bool isOwn, Dict opts)
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
        slotsAcc[slot.name] = genAst(env, slot, isOwn || noRecurse, opts)
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

