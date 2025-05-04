//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Sep 2024  Brian Frank  Creation
//

using xeto
using xetoEnv
using haystack::Ref

**
** Documentation utilities
**
@Js
const class DocUtil
{

//////////////////////////////////////////////////////////////////////////
// Uris
//////////////////////////////////////////////////////////////////////////

  ** Convert normalized doc URI to Ref
  static Ref uriToRef(Uri uri)
  {
    // search::{base64}
    if (uri.path.getSafe(0) == "search")
    {
      q := uri.query["q"] ?: ""
      if (q.isEmpty) return Ref("search")
      return Ref("search::" + q.toBuf.toBase64Uri)
    }

    str := uri.toStr[1..-1]
    if (uri.frag != null) str = str[0..<str.index("#")]
    str = str.replace("/", "::")

    return Ref(str)
  }

  ** Convert Ref to normalized doc URI
  static Uri refToUri(Ref id)
  {
    s := StrBuf().add("/")
    str := id.id
    colons := str.index("::")
    if (colons == null)
    {
      s.add(str)
    }
    else
    {
      libName := str[0..<colons]
      docName := str[colons+2..-1]
      if (libName == "search")
        s.add(libName).add("?q=").add(Buf.fromBase64(docName).readAllStr)
      else
        s.add(libName).add("/").add(docName)
    }
    return s.toStr.toUri
  }

  ** Top level index page
  static Uri indexUri()
  {
    `/index`
  }

  ** Search uri
  static Uri searchUri(Str pattern)
  {
    "/search?q=".plus(Uri.escapeToken(pattern, Uri.sectionQuery)).toUri
  }

  ** Lib name to the library index page
  static Uri libToUri(Str libName)
  {
    "/${libName}/index".toUri
  }

  ** Convert spec name to its normalized URI
  static Uri specToUri(Spec spec)
  {
    spec.isGlobal ? globalToUri(spec.qname) : typeToUri(spec.qname)
  }

  ** Convert type spec qualified name to its normalized URI
  static Uri typeToUri(Str qname)
  {
    qnameToUri(qname, false)
  }

  ** Convert global spec qualified name to its normalized URI
  static Uri globalToUri(Str qname)
  {
    qnameToUri(qname, true)
  }

  ** Convert instance qualified name to its normalized URI
  static Uri instanceToUri(Str qname)
  {
    qnameToUri(qname, false)
  }

  ** Convert chaoter qualified name to its normalized URI
  static Uri chapterToUri(Str qname)
  {
    qnameToUri(qname, false)
  }

  ** Convert normalized URI back to qname or null if not a spec/instance
  static Str? qnameFromUri(Uri uri)
  {
    if (uri.path.size != 2) return null
    l := uri.path[0]
    n := uri.path[1]
    if (n.size >= 2 && n.startsWith("_") && !n[1].isDigit) n = n[1..-1]
    return "$l::$n"
  }

  ** Convert spec or instance qualified name to its normalized URI
  private static Uri qnameToUri(Str qname, Bool isGlobal)
  {
    // have to deal with lower vs upper case names on file systems
    colons := qname.index("::") ?: throw Err("Not qname: $qname")
    s := StrBuf(qname.size + 3)
    return s.addChar('/')
            .addRange(qname, 0..<colons)
            .addChar('/')
            .add(isGlobal ? "_" : "")
            .addRange(qname, colons+2..-1)
            .toStr.toUri
  }

//////////////////////////////////////////////////////////////////////////
// Tags support
//////////////////////////////////////////////////////////////////////////

  ** Generate tags for given library
  static DocTag[] genTags(LibNamespace ns, Lib lib)
  {
    acc := DocTag[,]

    // categories
    cats := lib.meta["categories"] as List
    if (cats != null) cats.each |n| { acc.add(DocTag.intern(n.toStr)) }

    // specific types rollups
    comp  := ns.spec("sys.comp::Comp", false); comps := 0
    equip := ns.spec("ph::Equip", false); equips := 0
    point := ns.spec("ph::Point", false); points := 0
    lib.types.each |t|
    {
      if (comp  != null && t.isa(comp))  comps++
      if (equip != null && t.isa(equip)) equips++
      if (point != null && t.isa(point)) points++
    }
    if (comps  > 0) acc.add(DocTag("comps",  comps))
    if (equips > 0) acc.add(DocTag("equips", equips))
    if (points > 0) acc.add(DocTag("points", points))

    // overall defs
    if (lib.specs.size     > 0) acc.add(DocTag("specs",     lib.specs.size))
    if (lib.globals.size   > 0) acc.add(DocTag("globals",   lib.globals.size))
    if (lib.metaSpecs.size > 0) acc.add(DocTag("metas",     lib.metaSpecs.size))
    if (lib.instances.size > 0) acc.add(DocTag("instances", lib.instances.size))

    // chapters
    numChapters := libNumChapters(lib)
    if (numChapters > 0) acc.add(DocTag("chapters", numChapters))

    return acc
  }

  static Int libNumChapters(Lib lib)
  {
    count := 0
    libEachMarkdownFile(lib) |uri, special| { if (special == null) count++ }
    return count
  }

  static Void libEachMarkdownFile(Lib lib, |Uri uri, Str? special| f)
  {
    lib.files.list.each |uri|
    {
      if (uri.ext != "md") return
      n := uri.name.lower
      if (n == "index.md") f(uri, "index")
      else if (n == "readme.md") f(uri, "readme")
      else f(uri, null)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Standard icon refs
//////////////////////////////////////////////////////////////////////////

  static Ref tagToIcon(Str name)
  {
    switch (name)
    {
      case "specs":     return typeIcon
      case "globals":   return globalIcon
      case "metas":     return globalIcon
      case "instances": return instanceIcon
      case "chapters":  return chapterIcon
      case "sys":       return sysIcon
      case "comps" :    return compIcon
      case "equips":    return equipIcon
      case "points":    return pointIcon
      case "elec":      return elecIcon
      default:          return tagIcon
    }
  }

  static const Ref indexIcon    := Ref("ion.icons::list")
  static const Ref libIcon      := Ref("ion.icons::package")
  static const Ref typeIcon     := Ref("ion.icons::aperture")
  static const Ref globalIcon   := Ref("ion.icons::tag")
  static const Ref instanceIcon := Ref("ion.icons::at-sign")
  static const Ref chapterIcon  := Ref("ion.icons::sticky-note")
  static const Ref compIcon     := Ref("ion.icons::component")
  static const Ref equipIcon    := Ref("ion.icons::hard-drive")
  static const Ref pointIcon    := Ref("ion.icons::circle-dot")
  static const Ref sysIcon      := Ref("ion.icons::power")
  static const Ref elecIcon     := Ref("ion.icons::zap")
  static const Ref tagIcon      := Ref("ion.icons::tag")
}

