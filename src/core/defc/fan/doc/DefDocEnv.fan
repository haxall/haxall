//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Jun 2018  Brian Frank  Creation
//

using concurrent
using compilerDoc
using fandoc::HtmlDocWriter
using web
using haystack

**
** DefDocEnv is the defc implementatin of DocEnv
**
const class DefDocEnv : DocEnv
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(DefDocEnvInit init)
  {
    this.ns        = init.ns
    this.spacesMap = init.spacesMap
    this.defsMap   = init.defsMap
    this.ts        = DateTime.now
    this.libs      = spacesMap.vals.findAll |s| { s is DocLib }.sort
    this.libsMap   = Str:DocLib[:].addList(libs) { it.name }
    this.dataLibs  = spacesMap.vals.findAll |s| { s is DocDataLib }.sort
  }

//////////////////////////////////////////////////////////////////////////
// Lookup
//////////////////////////////////////////////////////////////////////////

  ** Underlying namespace of defs
  const Namespace ns

  ** Timestamp when docs generated
  const DateTime ts

  ** Top index with our custom index renderer
  override DocTopIndex topIndex() { DocTopIndex { it.renderer = DefTopIndexRenderer# } }

  ** Lookup a space by name
  override DocSpace? space(Str name, Bool checked := true)
  {
    space := spacesMap[name]
    if (space != null) return space
    if (checked) throw UnknownDocErr("space not found: $name")
    return null
  }
  const Str:DocSpace spacesMap

  ** Lookup manual space by name
  DocPod? manual(Str name, Bool checked := true)
  {
    x := space(name, false) as DocPod
    if (x != null && x.isManual) return x
    if (checked) throw UnknownDocErr("manual not found: $name")
    return null
  }

  ** Lib spaces
  const DocLib[] libs

  ** Lookup a library by name
  DocLib? lib(Str name, Bool checked := true)
  {
    lib := libsMap[name]
    if (lib != null) return lib
    if (checked) throw Err("Unknown lib: $name")
    return null
  }
  const Str:DocLib libsMap

  ** Lookup a def document by name
  DocDef? def(Str symbol, Bool checked := true)
  {
    def := defsMap[symbol]
    if (def != null) return def
    if (checked) throw Err("Unknown def: $symbol")
    return null
  }
  const Str:DocDef defsMap

  ** Find all the def docs that match given predicate
  DocDef[] findDefs(|DocDef->Bool| f)
  {
    acc := DocDef[,]
    defsMap.each |d| { if (f(d)) acc.add(d) }
    return acc.sort
  }

  ** Data spec libs
  const DocDataLib[] dataLibs

  ** Resolve Def to its DocDef, return null if def is undocumented
  DocDef? resolve(Def d)
  {
    def(d.symbol.toStr, false)
  }

  ** Resolve Def list to list of DocDef, silently ignore undocumented defs
  DocDef[] resolveList(Def[] list, Bool sort)
  {
    if (list.isEmpty) return DocDef#.emptyList
    acc := DocDef[,]
    acc.capacity = list.size
    list.each |d|
    {
      doc := resolve(d)
      if (doc != null) acc.add(doc)
    }
    if (sort) acc.sort
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Theme/Renderering
//////////////////////////////////////////////////////////////////////////

  ** Theme
  override DocTheme theme() { DefDocTheme() }

  ** Rendering in this framework requires DocOutStream
  override Void render(WebOutStream out, Doc doc)
  {
    o := (DocOutStream)out
    o.env = this
    o.doc = doc
    o.renderer = renderer(doc).make([this, out, doc])
    o.renderer.writeDoc
  }

  ** Hook to customize the renderer for the given document
  virtual Type renderer(Doc doc)
  {
    if (doc is DocChapter) return DefChapterRenderer#
    if (doc is DocPodIndex) return DefPodIndexRenderer#
    return doc.renderer
  }

  ** Hook to use our own HtmlDocWriter subclass
  override HtmlDocWriter initFandocHtmlWriter(OutStream out)
  {
    DocFandocWriter(out)
  }

//////////////////////////////////////////////////////////////////////////
// Customization Hooks
//////////////////////////////////////////////////////////////////////////

  ** Generate full html envelope or only content div
  virtual Bool genFullHtml() { true }

  ** Filename to use the CSS include
  virtual Str cssFilename() { "style.css" }

  ** Documentation web site title
  virtual Str siteDis() { "Project Haystack" }

  ** Footer for documentation pages to indicate version/timestamp
  virtual Str footer() { "Generated " + ts.toLocale("DD-MMM-YYYY hh:mm zzz") }

  ** Return if the given def tag should be shown in the meta data
  virtual Bool includeTagInMetaSection(Def base, DocDef tag) { true }

//////////////////////////////////////////////////////////////////////////
// Supertypes
//////////////////////////////////////////////////////////////////////////

  ** Return all supertypes
  DocDef[] supertypes(DocDef def)
  {
    resolveList(ns.supertypes(def.def), false)
  }

  ** Supertypes organized into indent tree
  DocDefTree supertypeTree(DocDef def)
  {
    root := DocDefTree(null, def)
    doSupertypeTree(root)
    return root.invert
  }

  private Void doSupertypeTree(DocDefTree node)
  {
    supertypes(node.def).each |s| { doSupertypeTree(node.add(s))  }
  }

//////////////////////////////////////////////////////////////////////////
// Subtypes
//////////////////////////////////////////////////////////////////////////

  ** Return all subtypes
  DocDef[] subtypes(DocDef def)
  {
    if (!def.type.isTerm) return DocDef#.emptyList
    return resolveList(ns.subtypes(def.def), false)
  }

  ** Direct or indirect subtypes organized into indent tree
  DocDefTree subtypeTree(DocDef def)
  {
    root := DocDefTree(null, def)
    doSubtypeTree(root)
    return root
  }

  private Void doSubtypeTree(DocDefTree node)
  {
    subtypes := subtypes(node.def)
    if (subtypes.isEmpty) return
    subtypes.each |s| { doSubtypeTree(node.add(s)) }
  }

//////////////////////////////////////////////////////////////////////////
// Associations
//////////////////////////////////////////////////////////////////////////

  ** List all all associations to generate a documentation section.
  ** These are marked with 'docAssociation' such as tags, quantities.
  DocDef[] docAssociations()
  {
    // cache this since is expensive and used on every page
    if (docSectionsRef.val == null)
    {
      acc := findDefs |def| { def.has("docAssociations") }
      acc.moveTo(def("tags"), 0)
      docSectionsRef.val = acc.toImmutable
    }
    return docSectionsRef.val
  }
  private const AtomicRef docSectionsRef := AtomicRef()

  ** List all tags marked as 'docSection' such as tags, quantities.
  DocDef[] associations(DocDef parent, DocDef association)
  {
    resolveList(ns.associations(parent.def, association.def), true)
  }

//////////////////////////////////////////////////////////////////////////
// Linking
//////////////////////////////////////////////////////////////////////////

  **
  ** Extended link shortcuts
  **  - `equip` => lib-phIoT/equip
  **  - `tz`    => lib-ph/tz  (tags trump funcs)
  **  - `tz()`  => lib-core/func~tz  (force func to trump tags)
  **
  override DocLink? link(Doc from, Str link, Bool checked := true)
  {
    // check for slot in current Type (before defs)
    if (from is DocType)
    {
      slot := ((DocType)from).slot(link, false)
      if (slot != null) return DocLink(from, from, link, link)
    }

    // try as def
    def := def(link, false)
    if (def != null) return DocLink(from, def, link)

    // map lib::foo to lib index page
    if (link.startsWith("lib:"))
    {
      libName := link[4..-1]
      lib := libsMap[libName]
      if (lib != null) return DocLink(from, lib.index, link)
    }

    // handle case when compiling core ph libs without docHaystack
    if (link.startsWith("docHaystack::") && space("docHaystack", false) == null)
      return DocLink.makeAbsUri(from, `https://project-haystack.dev/doc/` + link.replace("::", "/").toUri, "online")

    // try compilerDoc syntax
    return super.link(from, link, checked)
  }

  ** Resolve a section title/id to an explanation
  virtual Uri? linkSectionTitle(Doc from, Str title)
  {
    if (title.isEmpty) return null

    switch (title)
    {
      case "manual":   title = "manuals"
      case "chapters": title = "manuals"
      case "lib":      title = "def"
    }

    chapter := manual("docHaystack", false)?.chapter("Docs", false)
    if (chapter != null && chapter.heading(title, false) != null)
      return linkUri(DocLink(from, chapter, title, title))

    return null
  }

  **
  ** Check embedded image link in a document.  If it maps to a resource file
  ** we should include, then return the file.  Otherwise raise warning exception.
  **
  virtual DocResFile? imageLink(Doc from, Str link, DocLoc loc)
  {
    pod := from.space as DocPod
    if (pod != null)
    {
      // support standard pattern where images are located in pod doc/ dir
      res := pod.res(link, false)
      if (res != null)
      {
        file := Pod.find(pod.name).file(`/doc/$link`)
        return DocResFile(from.space.spaceName, link, file)
      }
    }
    throw DocErr("Unresolved image link: $link", loc)
  }

  **
  ** Iterate chapter toc links
  **
  Void walkChapterToc(Doc from, Doc target, |DocHeading,Uri| f)
  {
    chapter := target is DocLibManual ? ((DocLibManual)target).chapter : (DocChapter)target
    chapter.headings.each |h, i|
    {
      doWalkChapterToc(from, target, h, true, f)
    }
    return this
  }

  **
  ** Iterate only top-level chapter toc links
  **
  Void walkChapterTocTopOnly(Doc from, Doc target, |DocHeading,Uri| f)
  {
    chapter := target is DocLibManual ? ((DocLibManual)target).chapter : (DocChapter)target
    chapter.headings.each |h, i|
    {
      doWalkChapterToc(from, target, h, false, f)
    }
    return this
  }

  private Void doWalkChapterToc(Doc from, Doc target, DocHeading h, Bool walkKids, |DocHeading,Uri| f)
  {
    uri := from === target ? `#$h.anchorId` : linkUri(DocLink(from, target, h.title, h.anchorId))
    f(h, uri)
    if (walkKids)
      h.children.each |kid| { doWalkChapterToc(from, target, kid, walkKids, f) }
  }

}

**************************************************************************
** DefDocEnvInit
**************************************************************************

class DefDocEnvInit
{
  new make(|This| f) { f(this) }
  Namespace ns
  Str:DocSpace spacesMap
  Str:DocDef defsMap
}