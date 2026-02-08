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
  new make(Namespace ns)
  {
    this.ns = ns
  }

  ** Base namespace
  const Namespace ns

  ** Convenience
  Lib[] libs() { ns.libs }

  ** Convenience
  Lib? lib(Str name, Bool checked) { ns.lib(name, checked) }

  ** Convenience
  SpecMap funcs() { ns.funcs }

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

  once Str title()
  {
    if (name == "doc") return "$lib.name doc"
    return name
  }

  once Str:Str headings()
  {
    acc := Str:Str[:]
    try
    {
      proc := HeadingProcessor()

      // lazily parse just heading lines
      lines := lib.files.get(`/${name}.md`).readAllLines
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
    return acc
  }

}

