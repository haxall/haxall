//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack::Dict

**
** Generate DocPage for each entry
**
internal class GenPages: Step
{
  override Void run()
  {
    eachPage |PageEntry entry|
    {
      entry.pageRef = genPage(entry)
    }
  }

  DocPage genPage(PageEntry entry)
  {
    switch (entry.pageType)
    {
      case DocPageType.lib:      return genLib(entry, entry.def)
      case DocPageType.type:     return genType(entry, entry.def)
      case DocPageType.global:   return genGlobal(entry, entry.def)
      case DocPageType.instance: return genInstance(entry, entry.def)
      default: throw Err(entry.pageType.name)
    }
  }

  DocLib genLib(PageEntry entry, Lib x)
  {
    DocLib
    {
      it.name      = x.name
      it.doc       = genDoc(x.meta["doc"])
      it.meta      = genDict(x.meta)
      it.types     = summaries(typesToDoc(x))
      it.globals   = summaries(x.globals)
      it.instances = summaries(x.instances)
    }
  }

  DocType genType(PageEntry entry, Spec x)
  {
    doc        := genSpecDoc(x)
    meta       := genDict(x.meta)
    base       := x.isCompound ? genTypeRef(x) : genTypeRef(x.base)
    slots      := genSlots(x)
    supertypes := genSupertypes(x)
    subtypes   := genSubtypes(x)
    return DocType(x.qname, doc, meta, base, supertypes, subtypes, slots)
  }

  DocTypeGraph genSupertypes(Spec x)
  {
    acc := Str:Int[:]
    acc.ordered = true
    doGenSupertypes(acc, x)
    types := acc.keys.map |qname->DocTypeRef| { DocSimpleTypeRef(qname) }

    edges := Int[][,]
    acc.each |index, qname|
    {
      edges.add(toSupertypeBaseIndex(acc, ns.spec(qname)))
    }
    return DocTypeGraph(types, edges)
  }

  Int[] toSupertypeBaseIndex(Str:Int qnameToIndex, Spec spec)
  {
    if (spec.base == null) return Int#.emptyList
    if (!spec.isCompound) return [qnameToIndex.getChecked(spec.base.qname)]
    return spec.ofs.map |x->Int| { qnameToIndex.getChecked(x.qname) }
  }

  Void doGenSupertypes(Str:Int acc, Spec? x)
  {
    if (x == null || acc[x.qname] != null) return
    acc[x.qname] = acc.size
    if (!x.isCompound)
    {
      doGenSupertypes(acc, x.base)
    }
    else
    {
      x.ofs.each |sup|
      {
        doGenSupertypes(acc, sup)
      }
    }
  }

  DocTypeGraph genSubtypes(Spec x)
  {
    acc := typesToDoc(x.lib).findAll |t|
    {
      if (t.isCompound)
        return t.ofs.any { it === x }
      else
        return t.base === x
    }
    if (acc.isEmpty) return DocTypeGraph.empty
    types := acc.map |s| { DocSimpleTypeRef(s.qname) }
    return DocTypeGraph(types, null)
  }

  DocGlobal genGlobal(PageEntry entry, Spec x)
  {
    doc := genSpecDoc(x)
    meta  := genDict(x.meta)
    type := genTypeRef(x.type)
    return DocGlobal(x.qname, doc, meta, type)
  }

  DocInstance genInstance(PageEntry entry, Dict x)
  {
    qname    := x.id.id
    instance := genDict(x)
    return DocInstance(qname, instance)
  }

  Str:DocSlot genSlots(Spec type)
  {
    slots := type.slots
    if (slots.isEmpty) return DocSlot.empty
    acc := Str:DocSlot[:]
    acc.ordered = true
    slots.each |slot|
    {
      d := genSlot(type, slot)
      acc[d.name] = d
    }
    return acc
  }

  DocSlot genSlot(Spec parentType, Spec slot)
  {
    doc     := genSpecDoc(slot)
    meta    := genDict(slot.metaOwn)
    typeRef := genTypeRef(slot)
    parent  := slot.parent === parentType ? null : DocSimpleTypeRef(slot.parent.qname)
    return DocSlot(slot.name, doc, meta, typeRef, parent)
  }

  DocTypeRef? genTypeRef(Spec? x)
  {
    if (x == null) return null
    if (x.isCompound)
    {
      if (x.isAnd) return DocAndTypeRef(genTypeRefOfs(x), x.isMaybe)
      if (x.isOr)  return DocOrTypeRef(genTypeRefOfs(x), x.isMaybe)
    }
    baseType := XetoUtil.isAutoName(x.name) ? x.base : x.type
    base := DocSimpleTypeRef(baseType.qname, x.isMaybe)
    of := x.of(false)
    if (of != null)
    {
      return DocOfTypeRef(base, genTypeRef(of))
    }
    return base
  }

  DocTypeRef[] genTypeRefOfs(Spec x)
  {
    x.ofs.map |of->DocTypeRef| { genTypeRef(of) }
  }

  DocDict genDict(Dict d)
  {
    // we type everything as sys::Dict for now
    spec := d.get("spec") as Ref
    type := spec == null ? DocTypeRef.dict : DocSimpleTypeRef(spec.id.toStr)
    acc := Str:Obj[:]
    d.each |v, n|
    {
      if (n == "doc") return // handled by DocBlock
      acc[n] = genVal(v)
    }
    return DocDict(type, acc)
  }

  DocVal genVal(Obj x)
  {
    if (x is Dict) return genDict(x)
    if (x is List) return genList(x)
    return genScalar(x)
  }

  DocList genList(Obj[] x)
  {
    DocList(DocTypeRef.list, x.map |item| { genVal(item) })
  }

  DocScalar genScalar(Obj x)
  {
    type := DocSimpleTypeRef(ns.specOf(x).qname)
    return DocScalar(type, x.toStr)
  }

  DocBlock genSpecDoc(Spec x)
  {
    genDoc(x.meta["doc"])
  }

  DocBlock genDoc(Obj? doc)
  {
    str := doc as Str ?: ""
    if (str.isEmpty) return DocBlock.empty
    return DocBlock(str)
  }
}

