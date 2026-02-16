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

  ** Lookup unqualified function - match only if there exatly one in documented libs
  Spec? func(Str name)
  {
    matches := Spec[,]
    libs.each |lib|
    {
      matches.addNotNull(lib.funcs.get(name, false))
    }
    if (matches.size == 1) return matches.first
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
      if (f.path.size == 1 && f.ext == "md")
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
      // read lines
      lines := lib.files.get(`/${name}.md`).readAllLines

      // check leading comment for title: xxxx
      if (lines.first.trim == "<!--")
      {
        lines.eachWhile |line|
        {
          line = line.trim
          if (line == "-->") return "break"
          if (line.startsWith("title:"))
            title = line[line.index(":")+1..-1].trim
          return null
        }
      }

      // lazily parse just heading lines
      proc := HeadingProcessor()
      lines.each |line|
      {
        if (!line.startsWith("#")) return
        i := 0
        while (i+1 < line.size && line[i] == '#') i++
        text := line[i..-1].trim
        anchor := proc.toAnchor(text)
        acc[anchor] = text
      }
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

