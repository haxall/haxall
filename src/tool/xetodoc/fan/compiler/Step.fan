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

  Namespace ns() { compiler.ns }

  Void info(Str msg) { compiler.info(msg) }

  XetoCompilerErr err(Str msg, FileLoc loc, Err? err := null) { compiler.err(msg, loc, err) }

  XetoCompilerErr err2(Str msg, FileLoc loc1, FileLoc loc2, Err? err := null) { compiler.err2(msg, loc1, loc2, err) }

  Void bombIfErr() { if (!compiler.errs.isEmpty) throw compiler.errs.first }

  Void eachPage(|DocPage| f) { compiler.pages.each(f) }

  Spec[] specsToDoc(Lib lib)
  {
    lib.specs.list.findAll |t| { !DocUtil.isSpecNoDoc(t) }
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

