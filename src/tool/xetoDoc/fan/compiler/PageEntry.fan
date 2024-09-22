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
** PageEntry is the working data for a DocPage
**
class PageEntry
{

  ** Constructor for lib
  new makeLib(Lib x)
  {
    this.key      = DocCompiler.key(x)
    this.def      = x
    this.uri      = `${x.name}/doc-index`
    this.dis      = x.name
    this.pageType = DocPageType.lib
    this.meta     = x.meta
    this.link     = DocLink(uri, dis)
  }

  ** Constructor for type/global
  new makeSpec(Spec x, DocPageType pageType)
  {
    this.key      = DocCompiler.key(x)
    this.def      = x
    this.uri      = `${x.lib.name}/${x.name}`
    this.dis      = x.name
    this.pageType = pageType
    this.meta     = x.meta
    this.link     = DocLink(uri, dis)
  }

  ** Constructor for instance
  new makeInstance(Dict x)
  {
    qname   := x.id.id
    libName := XetoUtil.qnameToLib(qname)
    name    := XetoUtil.qnameToName(qname)

    this.key      = DocCompiler.key(x)
    this.def      = x
    this.uri      = `${libName}/${name}`
    this.dis      = name
    this.pageType = DocPageType.instance
    this.meta     = x
    this.link     = DocLink(uri, dis)
  }

  ** Unique key for mapping libs, specs, instancs
  const Str key

  ** URI relative to base dir to page
  const Uri uri

  ** URI relative to base dir to page with ".json" extension
  Uri uriJson() { `${uri}.json` }

  ** Display name for this page
  const Str dis

  ** Page type
  const DocPageType pageType

  ** Link to this page
  const DocLink link

  ** Meta for the page (lib meta, spec meta, instance itself)
  const Dict meta

  ** Definition as Lib, Spec, or Dict instance
  const Obj def

  ** Get the summary
  DocSummary summary() { summaryRef ?: throw NotReadyErr(dis) }
  internal DocSummary? summaryRef

  ** Get the page
  DocPage page() { pageRef ?: throw NotReadyErr(dis) }
  internal DocPage? pageRef

  ** Debug string
  override Str toStr() { "$uri.toCode $dis [$pageType]" }

}

