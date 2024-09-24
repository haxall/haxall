//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Nov 2023  Brian Frank  Creation
//   21 May 2024  Brian Frank  Port into xetoEnv
//

using xeto
using haystack::Dict
using haystack::Ref
using haystack

**
** CompUtil
**
@Js
class CompUtil
{

  ** Return if name is a slot that cannot be directly changed in an Comp
  static Bool isReservedSlot(Str name)
  {
    name == "id" || name == "spec"
  }

  ** Convert slot to fantom handler method or null
  static Method? toHandlerMethod(Comp c, Spec slot)
  {
    c.typeof.method(toHandlerMethodName(slot.name), false)
  }

  ** Convert component slot "name" to Fantom method implementation "onName"
  static Str toHandlerMethodName(Str name)
  {
    StrBuf(name.size + 1)
      .add("on")
      .addChar(name[0].upper)
      .addRange(name, 1..-1)
      .toStr
  }

  ** Encode a component into a sys.comp::Comp dict representation (with children)
  static Dict compSave(Comp comp)
  {
    acc := Str:Obj[:]
    spec := comp.spec
    links := comp.links
    comp.each |v, n|
    {
      // must have spec tag
      if (n == "spec") { acc[n] = v; return }

      // skip transients
      slot := spec.slot(n, false)
      if (slot != null && slot.meta.has("transient")) return

      // skip default scalar values if not maybe
      if (slot != null && !slot.isMaybe && v == slot.meta["val"]) return

      // skip linked slots
      if (links.isLinked(n)) return

      // recurse component sub-tree
      if (v is Comp) v = compSave(v)

      // save this name/value pair
      acc[n] = v
    }
    return Etc.dictFromMap(acc)
  }

  ** Encode a component into a sys.comp::Comp dict representation (no children)
  static Dict compToDict(Comp comp)
  {
    acc := Str:Obj[:]
    comp.each |v, n|
    {
      if (v is Comp) return

      // non-Haystack typed scalars encode to Str
      kind := Kind.fromVal(v, false)
      if (kind == null) v = v.toStr

      acc[n] = v
    }
    return Etc.dictFromMap(acc)
  }

  ** Encode a component into a sys.comp::Comp dict representation, then brio
  static Buf compToBrio(Comp comp)
  {
    dictToBrio(compToDict(comp))
  }

  ** Dict to brio buf
  static Buf dictToBrio(Dict dict)
  {
    buf := Buf()
    BrioWriter(buf.out).writeDict(dict)
    return buf.toImmutable
  }

  ** Return grid format used for BlockView feed protocol
  static Grid toFeedGrid(Dict gridMeta, Str cookie, Dict[] dicts, [Ref:Ref]? deleted)
  {
    gb := GridBuilder()
    gb.capacity = dicts.size + (deleted == null ? 0 : deleted.size)
    if (gridMeta.isEmpty) gb.setMeta(Etc.dict1("cookie", cookie))
    else gb.setMeta(Etc.dictSet(gridMeta, "cookie", cookie))
    gb.addCol("id").addCol("comp")
    dicts.each |dict|
    {
      gb.addRow2(dict.id, CompUtil.dictToBrio(dict))
    }
    if (deleted != null)
    {
      deleted.each |id| { gb.addRow2(id, null) }
    }
    return gb.toGrid
  }

}

