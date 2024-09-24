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
      it.uri       = entry.uri
      it.name      = x.name
      it.doc       = genDoc(x.meta["doc"])
      it.types     = summaries(x.types)
      it.globals   = summaries(x.globals)
      it.instances = summaries(x.instances)
    }
  }

  DocType genType(PageEntry entry, Spec x)
  {
    doc   := genSpecDoc(x)
    base  := x.isCompound ? genTypeRef(x) : genTypeRef(x.base)
    slots := genSlots(x)
    return DocType(entry.uri, x.qname, doc, base, slots)
  }

  DocGlobal genGlobal(PageEntry entry, Spec x)
  {
    doc := genSpecDoc(x)
    type := genTypeRef(x.type)
    return DocGlobal(entry.uri, x.qname, doc, type)
  }

  DocInstance genInstance(PageEntry entry, Dict x)
  {
    DocInstance
    {
      it.uri   = entry.uri
      it.qname = x.id.id
    }
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

  DocSlot genSlot(Spec type, Spec slot)
  {
    parent := slot.parent === type ? null : DocSimpleTypeRef(slot.parent.qname)
    return DocSlot(slot.name, genSpecDoc(slot), genTypeRef(slot.type), parent)
  }

  DocTypeRef? genTypeRef(Spec? x)
  {
    if (x == null) return null
    if (x.isAnd) return DocAndTypeRef(genTypeRefOfs(x))
    if (x.isOr)  return DocOrTypeRef(genTypeRefOfs(x))
    return DocSimpleTypeRef(x.qname)
  }

  DocTypeRef[] genTypeRefOfs(Spec x)
  {
    x.ofs.map |of->DocTypeRef| { genTypeRef(of) }
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

