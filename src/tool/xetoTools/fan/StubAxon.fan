//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2025  Brian Frank  Creation
//

using util
using haystack

internal class StubAxon : XetoCmd
{
  override Str name() { "stub-axon" }

  override Str summary() { "Generate axon xeto funcs from trio and fantom" }

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

    acc.sort
    writeAll(Env.cur.out, acc)

    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Fanton
//////////////////////////////////////////////////////////////////////////

  Type? toFantomType(Pod pod)
  {
    if (pod.name == "axon") return pod.type("CoreLib")
    return null
  }

  Void reflectType(StubFunc[] acc, Type type)
  {
    type.methods.each |m|
    {
      if (!m.isPublic) return
      if (m.parent !== type) return
      facet := m.facet(axonFacetType, false)
      if (facet == null) return
      acc.add(reflectMethod(m, facet))
    }
  }

  StubFunc reflectMethod(Method method, Obj facet)
  {
    // lookup method by name or _name
    name := method.name
    if (name[0] == '_') name = name[1..-1]

    doc := method.doc

    // meta
    meta := Str:Obj[:]
    facet.typeof.method("decode").call(facet) |n, v|
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
    return StubFunc(name, doc, Etc.makeDict(meta), params, returns)
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

    out.printLine(" {")

    func.params.each |p| { writeParam(out, p) }
    writeParam(out, func.returns)

    out.printLine("}")
  }

  Void writeParam(OutStream out, StubParam p)
  {
    out.printLine("  $p.name: $p.type")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Type axonFacetType := Type.find("axon::Axon")
}

**************************************************************************
** StubFunc
**************************************************************************

internal class StubFunc
{
  new make(Str name, Str doc, Dict meta, StubParam[] params, StubParam returns)
  {
    this.name    = name
    this.doc     = doc
    this.meta    = meta
    this.params  = params
    this.returns = returns
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

