//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jul 2025  Brian Frank  Creation
//

using concurrent
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
    modify(filename) |f|
    {
      f.withOut |out| { out.print(val) }
    }
  }

  ** Rename a filename
  Void rename(Str oldName, Str newName)
  {
    modify(oldName) |f|
    {
      f.moveTo(file(newName))
    }
  }

  ** Delete a filename
  Void delete(Str filename)
  {
    modify(filename) |f|
    {
      f.delete
    }
  }

  ** Modify holding lock and clear digest
  private Void modify(Str filename, |File| cb)
  {
    // modify holding lock
    lock.lock
    try
    {
      cb(file(filename))
      digestRef.val = null
    }
    finally lock.unlock
  }

//////////////////////////////////////////////////////////////////////////
// Encode
//////////////////////////////////////////////////////////////////////////

  ** Create a SHA-1 digest for the files
  Str digest()
  {
    // check cache only cleared on modify
    cached := digestRef.val
    if (cached != null) return cached

    // compute new digest holding lock
    d := Crypto.cur.digest("SHA-1")
    temp := Buf(1024)
    lock.lock
    try
    {
      list.sort.each |name|
      {
        f := file(name)
        f.withIn |in| { in.readBufFully(temp.clear, f.size) }

        d.update(name.toBuf)
        d.update(temp)
      }
    }
    finally lock.unlock

    // digest is base 64 of SHA-1
    x := d.digest.toBase64Uri
    digestRef.val = x
    return x
  }

  **
  ** Encode into an in-memory buffer.  Format looks like:
  **
  **   tb 1.0
  **   <numFiles>
  **   --- <file0> <size0>
  **   <file0>
  **   --- <file1> <size1>
  **   <file1>
  **
  Buf encode()
  {
    // encode holding lock
    lock.lock
    try
    {
      // names sorted
      names := list.sort

      // allocate in-memory buffer
      buf := Buf()
      buf.capacity = names.size * 256

      // first two lines are magic, then number of files
      buf.printLine("tb 1.0")
      buf.printLine(names.size)

      // each file is "--- name size" + file + newline
      names.each |name|
      {
        f := file(name)
        size := f.size
        buf.print("--- ").print(name).print(" ").printLine(size)
        f.withIn |in| { in.readBufFully(buf, size) }
        buf.seek(buf.size) // readBufFully seeks back to start
        buf.printLine
      }

      return buf.seek(0)
    }
    finally lock.unlock
  }

  ** Decode to the given directory
  static TextBase decode(File dir, Buf buf)
  {
    // start with normalized clean dir
    tb := TextBase(dir)
    tb.dir.delete

    // read magic line
    line := buf.seek(0).readLine
    if (!line.startsWith("tb 1.0")) throw Err("Invalid text base: $line.toCode")

    // read files
    numFiles := buf.readLine.toInt
    numFiles.times |i|
    {
      line = buf.readLine
      sp  := line.index(" ", 5)
      if (!line.startsWith("--- ") || sp == null) throw Err("Invalid name line: $line")
      name := line[4..<sp]
      size := line[sp+1..-1].toInt
      tb.file(name).withOut |out| { out.writeBuf(buf, size) }
      if (!buf.readLine.isEmpty) throw Err("Expecting empty line")
    }

    return tb
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
    if (filename.contains(" ")) throw ArgErr("Filename cannot contain space")
    if (filename.contains("/")) throw ArgErr()
    file := File(dir.uri + filename.toUri, false)
    if (file.isDir) throw ArgErr()
    if (!file.normalize.pathStr.startsWith(dir.pathStr)) throw ArgErr()
    return file
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Lock lock := Lock.makeReentrant
  private const AtomicRef digestRef := AtomicRef()

}

