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
** Generate initial PageEntry stub for every top-level page
**
internal class StubPages: Step
{
  override Void run()
  {
    add(PageEntry.makeIndex)
    compiler.libs.each |lib| { stubLib(lib) }
    compiler.entries = byKey
    compiler.libEntries = libEntries
  }

  Void stubLib(Lib lib)
  {
    // lib id
    libDoc := PageEntry.makeLib(lib)
    add(libDoc)

    // type ids
    typesToDoc(lib).each |x|
    {
      add(PageEntry.makeSpec(x, DocPageType.type))
    }

    // globals
    lib.globals.each |x|
    {
      entry := PageEntry.makeSpec(x, DocPageType.global)
      entry.summaryType = genTypeRef(x.type)
      add(entry)
    }

    // instances
    lib.instances.each |x|
    {
      add(PageEntry.makeInstance(lib, x))
    }

    // chapters
    if (lib.hasMarkdown)
    {
      lib.files.list.each |uri|
      {
        if (uri.ext == "md")
        {
          // read markdown as string
          markdown := lib.files.get(uri).readAllStr

          // special handling for index.md and readme.md
          n := uri.name.lower
          if (n == "index.md")
            libDoc.mdIndex = DocMarkdown(markdown)
          else if (n == "readme.md")
            libDoc.readme = DocMarkdown(markdown)
          else
            add(PageEntry.makeChapter(lib, uri, markdown))
        }
      }
    }
  }

  Void add(PageEntry entry)
  {
    // verify no duplicates by key nor by uri
    byKey.add(entry.key, entry)
    byUri.add(entry.uri, entry)
    if (entry.pageType === DocPageType.lib) libEntries.add(entry)
  }

  Str:PageEntry byKey := [:]
  Uri:PageEntry byUri := [:]
  PageEntry[] libEntries := [,]
}

