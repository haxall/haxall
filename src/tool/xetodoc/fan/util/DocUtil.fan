//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetom

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

  ** Convert normalized URI back to qname or null if not a spec/instance
  static Str? qnameFromUri(Uri uri)
  {
    if (uri.path.size != 2) return null
    l := uri.path[0]
    n := fromUriName(uri.path[1])
    return "$l::$n"
  }

  ** Convert spec or instance qualified name to its normalized URI
  internal static Uri specToUri(Spec spec)
  {
    Str? frag := null
    while (spec.parent != null)
    {
      frag = frag == null ? spec.name : spec.name + "." + frag
      spec = spec.parent
    }
    return qnameToUri(spec.qname, frag)
  }

  ** Convert slot path to URI
  internal static Uri slotToUri(Str qname, Str[] path)
  {
    qnameToUri(qname, path.join("."))
  }

  ** Convert linker scope to uri
  internal static Uri linkerToUri(Lib? lib, Obj? doc)
  {
    if (lib == null) return indexUri
    if (doc == null) return libToUri(lib.name)
    if (doc is Spec) return specToUri(doc)
    return toUri(lib.name, ((DocNamespaceChapter)doc).name)
  }

  ** Convert spec or instance qualified name to its normalized URI
  internal static Uri toUri(Str lib, Str name, Str? frag := null)
  {
    StrBuf(2+lib.size+name.size)
      .addChar('/')
      .add(lib)
      .addChar('/')
      .add(name)
      .joinNotNull(frag, "#")
      .toStr.toUri
  }

  ** Convert spec or instance qualified name to its normalized URI
  internal static Uri qnameToUri(Str qname, Str? frag := null)
  {
    // have to deal with lower vs upper case names on file systems
    colons := qname.index("::") ?: throw Err("Not qname: $qname")
    s := StrBuf(qname.size + 3)
    return s.addChar('/')
            .addRange(qname, 0..<colons)
            .addChar('/')
            .add(toUriName(qname[colons+2..-1]))
            .joinNotNull(frag, "#")
            .toStr.toUri
  }

  ** Swizzle spec/instance names that conflict with lib index
  static Str toUriName(Str n)
  {
    n.equalsIgnoreCase("index") ? "_$n" : n
  }

  ** Swizzle spec/instance names that conflict with lib index
  static Str fromUriName(Str n)
  {
    n.equalsIgnoreCase("_index") ? n[1..-1] : n
  }

  ** Normalize HTML href URIs
  static Uri htmlUri(Uri cur, Uri uri, Str? ext := ".html")
  {
   // we can assume one or two level tree of /index or /lib/page
    if (uri.path.isEmpty) return uri
    if (uri.scheme != null) return uri
    s := StrBuf()
    if (cur.path.first != uri.path.first)
    {
      if (cur.path.size > 1) s.add("../")
      if (uri.path.size > 1) s.add(uri.path[0]).addChar('/')
    }
    s.add(uri.name).joinNotNull(ext, "").joinNotNull(uri.frag, "#")
    return s.toStr.toUri
  }

//////////////////////////////////////////////////////////////////////////
// Docs
//////////////////////////////////////////////////////////////////////////

  static Str parseFirstSentence(Str s)
  {
    // this logic isn't exactly like firstSentence because we clip at colon
    if (s.isEmpty) return ""

    semicolon := s.index(";")
    if (semicolon != null) s = s[0..<semicolon]

    colon := s.index(":")
    while (colon != null && colon + 1 < s.size && !s[colon+1].isSpace)
      colon = s.index(":", colon+1)
    if (colon != null) s = s[0..<colon]

    period := s.index(".")
    while (period != null && period + 1 < s.size && !s[period+1].isSpace)
      period = s.index(".", period+1)
    if (period != null) s = s[0..<period]

    return s
  }

//////////////////////////////////////////////////////////////////////////
// Source Locations
//////////////////////////////////////////////////////////////////////////

  ** Spec location
  static FileLoc? srcLocDecode(Str:Obj obj)
  {
    s := obj["srcLoc"]
    if (s == null) return null
    return FileLoc.parse(s)
  }

  ** Spec location
  static FileLoc srcLoc(Spec x)
  {
    lib := x.lib.loc.file
    rel := x.loc.file
    if (rel.startsWith(lib)) rel = rel[lib.size..-1]
    return FileLoc(rel, x.loc.line, x.loc.col)
  }

//////////////////////////////////////////////////////////////////////////
// Tags support
//////////////////////////////////////////////////////////////////////////

  ** Generate tags for given library
  static DocTag[] genTags(Namespace ns, Lib lib)
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
    if (lib.types.size     > 0) acc.add(DocTag("types",     lib.types.size))
    if (lib.mixins.size    > 0) acc.add(DocTag("mixins",    lib.mixins.size))
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
    if (!lib.hasMarkdown) return
    lib.files.list.each |uri|
    {
      if (uri.ext != "md") return
      n := uri.name.lower
      if (n == "index.md") return f(uri, "index")
      if (n == "readme.md") return f(uri, "readme")
      f(uri, null)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Visiblity
//////////////////////////////////////////////////////////////////////////

  static Bool isLibNoDoc(Lib x)
  {
    x.meta.has("nodoc")
  }

  static Bool isSpecNoDoc(Spec x)
  {
    x.meta.has("nodoc") || XetoUtil.isAutoName(x.name)
  }

//////////////////////////////////////////////////////////////////////////
// Standard icon refs
//////////////////////////////////////////////////////////////////////////

  static Str tagToIcon(Str name)
  {
    switch (name)
    {
      case "specs":     return typeIcon
      case "mixins":    return mixinIcon
      case "globals":   return globalIcon
      case "metas":     return globalIcon
      case "funcs":     return funcIcon
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

  static const Str indexIcon    := "list"
  static const Str libIcon      := "package"
  static const Str typeIcon     := "spec"
  static const Str mixinIcon    := "spec"
  static const Str globalIcon   := "tag"
  static const Str funcIcon     := "func"
  static const Str instanceIcon := "at-sign"
  static const Str chapterIcon  := "sticky-note"
  static const Str compIcon     := "component"
  static const Str equipIcon    := "hard-drive"
  static const Str pointIcon    := "circle-dot"
  static const Str sysIcon      := "power"
  static const Str elecIcon     := "zap"
  static const Str tagIcon      := "tag"
}

