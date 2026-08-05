//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Aug 2026  Brian Frank  Creation
//

using xeto

**
** LibSrcFiles is the single directory walk used to map a lib source
** directory to its source and resource files.  It is the choke point
** used by the compiler to parse the source files, by XetoZipUtil to
** build the xetolib zip, and by DirLibFiles to expose the lib's
** resource files.  Hidden files which start with "." are excluded.
**
@Js
const class LibSrcFiles
{
  ** Walk the given lib source directory
  static LibSrcFiles makeDir(File dir)
  {
    acc := Uri:File[:]
    walk(acc, "", dir)

    // flat sort so listing order is consistent regardless of nesting
    map := Uri:File[:] { ordered = true }
    acc.keys.sort.each |uri| { map[uri] = acc[uri] }
    return make(map)
  }

  private static Void walk(Uri:File acc, Str path, File file)
  {
    if (file.name.startsWith(".")) return
    if (file.isDir)
    {
      file.list.each |kid| { walk(acc, path + "/" + kid.name, kid) }
      return
    }
    acc[path.toUri] = file
  }

  private new make(Uri:File map) { this.map = map.toImmutable }

  ** Lib relative uri to file for every source and resource file
  const Uri:File map

  ** Iterate all source and resource files
  Void each(|File, Uri| f) { map.each(f) }

  ** Iterate the ".xeto" source files at any directory depth
  Void eachSrc(|File, Uri| f)
  {
    map.each |file, uri| { if (uri.ext == "xeto") f(file, uri) }
  }

  ** Return if any markdown chapter files
  once Bool hasMarkdown()
  {
    map.keys.any |uri| { uri.ext == "md" }
  }

  ** Lib relative uris of the resource files
  once Uri[] resourceUris()
  {
    map.keys.findAll |uri| { uri.ext != "xeto" }.toImmutable
  }
}

