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
    acc := Str:PageEntry[:]
    compiler.libs.each |lib| { stubLib(acc, lib) }
    compiler.pages = acc
  }

  Void stubLib(Str:PageEntry acc, Lib lib)
  {
    // lib id
    add(acc, PageEntry.makeLib(lib))

    // type ids
    typesToDoc(lib).each |x|
    {
      add(acc, PageEntry.makeSpec(x, DocPageType.type))
    }

    // globals
    lib.globals.each |x|
    {
      entry := PageEntry.makeSpec(x, DocPageType.global)
      entry.summaryType = genTypeRef(x.type)
      add(acc, entry)
    }

    // instances
    lib.instances.each |x|
    {
      add(acc, PageEntry.makeInstance(x))
    }

    // chapters
    if (lib.hasMarkdown)
    {
      lib.files.list.each |uri|
      {
        if (uri.ext == "md")
        {
          markdown := lib.files.readStr(uri)
          add(acc, PageEntry.makeChapter(lib, uri, markdown))
        }
      }
    }
  }

  Void add(Str:PageEntry acc, PageEntry entry)
  {
    acc.add(entry.key, entry)
  }

}

