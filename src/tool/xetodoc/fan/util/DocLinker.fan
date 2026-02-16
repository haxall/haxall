//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jan 2026  Brian Frank  Creation
//

using markdown
using util
using xeto
using xetom

**
** DocLinker is use to resolve shortcut links against current location
**
const class DocLinker
{
  ** Constructor with given location
  new make(DocNamespace ns, Lib? lib, Obj? doc := null)
  {
    this.ns  = ns
    this.lib = lib
    this.doc = doc
    this.uri = DocUtil.linkerToUri(lib, doc)
  }

  ** Resolve destination against current location or null if unresolved
  DocLinkUri? resolve(Str x)
  {
    // handle absolute URIs
    if (x.startsWith("/") || x.contains("//")) return DocLinkUri(x.toUri)

    // parse into libName::docName.slotName#frag
    orig := x
    Str? libName  := null
    Str? docName  := x
    Str? slotName := null
    Str? frag     := null

    colons := x.index("::")
    if (colons != null)
    {
      libName = x[0..<colons]
      docName = x = x[colons+2..-1]
    }

    pound := x.indexr("#")
    if (pound != null)
    {
      frag    = x[pound+1..-1]
      docName = x = x[0..<pound]
    }

    dot := x.index(".")
    if (dot != null)
    {
      slotName = x[dot+1..-1]
      docName  = x = x[0..<dot]
    }

    // handle function()
    if (docName.endsWith("()"))
    {
      if (slotName != null || frag != null) return null
      name := docName[0..-3]
      Spec? func
      if (libName != null)
      {
        func = ns.lib(libName, false)?.spec("Funcs", false)?.slot(name, false)
      }
      else
      {
        func = ns.func(name)
      }
      if (func == null) return null
      return DocLinkUri(DocUtil.specToUri(func), func.name + "()")
    }

    // handle #frag within chapter
    if (docName.isEmpty && doc is DocNamespaceChapter && frag != null)
    {
      chapter := (DocNamespaceChapter)doc
      if (chapter.headings[frag] == null) return null
      return DocLinkUri(`#${frag}`, frag)
    }

    // lib is required for everything else - resolve libName or use scope
    Lib? lib
    if (libName == null)
    {
      lib = this.lib
      libName = lib?.name
    }
    else
    {
      lib = ns.lib(libName, false)
    }
    if (lib == null) return null

    // doc - index
    if (docName == "index")
    {
      if (slotName != null) return null
      if (frag != null) return null
      return DocLinkUri(DocUtil.libToUri(libName), libName)
    }

    // doc - spec
    spec := resolveSpec(lib, docName)
    if (spec != null)
    {
      dis := spec.name
      if (frag != null) return null
      if (slotName != null)
      {
        spec = spec.member(slotName, false)
        if (spec == null) return null
        dis = slotName
      }
      return DocLinkUri(DocUtil.specToUri(spec), dis)
    }

    // doc - instance
    inst := lib.instance(docName, false)
    if (inst != null)
    {
      if (slotName != null) return null
      if (frag != null) return null
      return DocLinkUri(DocUtil.toUri(libName, docName), docName)
    }

    // doc - chapter
    chapter := ns.chapters(lib).get(docName)
    if (chapter != null)
    {
      if (slotName != null && slotName != "md") return null
      if (frag != null && chapter.headings.get(frag) == null) return null
      dis := docName == "doc" ? libName : docName
      return DocLinkUri(DocUtil.toUri(libName, docName, frag), dis)
    }

    /* handle images (we don't call DocLinker for Image/Video nodes
    if (slotName == "svg" || slotName == "png" || slotName == "jpeg")
    {
      uri := lib.files.list.find |uri| { uri.path.size == 1 && uri.name == orig }
      if (uri != null) return DocLinkUri(orig.toUri, orig)
      }
    }
    */

    return null
  }

  ** Spec in library of one of it depends
  private Spec? resolveSpec(Lib lib, Str name)
  {
    // if in library itself then it always wins
    spec := lib.spec(name, false)
    if (spec != null) return spec

    // find all types in lib's depends (cannot use mixins)
    specs := Spec[,]
    ns.libs.each |x|
    {
      spec = x.type(name, false)
      if (spec == null) return
      if (XetoUtil.isInDepends(ns.ns, lib.name, spec.lib.name)) specs.add(spec)
    }
    if (specs.size > 1) throw Err("Ambiguous spec link: $specs")
    return specs.first
  }

  ** File location based on current lib/spec location
  FileLoc loc(FileLoc? markdownLoc)
  {
    // spec use location where spec is defined
    if (doc is Spec) return ((Spec)doc).loc

    // chapter use line within markdown
    if (doc is DocNamespaceChapter)
    {
      loc := ((DocNamespaceChapter)doc).loc
      if (markdownLoc != null) return FileLoc(loc.file, markdownLoc.line)
      return loc
    }

    if (lib != null) return lib.loc
    return FileLoc.unknown
  }

  const DocNamespace ns    // namespace and cached chapter headings
  const Uri uri            // current location uri
  const Lib? lib           // current lib scope
  const Obj? doc           // current doc scope (Spec or DocNamespaceChapter)
}

**************************************************************************
** DocLinkUri
**************************************************************************

** Result from DocLinker.resolve
const class DocLinkUri
{
  ** Constructor
  new make(Uri uri, Str dis := uri.toStr)
  {
    this.uri = uri
    this.dis = dis
  }

  ** Normalized uri for the link
  const Uri uri

  ** Base display text to use if shortcut was used
  const Str dis

  ** Debug string
  override Str toStr() { "[$dis]($uri)" }
}

