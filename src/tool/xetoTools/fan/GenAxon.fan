//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2025  Brian Frank  Creation
//

using util
using haystack
using axon

internal class GenAxon : XetoCmd
{
  override Str name() { "gen-axon" }

  override Str summary() { "Generate Xeto func specs from Axon defined by Trio/Fantom" }

  @Arg { help = "Pod name to compile" }
  Str? podName

  override Int run()
  {
    if (podName == null) throw Err("No pod name specified")
    pod := Pod.find(podName)

    acc := StubFunc[,]

    // fantom functions
    type := toFantomType(pod)
    if (type != null) reflectType(acc, type)

    // trio functions
    reflectTrioFiles(acc, pod)

    acc.sort
    writeAll(Env.cur.out, acc)

    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Fanton
//////////////////////////////////////////////////////////////////////////

  Type? toFantomType(Pod pod)
  {
    // specials
    if (pod.name == "axon") return pod.type("CoreLib")

    // SkySpark extension
    prefix := pod.name + "::"
    ext := Env.cur.index("skyarc.lib").find { it.startsWith(prefix) }
    if (ext != null) return Type.find(ext)

    return null
  }

  Void reflectType(StubFunc[] acc, Type type)
  {
    type.methods.each |m|
    {
      if (!m.isPublic) return
      if (m.parent !== type) return
      facet := m.facet(Axon#, false)
      if (facet == null) return
      acc.add(reflectMethod(m, facet))
    }
  }

  StubFunc reflectMethod(Method method, Axon facet)
  {
    // lookup method by name or _name
    name := method.name
    if (name[0] == '_') name = name[1..-1]

    doc := method.doc

    // meta
    meta := Str:Obj[:]
    facet.decode |n, v|
    {
      meta[n] = v
    }
    if (method.hasFacet(NoDoc#)) meta["nodoc"] = Marker.val

    // params
    params := method.params.map |p->StubParam|
    {
      paramName := p.name
      if (paramName == "returns") paramName = "_returns"
      return reflectParam(paramName, p.type)
    }

    // returns
    returns := reflectParam("returns", method.returns)

    // function stub
    return StubFunc(name, doc, Etc.makeDict(meta), params, returns, null)
  }

  private StubParam reflectParam(Str name, Type type)
  {
    sig := type.name
    if (type.isNullable) sig += "?"
    return StubParam(name, sig)
  }

//////////////////////////////////////////////////////////////////////////
// Write
//////////////////////////////////////////////////////////////////////////

  Void writeAll(OutStream out, StubFunc[] funcs)
  {
    funcs.each |func|
    {
      out.printLine
      write(out, func)
    }
  }

  Void write(OutStream out, StubFunc func)
  {
    doc := func.doc.trimToNull
    if (doc != null)
    {
      doc.splitLines.each |line|
      {
        out.printLine("// $line")
      }
    }

    out.print(func.name).print(": Func")

    if (!func.meta.isEmpty)
    {
      out.print(" <")
      first := true
      func.meta.each |v, n|
      {
        if (first) first = false
        else out.print(", ")
        out.print(n)
        if (v !== Marker.val) out.print(":").print(v.toStr.toCode)
      }
      out.print(">")
    }

    out.print(" { ")

    first := true
    func.params.each |p| { first = writeParam(out, p, first) }
    first = writeParam(out, func.returns, first)

    out.printLine(" }")

    if (func.axon != null)
    {
      out.printLine("  --- axon")
      func.axon.splitLines.each |line| { out.printLine("  $line") }
      out.printLine("  ---")
    }
  }

  Bool writeParam(OutStream out, StubParam p, Bool first)
  {
    if (!first) out.print(", ")
    out.print("$p.name: $p.type")
    return false
  }

//////////////////////////////////////////////////////////////////////////
// Trio
//////////////////////////////////////////////////////////////////////////

  private Void reflectTrioFiles(StubFunc[] acc, Pod pod)
  {
    pod.files.each |f|
    {
      if (f.pathStr.startsWith("/lib/") && f.ext == "trio")
        reflectTrioFile(acc, f)
    }
  }

  private Void reflectTrioFile(StubFunc[] acc, File f)
  {
    recs := TrioReader(f.in).readAllDicts
    loc := Loc(f.pathStr)
    recs.each |rec|
    {
      if (rec.has("func")) acc.addNotNull(reflectTrioFunc(loc, rec))
    }
  }

  private StubFunc? reflectTrioFunc(Loc loc, Dict rec)
  {
    name := rec["name"] as Str ?: throw Err("Func missing name: $rec")
    axon := rec["src"] as Str ?: throw Err("Func missing axon: $name")

    meta := Str:Obj[:]
    doc := ""
    rec.each |v, n|
    {
      if (n == "name") return
      if (n == "src") return
      if (n == "func") return
      if (n == "doc") { doc = v.toStr; return }
      meta[n] = v
    }

    // parse function to get param names
    parser := Parser(loc, axon.in)
    fn := parser.parseTop(name)
    params := fn.params.map |p->StubParam| { StubParam(p.name, "Obj?") }
    returns := StubParam("returns", "Obj?")

    return StubFunc(name, doc, Etc.makeDict(meta), params, returns, axon)
  }
}

**************************************************************************
** StubFunc
**************************************************************************

internal class StubFunc
{
  new make(Str name, Str doc, Dict meta, StubParam[] params, StubParam returns, Str? axon)
  {
    this.name    = name
    this.doc     = doc
    this.meta    = meta
    this.params  = params
    this.returns = returns
    this.axon    = axon
  }

  override Str toStr()
  {
    "$name(" + params.join(", ") + "): $returns.type $meta"
  }

  const Str name
  const Str doc
  const Dict meta
  const StubParam[] params
  const StubParam returns
  const Str? axon
}

internal const class StubParam
{
  new make(Str name, Str type)
  {
    this.name = name
    this.type = type
  }

  const Str name
  const Str type

  override Str toStr() { "$name: $type"  }
}

