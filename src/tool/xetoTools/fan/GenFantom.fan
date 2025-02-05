//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Feb 2024  Brian Frank  Creation
//

using util
using haystack::Dict
using haystack::Marker
using xeto

internal class GenFantom : AbstractGenCmd
{
  override Str name() { "gen-fantom" }

  override Str summary() { "Generate Xeto lib of interfaces for Fantom pods" }

  @Opt { help = "Base directory to contain 'src/xeto'" }
  File workDir := Env.cur.workDir

  @Arg { help = "Pod names to compile" }
  Str[]? podNames

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    if (podNames == null || podNames.isEmpty) throw Err("No pod names specified")

    pods := podNames.map |n->Pod| { Pod.find(n) }
    pods.each |pod| { genPod(pod) }

    return 0
  }

  private Void genPod(Pod pod)
  {
    outDir = workDir +`src/xeto/fan.$pod.name/`
    genLibMeta(pod)
    pod.types.dup.sort.each |type| { genType(type) }
    if (pod.name == "sys") genSys
    echo("Generated '$pod.name' $numFiles files [$outDir.osPath]")
  }

//////////////////////////////////////////////////////////////////////////
// Generation
//////////////////////////////////////////////////////////////////////////

  private Void genLibMeta(Pod pod)
  {
    out := open(`lib.xeto`)
    out.w("pragma: Lib <").nl
    out.w("  doc: ").str(pod.meta["pod.summary"]).nl
    out.w("  version: ").str(pod.version).nl

    // depends
    out.w("  depends: {").nl
    out.w("    { lib: ").str("sys").w(" }").nl
    pod.depends.each |d|
    {
      versions := LibDependVersions.fromFantomDepend(d)
      out.w("    { lib: ").str("fan.${d.name}").w(", versions: ").str(versions).w(" }").nl
    }
    out.w("  }").nl

    // org
    orgDis := pod.meta["org.name"] ?: pod.meta["proj.name"]
    orgUri := pod.meta["org.uri"] ?: pod.meta["proj.uri"]
    if (orgDis != null || orgUri != null)
    {
      out.w("  org: {").nl
      if (orgDis != null) out.w("    dis: ").str(orgDis).nl
      if (orgUri != null) out.w("    uri: ").str(orgUri).nl
      out.w("  }").nl
    }

    out.w(">").nl
    out.close
  }

//////////////////////////////////////////////////////////////////////////
// Types
//////////////////////////////////////////////////////////////////////////

  private Void genType(Type x)
  {
    if (skipType(x)) return

    out := open(`${x.name}.xeto`)

    genDoc(out, x.doc, "")
    out.w(x.name).w(": ")
    base := x.base
    if (base != null) out.sig(base)
    else out.w("Interface")
    x.mixins.each |m| { out.w(" & ").sig(m) }

    out.meta(toTypeMeta(x))

    slots := x.slots.findAll |slot| { slot.parent === x }
    slots.sort
    if (slots.isEmpty) out.nl
    else
    {
      out.w(" {").nl.nl
      slots.each |slot| { genSlot(out, slot) }
      out.w("}").nl
    }

    out.close
  }

  Bool skipType(Type type)
  {
    if (type.isSynthetic) return true
    if (type.hasFacet(NoDoc#)) return true
    if (type.isInternal) return true
    if (type.fits(Test#) && type.qname != "sys::Test") return true
    return false
 }

  Str:Obj toTypeMeta(Type x)
  {
    acc := Str:Obj[:] { ordered = true }
    if (x.isAbstract) acc["abstract"] = Marker.val
    if (x.isConst)    acc["const"] = Marker.val
    if (x.isFinal)    acc["sealed"] = Marker.val
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Slot
//////////////////////////////////////////////////////////////////////////

  Void genSlot(FantomGenWriter out, Slot x)
  {
    if (skipSlot(x)) return

    genDoc(out, x.doc, "  ")
    out.w("  ").w(x.name).w(": ")
    if (x.isField)
      genField(out, x)
    else
      genMethod(out, x)
    out.nl
  }

  Bool skipSlot(Slot slot)
  {
    if (slot.isSynthetic) return true
    if (slot.isPrivate) return true
    if (slot.isInternal) return true
    if (slot.hasFacet(NoDoc#)) return true
    return false
  }

  Void genField(FantomGenWriter out, Field x)
  {
    out.sig(x.type)
    out.meta(toFieldMeta(x))
    out.nl
  }

  Void genMethod(FantomGenWriter out, Method x)
  {
    out.w("sys::Func")
    out.meta(toMethodMeta(x))
    out.w(" { ")
    first := true
    x.params.each |p|
    {
      if (first) first = false
      else out.w(", ")
      out.w(p.name).w(": ").sig(p.type)
    }

    if (!first) out.w(", ")
    out.w("returns: ")
    if (x.isCtor)
      out.w("fan.sys::This")
    else
      out.sig(x.returns)
    out.w(" }\n")
  }

  Str:Obj toFieldMeta(Field x)
  {
    acc := Str:Obj[:] { ordered = true }
    if (x.isAbstract) acc["abstract"] = Marker.val
    if (x.isConst)    acc["const"] = Marker.val
    if (x.isStatic)   acc["static"] = Marker.val
    if (x.isVirtual)  acc["virtual"] = Marker.val
    return acc
  }

  Str:Obj toMethodMeta(Method x)
  {
    acc := Str:Obj[:] { ordered = true }
    if (x.isAbstract) acc["abstract"] = Marker.val
    if (x.isCtor) acc["new"] = Marker.val
    else if (x.isStatic) acc["static"] = Marker.val
    if (x.isVirtual)  acc["virtual"] = Marker.val
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  FantomGenWriter open(Uri filename)
  {
    numFiles++
    file := outDir + filename
    out := FantomGenWriter(file)
    out.w("// Auto-generated ").w(ts).nl
    out.nl
    return out
  }

  Void genDoc(FantomGenWriter out, Str? doc, Str indent)
  {
    doc = doc?.trimToNull
    if (doc == null) return

    doc.splitLines.each |line|
    {
      out.w(indent).w("// ").w(line).nl
    }
  }

//////////////////////////////////////////////////////////////////////////
// Sys
//////////////////////////////////////////////////////////////////////////

  Void genSys()
  {
    out := open(`sys.xeto`)

    "A,B,C,D,E,F,G,H,K,L,M,R,V".split(',').each |n|
    {
      out.w(n).w(": Interface").nl
    }

    out.close
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  override File outDir := Env.cur.workDir
  Int numFiles
}

**************************************************************************
** FantomGenWriter
**************************************************************************

internal class FantomGenWriter : GenWriter
{
  new make(File file) : super(file) {}

  This sig(Type t)
  {
    w("fan.").w(t.pod.name).w("::").w(t.name)
  }

  This meta(Str:Obj acc)
  {
    if (acc.isEmpty) return this
    w(" <")
    first := true
    acc.each |v, n|
    {
      if (first) first = false
      else w(", ")
      w(n)
      if (v !== Marker.val) w(": ").str(v)
    }
    w(">")
    return this
  }
}

