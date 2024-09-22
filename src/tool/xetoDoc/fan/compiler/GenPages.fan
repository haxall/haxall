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
      case DocPageType.lib:  return genLib(entry, entry.def)
      case DocPageType.type: return genSpec(entry, entry.def)
      default: throw Err(entry.pageType.name)
    }
  }

  DocLib genLib(PageEntry entry, Lib x)
  {
    DocLib
    {
      it.uri   = entry.uri
      it.name  = x.name
      it.types = DocSummary[,]
    }
  }

  DocSpec genSpec(PageEntry entry, Spec x)
  {
    DocSpec
    {
      it.uri      = entry.uri
      it.pageType = entry.pageType
      it.qname    = x.qname
      it.libName  = x.lib.name
      it.name     = x.name
    }
  }
}

