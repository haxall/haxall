//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jul 2025  Brian Frank  Creation
//

using crypto
using util
using xeto

**
** TextBase is a simple database of text files stored to a flat directory.
** It is designed for small datasets under 1MB such as configuration data
** where we want easy access for text editing.
**
class TextBase
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Construct for given directory
  new make(File dir)
  {
    if (!dir.isDir) throw ArgErr("Not dir: $dir")
    this.dir = dir.normalize
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Directory for files
  const File dir

//////////////////////////////////////////////////////////////////////////
// Files
//////////////////////////////////////////////////////////////////////////

  ** List filenames
  Str[] list()
  {
    acc := Str[,]
    dir.list.each |f|
    {
      if (f.isDir) return
      if (f.name[0] == '.') return
      name := f.name
      acc.add(name)
    }
    return acc
  }

  ** Return if filename exists
  Bool exists(Str filename)
  {
    file(filename).exists
  }

  ** Read a filename, or if does not exist raise exception or return null
  Str? read(Str filename, Bool checked := true)
  {
    f := file(filename)
    if (f.exists) return f.readAllStr
    if (checked) throw UnknownNameErr(filename)
    return null
  }

  ** Write a filename
  Void write(Str filename, Str val)
  {
    file(filename).withOut |out| { out.print(val) }
  }

  ** Rename a filename
  Void rename(Str oldName, Str newName)
  {
    file(oldName).moveTo(file(newName))
  }

  ** Delete a filename
  Void delete(Str filename)
  {
    file(filename).delete
  }

//////////////////////////////////////////////////////////////////////////
// Encode
//////////////////////////////////////////////////////////////////////////

  ** Create a SHA-1 digest for the files
  Str digest()
  {
    d := Crypto.cur.digest("SHA-1")
    list.sort.each |name|
    {
      d.update(name.toBuf)
      d.update(file(name).readAllBuf)
    }
    return d.digest.toBase64Uri
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Debug dump
  Void dump(Console con := Console.cur)
  {
    table := Obj[][,]
    table.add(["name", "size", "preview"])
    list.each |n|
    {
      size := file(n).size.toLocale
      preview := read(n)
      if (preview.size > 30) preview = preview[0..<30]
      table.add([n, size, preview.toCode])
    }
    con.table(table)
  }

  ** Map filename to file safely
  private File file(Str filename)
  {
    if (filename[0] == '.') throw ArgErr("Filename cannot start with dot")
    if (filename.contains("/")) throw ArgErr()
    file := File(dir.uri + filename.toUri, false)
    if (file.isDir) throw ArgErr()
    if (!file.normalize.pathStr.startsWith(dir.pathStr)) throw ArgErr()
    return file
  }
}

