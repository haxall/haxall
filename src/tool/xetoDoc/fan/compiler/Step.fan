//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Base class for DocCompiler steps
**
abstract internal class Step
{
  DocCompiler? compiler

  abstract Void run()

  LibNamespace ns() { compiler.ns }

  Void info(Str msg) { compiler.info(msg) }

  XetoCompilerErr err(Str msg, FileLoc loc, Err? err := null) { compiler.err(msg, loc, err) }

  XetoCompilerErr err2(Str msg, FileLoc loc1, FileLoc loc2, Err? err := null) { compiler.err2(msg, loc1, loc2, err) }

  Void bombIfErr() { if (!compiler.errs.isEmpty) throw compiler.errs.first }

  Void eachPage(|PageEntry| f)
  {
    compiler.entries.each(f)
  }

  Void eachLib(|PageEntry| f)
  {
    compiler.libEntries.each(f)
  }

  Spec[] specsToDoc(Lib lib)
  {
    lib.specs.findAll |t| { !XetoUtil.isAutoName(t.name) }
  }

  PageEntry[] chapters(Lib lib)
  {
    acc := PageEntry[,]
    compiler.entries.each |page|
    {
      if (page.pageType == DocPageType.chapter && page.lib == lib)
        acc.add(page)
    }
    return acc
  }

  PageEntry? chapter(Lib lib, Str name)
  {
    compiler.entries.find |page|
    {
      page.pageType == DocPageType.chapter && page.lib == lib  && page.uri.name == name
    }
  }

  DocSummary[] chapterSummaries(Lib lib)
  {
    list := chapters(lib)
    list.sort |a, b| { a.order <=> b.order }
    return list.map |x->DocSummary| { x.summary }
  }

  PageEntry entry(Obj x)
  {
    compiler.entry(x)
  }

  DocSummary summary(Obj x)
  {
    entry(x).summary
  }

  DocSummary[] summaries(Obj[] list)
  {
    list.map |x->DocSummary| { summary(x) }
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
}

