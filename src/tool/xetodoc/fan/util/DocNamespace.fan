//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Jan 2026  Brian Frank  Creation
//

using util
using concurrent
using markdown
using xeto
using xetom

**
** DocNamespace wraps a standard namespace with additional cached
** data structures used for the documentation compiler.  It parses
** and caches the chapter index and headings for link checking.
**
const class DocNamespace
{
  ** Constructor with base namespace
  new make(Namespace ns, Lib[] libs)
  {
    this.ns   = ns
    this.libs = libs
    this.libsByName = Str:Lib[:].addList(libs) { it.name }
  }

  ** Base namespace
  const Namespace ns

  ** Libs we are documenting
  const Lib[] libs

  ** Libs we are documenting
  const Str:Lib libsByName

  ** Convenience
  Lib? lib(Str name, Bool checked) { libsByName.getChecked(name, checked) }

  ** Lookup unqualified function in documented libs.  If ambiguous then
  ** prefer match in cur lib itself, and then prefer func without op tag
  Spec? func(Str name, Lib? cur := null)
  {
    matches := Spec[,]
    libs.each |lib|
    {
      matches.addNotNull(lib.funcs.get(name, false))
    }
    if (matches.size <= 1) return matches.first

    // ambiguous - prefer func in cur lib itself
    if (cur != null)
    {
      inCur := matches.find |x| { x.lib === cur }
      if (inCur != null) return inCur
    }

    // ambiguous - prefer func without op tag
    nonOps := matches.findAll |x| { x.meta.missing("op") }
    if (nonOps.size == 1) return nonOps.first
    return null
  }

  ** Get chapters keyed by name for given lib
  Str:DocNamespaceChapter chapters(Lib lib)
  {
    x := chaptersByLibName.get(lib.name)
    if (x == null)
    {
      chaptersByLibName[lib.name] = x = loadChapters(lib)
    }
    return x
  }

  private Str:DocNamespaceChapter loadChapters(Lib lib)
  {
    acc := Str:DocNamespaceChapter[:]
    lib.files.list.each |f|
    {
      if (XetoUtil.isChapter(f))
        acc[f.basename] = DocNamespaceChapter(lib, f.basename)
    }
    if (acc.isEmpty) return noChapters
    else return acc.toImmutable
  }

  private const Str:DocNamespaceChapter noChapters := [:]
  private const ConcurrentMap chaptersByLibName := ConcurrentMap()
}

**************************************************************************
** DocNamespaceChapter
**************************************************************************

@Js
const class DocNamespaceChapter
{
  internal new make(Lib lib, Str name)
  {
    this.lib  = lib
    this.name = name
    this.uri  = DocUtil.toUri(lib.name, name)
  }

  const Lib lib

  const Str name

  const Uri uri

  FileLoc loc() { FileLoc("$lib.name::$name") }

  override Str toStr() { loc.toStr }

  Str title() { parse; return titleRef.val }
  private const AtomicRef titleRef := AtomicRef()

  Str:Str headings() { parse; return headingsRef.val }
  private const AtomicRef headingsRef := AtomicRef()

  private Void parse()
  {
    if (titleRef.val != null) return

    acc := Str:Str[:]
    Str? title := null
    try
    {
      xc := XetodocChapter.parse(lib.files.get(`/${name}.md`).readAllStr)
      title = xc.meta["title"]
      acc   = xc.anchorToTextMap
    }
    catch (Err e)
    {
      Console.cur.err("Cannot parse chapter [$uri]", e)
    }
    if (name == "doc") title = "$lib.name doc"
    titleRef.val = title ?: name
    headingsRef.val = acc.toImmutable
  }

}

