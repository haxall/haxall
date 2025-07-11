//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jul 2025  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetoc
using hx

**
** ProjSpecs implementation
**
const class MProjSpecs : ProjSpecs
{

  new make(MProjLibs libs)
  {
    this.libs = libs
    this.fb   = libs.fb
  }

  const MProjLibs libs

  const DiskFileBase fb

  override Lib lib()
  {
    libs.ns.lib("proj")
  }

  override Str? libErrMsg()
  {
    err := libs.ns.libErr("proj")
    if (err == null) return null
    if (err is FileLocErr) return ((FileLocErr)err).loc.toFilenameOnly.toStr + ": " + err.msg
    return err.toStr
  }

  override Str[] list()
  {
    fb.list.mapNotNull |n->Str?|
    {
      if (n == "lib.xeto") return null // TODO
      return n.endsWith(".xeto") ? n[0..-6] : null
    }
  }

  override Str? read(Str name, Bool checked := true)
  {
    buf := fb.read("${name}.xeto", false)
    if (buf != null) return readFormat(name, buf)
    if (checked) throw UnknownSpecErr("proj::$name")
    return null
  }

  override Spec add(Str name, Str body)
  {
    if (read(name, false) != null) throw DuplicateNameErr("Spec already exists: $name")
    return doUpdate(name, body)
  }

  override Spec update(Str name, Str body)
  {
    read(name)
    return doUpdate(name, body)
  }

  override Spec rename(Str oldName, Str newName)
  {
    body := read(oldName)
    if (read(newName, false) != null) throw DuplicateNameErr("Spec already exists: $newName")
    write(newName, body)
    remove(oldName)
    return lib.spec(newName)
  }

  override Void remove(Str name)
  {
    fb.delete("${name}.xeto")
    libs.reload
  }

  private Spec doUpdate(Str name, Str body)
  {
    write(name, body)
    libs.reload
    return lib.spec(name)
  }

  private Void write(Str name, Str body)
  {
    buf := writeFormat(name, body)
    fb.write("${name}.xeto", buf)
  }

  private Str readFormat(Str name, Buf buf)
  {
    sb := StrBuf()
    sb.capacity = buf.size
    prelude := true
    buf.eachLine |line|
    {
      if (prelude && line.trim.isEmpty) return
      if (!sb.isEmpty) sb.add("\n")
      if (prelude)
      {
        if (line.startsWith("//")) { sb.add(line); return }
        colon := line.index(":") ?: throw Err("Malformed proj spec: $line")
        line = line[colon+1..-1].trim
        prelude = false
      }
      sb.add(line)
    }
    return sb.toStr
  }

  private Buf writeFormat(Str name, Str body)
  {
    buf := Buf()
    buf.capacity = name.size + 16 + body.size
    prelude := true
    body.splitLines.each |line|
    {
      line = line.trimEnd
      if (prelude)
      {
        line = line.trimStart
        if (line.isEmpty) return
        if (!line.startsWith("//"))
        {
          buf.print(name).print(": ")
          prelude = false
        }
      }
      buf.printLine(line)
    }
    while (!buf.isEmpty && buf[-1] == '\n') buf.size = buf.size - 1
    return buf
  }
}

