//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetom

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

    // globals (excluding functions)
    lib.globals.each |x|
    {
      if (x.type.qname != "sys::Func")
      {
        entry := PageEntry.makeSpec(x, DocPageType.global)
        entry.summaryType = genTypeRef(x.type)
        add(entry)
      }
    }

    // functions
    lib.funcs.each |x|
    {
      entry := PageEntry.makeSpec(x, DocPageType.func)
      entry.summaryType = genTypeRef(x.type)
      add(entry)
    }

    // meta specs
    lib.metaSpecs.each |x|
    {
      entry := PageEntry.makeSpec(x, DocPageType.meta)
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
      DocUtil.libEachMarkdownFile(lib) |uri, special|
      {
        // read markdown as string
        markdown := lib.files.get(uri).readAllStr

        // special handling for index.md and readme.md
        switch (special)
        {
          case "index":  libDoc.mdIndex = DocMarkdown(markdown)
          case "readme": libDoc.readme  = DocMarkdown(markdown)
          default:       add(PageEntry.makeChapter(lib, uri, markdown))
        }
      }
    }
  }

  Void add(PageEntry entry)
  {
    // verify no duplicates by key nor by uri
    existing := byKey[entry.key]
    if (existing != null)
    {
      // Provide detailed error information for debugging
      throw Err("Duplicate key '${entry.key}': existing=${existing.pageType} at ${existing.uri}, new=${entry.pageType} at ${entry.uri}")
    }
    
    existingUri := byUri[entry.uri]
    if (existingUri != null)
    {
      // Provide detailed error information for URI collisions
      throw Err("Duplicate URI '${entry.uri}': existing key='${existingUri.key}' (${existingUri.pageType}), new key='${entry.key}' (${entry.pageType})")
    }
    
    byKey.add(entry.key, entry)
    byUri.add(entry.uri, entry)
    if (entry.pageType === DocPageType.lib) libEntries.add(entry)
  }


  Str:PageEntry byKey := [:]
  Uri:PageEntry byUri := [:]
  PageEntry[] libEntries := [,]
}
