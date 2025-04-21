//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Apr 2025  Brian Frank  Creation
//

using util
using xeto
using haystack
using haystack::Dict

**
** DocSpace implements a corpus of Xeto lib documentation
** that is treated a whole for indexing and search
**
const mixin DocSpace
{
  ** Resolve doc page file in this space.
  **
  ** Standard URIs which must be handled:
  **   - /index: top level index
  **   - /{lib}/index: library level index
  **   - /{lib}/{doc}: spec and instance level pages
  **   - /search?q={pattern}: search
  abstract DocFile? resolve(Uri uri, Bool checked := true)

  ** Iterate all the pages in the spage
  abstract Void eachPage(|DocPage| f)

  ** Search the given pattern and return search page
  abstract DocFile search(Str pattern, Dict opts)
}

**************************************************************************
** FileDocSpace
**************************************************************************

**
** Implementation of DocSpace that resolves URIs to the local
** file system of pre-compiled JSON files.  Search is not supported.
**
const class FileDocSpace : DocSpace
{
  ** Construt with root dir that contains lib directories
  new make(File dir)
  {
    this.dir = dir
    this.dirNormPath = dir.normalize.pathStr
  }

  ** Root directory
  const File dir

  const Str dirNormPath

  ** Resolve uri to a doc file ending in ".json"
  override DocFile? resolve(Uri uri, Bool checked := true)
  {
    // extract two level path
    libName := uri.path.getSafe(0) ?: "_not_found_"
    docName := uri.path.getSafe(1)

    // special handling for search
    if (libName == "search")
      return search(uri.queryStr ?: "", Etc.dict0)

    // build file path under dir
    path := docName == null ? "${libName}.json" : "${libName}/${docName}.json"

    // resolve to file
    file := dir + path.toUri
    if (file.exists && !file.isDir && file.normalize.pathStr.startsWith(dirNormPath))
      return DocDiskFile(uri, file)

    // no joy
    if (checked) throw UnresolvedErr(uri.toStr)
    return null
  }

  ** Iterate all the pages in the spage
  override Void eachPage(|DocPage| f) { doEachPage(dir, 0, f) }
  private Void doEachPage(File file, Int level, |DocPage| f)
  {
    if (file.isDir)
    {
      if (level > 1) return
      file.list.each |kid| { doEachPage(kid, level+1, f) }
    }
    else if (file.ext == "json")
    {
      try
        f(DocPage.decodeFromFile(file))
      catch (Err e)
        Console.cur.err("${typeof}.eachPage [$file.osPath]", e)
    }
  }

  ** Return unsupported page
  override DocFile search(Str pattern, Dict opts)
  {
    page := DocSearch {
      it.pattern = pattern
      it.hits = [DocSummary(DocLink(`sys/index`, "Not Avail"), DocMarkdown("Doc search unavailable"))]
    }
    return DocMemFile(page)
  }
}

