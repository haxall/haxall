//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jul 2025  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack
using xetoc
using axon
using hx
using hxUtil

**
** ProjSpecs implementation
**
const class HxProjSpecs : ProjSpecs
{

  new make(HxRuntime rt)
  {
    this.rt = rt
  }

  const HxRuntime rt

  Namespace ns() { rt.ns }

  TextBase tb() { rt.tb }

  override Lib lib()
  {
    ns.lib("proj")
  }

  override Str? libErrMsg()
  {
    err := ns.libErr("proj")
    if (err == null) return null
    if (err is FileLocErr) return ((FileLocErr)err).loc.toFilenameOnly.toStr + ": " + err.msg
    return err.toStr
  }

  override Str[] list()
  {
    tb.list.mapNotNull |n->Str?|
    {
      n.endsWith(".xeto") ? n[0..-6] : null
    }
  }

  override Str? read(Str name, Bool checked := true)
  {
    buf := tb.read("${name}.xeto", false)
    if (buf != null) return readFormat(name, buf)
    if (checked) throw UnknownSpecErr("proj::$name")
    return null
  }

  override Spec add(Str name, Str body)
  {
    checkName(name)
    checkExists(name, false)
    return doUpdate(name, body)
  }

  override Spec update(Str name, Str body)
  {
    checkExists(name, true)
    return doUpdate(name, body)
  }

  override Spec rename(Str oldName, Str newName)
  {
    checkName(newName)
    checkExists(newName, false)
    body := read(oldName)
    write(newName, body)
    remove(oldName)
    return lib.spec(newName)
  }

  override Void remove(Str name)
  {
    tb.delete("${name}.xeto")
    rt.libsRef.reload
  }

  private Spec doUpdate(Str name, Str body)
  {
    write(name, body)
    rt.libsRef.reload
    return lib.spec(name)
  }

  private Void write(Str name, Str body)
  {
    buf := writeFormat(name, body)
    tb.write("${name}.xeto", buf)
  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  override Spec addFunc(Str name, Str src, Dict meta := Etc.dict0)
  {
    // parse axon
    fn := Parser(Loc(name), src.in).parseTop(name, meta)

    // write xeto spec for func
    s := StrBuf()
    s.capacity = 100 + src.size
    s.add("Func")
    if (!meta.isEmpty)
    {
      s.add(" <")
      first := true
      meta.each |v, n|
      {
        if (first) first = false
        else s.add(", ")
        s.add(n)
        if (v != Marker.val) s.add(":").add(v.toStr.toCode)
      }
      s.add(">")
    }
    s.add(" { ")
    first := true
    fn.params.each |p, i|
    {
      if (first) first = false
      else s.add(", ")
      s.add(p.name).add(": Obj?")
    }
    if (!first) s.add(", ")
    s.add("returns: Obj?\n")
    s.add("<axon:---\n")
    linenum := 0
    src.eachLine |line|
    {
      linenum++
      if (line.contains("---")) throw Err("Axon cannot contain --- [line $linenum]")
      s.add(line).add("\n")
    }
    s.add("--->}\n")

    return add(name, s.toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Checks
//////////////////////////////////////////////////////////////////////////

  private Void checkName(Str name)
  {
    if (!XetoUtil.isSpecName(name)) throw NameErr("Invalid spec name $name.toCode")
  }

  private Void checkExists(Str name, Bool expect)
  {
    actual := tb.exists("${name}.xeto")
    if (actual == expect) return
    if (actual)
      throw DuplicateNameErr("Spec already exists: $name")
    else
      throw UnknownSpecErr(name)
  }

//////////////////////////////////////////////////////////////////////////
// Formatting
//////////////////////////////////////////////////////////////////////////

  private Str readFormat(Str name, Str buf)
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

  private Str writeFormat(Str name, Str body)
  {
    buf := StrBuf()
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
          buf.add(name).add(": ")
          prelude = false
        }
      }
      buf.add(line).addChar('\n')
    }
    while (!buf.isEmpty && buf[-1] == '\n') buf.remove(-1)
    return buf.toStr
  }
}

