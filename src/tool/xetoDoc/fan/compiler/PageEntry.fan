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
using haystack::Etc
using haystack::Dict

**
** PageEntry is the working data for a DocPage
**
class PageEntry
{
  ** Constructor for top level index
  new makeIndex()
  {
    this.key      = "index"
    this.def      = "index"
    this.uri      = DocUtil.indexUri
    this.lib      = null
    this.dis      = "Doc Index"
    this.pageType = DocPageType.index
    this.meta     = Etc.dict0
    this.link     = DocLink(uri, dis)
  }

  ** Constructor for lib
  new makeLib(Lib x)
  {
    this.key      = DocCompiler.key(x)
    this.def      = x
    this.uri      = DocUtil.libToUri(x.name)
    this.lib      = x
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
    this.uri      = DocUtil.specToUri(x)
    this.lib      = x.lib
    this.dis      = x.name
    this.pageType = pageType
    this.meta     = x.meta
    this.link     = DocLink(uri, dis)
  }

  ** Constructor for instance
  new makeInstance(Lib lib, Dict x)
  {
    qname   := x.id.id
    libName := XetoUtil.qnameToLib(qname)
    name    := XetoUtil.qnameToName(qname)

    this.key      = DocCompiler.key(x)
    this.def      = x
    this.uri      = DocUtil.instanceToUri(qname)
    this.lib      = lib
    this.dis      = name
    this.pageType = DocPageType.instance
    this.meta     = x
    this.link     = DocLink(uri, dis)
  }

  ** Constructor for chapter
  new makeChapter(Lib lib, Uri file, Str markdown)
  {
    name  := file.basename
    qname := lib.name + "::" + name

    this.key      = qname
    this.lib      = lib
    this.def      = markdown
    this.uri      = DocUtil.chapterToUri(qname)
    this.dis      = name
    this.pageType = DocPageType.chapter
    this.meta     = Etc.dict0
    this.link     = DocLink(uri, dis)
  }

  ** Unique key for mapping libs, specs, instancs
  const Str key

  ** URI relative to base dir to page
  const Uri uri

  ** URI relative to base dir to page with ".json" extension
  Uri uriJson() { `${uri}.json` }

  ** If page is under a lib
  const Lib? lib

  ** Doc lib reference
  once DocLibRef? libRef() { lib == null ? null : DocLibRef(lib.name, lib.version) }

  ** Display name for this page
  const Str dis

  ** Page type
  const DocPageType pageType

  ** Link to this page
  const DocLink link

  ** If we want to add type into lib summary (globals)
  DocTypeRef? summaryType

  ** Meta for the page (lib meta, spec meta, instance itself)
  const Dict meta

  ** Definition as Lib, Spec, Dict instance, or chapter markdown Str
  const Obj def

  ** Get the summary
  DocSummary summary() { summaryRef ?: throw NotReadyErr(dis) }
  internal DocSummary? summaryRef

  ** Get the page
  DocPage page() { pageRef ?: throw NotReadyErr(dis) }
  internal DocPage? pageRef

  ** This is the index.md file for lib pages
  DocMarkdown? mdIndex

  ** Readme.md for lib pages
  DocMarkdown? readme

  ** Used for sorting chapters
  internal Int order

  ** Debug string
  override Str toStr() { "$uri.toCode $dis [$pageType]" }

}

