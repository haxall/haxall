//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Feb 2023  Brian Frank  Creation
//

using util
using data
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
  static |DataLogRec|? optLog(DataDict? opts, Str name)
  {
    if (opts == null) return null
    x := opts.get(name, null)
    if (x == null) return null
    if (x is Unsafe) x = ((Unsafe)x).val
    if (x is Func) return x
    throw Err("Expecting |DataLogRec| func for $name.toCode [$x.typeof]")
  }

//////////////////////////////////////////////////////////////////////////
// Inherit Meta
//////////////////////////////////////////////////////////////////////////

  ** Inherit spec meta data
  static DataDict inheritMeta(MSpec spec)
  {
    env := spec.env
    own := spec.own

    base := spec.base as XetoSpec
    if (base == null) return own

    // walk thru base tags and map tags we inherit
    acc := Str:Obj[:]
    baseSize := 0
    base.m.meta.each |v, n|
    {
      baseSize++
      if (isMetaInherited(n)) acc[n] = v
    }

    // if we inherited all of the base tags and
    // I have none of my own, then reuse base meta
    if (acc.size == baseSize && own.isEmpty)
      return base.m.meta

    // merge in my own tags
    if (!own.isEmpty)
    {
      own.each |v, n|
      {
        if (v === env.none && spec !== env.sys.none.m)
          acc.remove(n)
        else
          acc[n] = v
      }
    }

    return spec.env.dictMap(acc)
  }

  static Bool isMetaInherited(Str name)
  {
    // we need to make this use reflection at some point
    if (name == "abstract") return false
    if (name == "sealed") return false
    return true
  }

//////////////////////////////////////////////////////////////////////////
// Inherit Slots
//////////////////////////////////////////////////////////////////////////

  ** Inherit spec slots
  static MSlots inheritSlots(MSpec spec)
  {
    own := spec.slotsOwn
    base := spec.base

    if (base == null) return own
    if (spec.isLib) return own

    [Str:XetoSpec]? acc := null
    autoCount := 0
    if (base === spec.env.sys.and)
    {
      acc = Str:XetoSpec[:]
      acc.ordered = true

      ofs := spec.get("ofs", null) as DataSpec[]
      if (ofs != null) ofs.each |x|
      {
        x.slots.each |s|
        {
          // TODO: need to handle conflicts in compiler checks
          name := s.name
          if (XetoUtil.isAutoName(name)) name = "_" + (autoCount++)
          dup := acc[name]
          if (dup != null)
            acc[name] = overrideSlot(dup, s)
          else
            acc[name] = s
        }
      }
    }
    else
    {
      if (own.isEmpty) return base.slots

      // add supertype slots
      acc = Str:XetoSpec[:]
      acc.ordered = true
      base.slots.each |s|
      {
        name := s.name
        if (XetoUtil.isAutoName(name)) name = "_" + (autoCount++)
        acc[name] = s
      }
    }

    // add in my own slots
    own.each |s|
    {
      name := s.name
      if (XetoUtil.isAutoName(name)) name = "_" + (autoCount++)
      inherit := acc[name]
      if (inherit != null) s = overrideSlot(inherit, s)
      acc[name] = s
    }

    return MSlots(acc)
  }

  ** Merge inherited slot 'a' with override slot 'b'
  private static XetoSpec overrideSlot(XetoSpec a, XetoSpec b)
  {
    XetoSpec(MSpec(b.loc, b.parent, b.name, a, b.type, b.own, b.slotsOwn, b.m.flags))
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

  static DataSpec[]? ofs(XetoSpec x, Bool checked)
  {
    val := x.m.own.get("ofs", null) as DataSpec[]
    if (val != null) return val
    if (checked) throw UnknownNameErr("Missing 'ofs' meta: $x.qname")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Derive
//////////////////////////////////////////////////////////////////////////

  ** Dervice a new spec from the given base, meta, and map
  static DataSpec derive(XetoEnv env, Str name, XetoSpec base, DataDict meta, [Str:DataSpec]? slots)
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

  private static Int deriveFlags(XetoSpec base, DataDict meta)
  {
    flags := base.m.flags
    if (meta.has("maybe")) flags = flags.or(MSpecFlags.maybe)
    return flags
  }

  private static MSlots deriveSlots(XetoEnv env, XetoSpec parent, [Str:DataSpec]? slotsMap)
  {
    if (slotsMap == null || slotsMap.isEmpty) return MSlots.empty

    derivedMap := slotsMap.map |XetoSpec base, Str name->XetoSpec|
    {
      XetoSpec(MSpec(FileLoc.synthetic, parent, name, base, base.type, env.dict0, MSlots.empty, base.m.flags))
    }

    return MSlots(derivedMap)
  }

//////////////////////////////////////////////////////////////////////////
// Instantiate
//////////////////////////////////////////////////////////////////////////

  ** Instantiate default value of spec
  static Obj? instantiate(XetoEnv env, XetoSpec spec)
  {
    meta := spec.m.meta
    if (meta.has("abstract")) throw Err("Spec is abstract: $spec.qname")

    if (spec.isNone) return null
    if (spec.isScalar) return meta->val
    if (spec === env.sys.dict) return env.dict0
    if (spec.isList) return env.list0

    acc := Str:Obj[:]
    spec.slots.each |slot|
    {
      if (slot.isMaybe) return
      if (slot.isQuery) return
      acc[slot.name] = instantiate(env, slot)
    }
    return env.dictMap(acc)
  }

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////


  **
  ** Generate AST dict tree
  **
  static DataDict genAst(DataEnv env, DataSpec spec, Bool isOwn)
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

    DataDict meta := isOwn ? spec.own : spec
    meta.each |v, n|
    {
      if (n == "val" && v === env.marker) return
      acc[n] = genAstVal(env, v)
    }

    slots := isOwn ? spec.slotsOwn : spec.slots
    if (!slots.isEmpty)
    {
      slotsAcc := Str:Obj[:]
      slotsAcc.ordered = true
      slots.each |slot|
      {
        noRecurse := slot.base?.type === slot.base && !slot.isType
        slotsAcc[slot.name] = genAst(env, slot, isOwn || noRecurse)
      }
      acc["slots"] = env.dictMap(slotsAcc)
    }

    return env.dictMap(acc)
  }

  private static Obj genAstVal(DataEnv env, Obj val)
  {
    if (val is DataSpec) return val.toStr
    if (val is List)
    {
      return ((List)val).map |x| { genAstVal(env, x) }
    }
    if (val is DataDict)
    {
      dict := (DataDict)val
      if (dict.isEmpty) return dict
      acc := Str:Obj[:]
      acc.ordered = true
      isList := true // TODO
      ((DataDict)val).each |v, n|
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

