//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack
using folio
using hx
using hx4
using xetoc

**
** Namespace implementation
**
const class ProjNamespace : LocalNamespace, Namespace
{
  internal new make(LocalNamespaceInit init, Log log) : super(init)
  {
    this.log = log
    this.projLib = lib("proj")
  }

  const Log log

  override const Lib projLib

  once NamespaceExts exts()
  {
    ext := spec("hx::Ext")
    acc := Str:ExtDef[:]
    libs.each |lib|
    {
      lib.specs.each |spec|
      {
        if (spec.isa(ext) && spec.meta.missing("abstract"))
        {
          if (!spec.name.endsWith("Ext"))
            return log.err("Ext name must end with Ext: $spec")
          else
            acc[spec.qname] = MExtDef(spec)
        }
      }
    }
    return MExtDefs(acc)
  }
}

