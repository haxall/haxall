//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xeto::Lib
using xetoEnv
using haystack
using haystack::Dict
using xetoDoc

**
** DocTest
**
class DocTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  DocCompiler? compiler

  Void testBasics()
  {
    ns := createNamespace(["ph.points", "hx.test.xeto"])
    lib := ns.lib("hx.test.xeto")
    compiler = DocCompiler { it.ns = ns; it.libs = [lib]; it.outDir = tempDir }
    compiler.compile

    // lib
    entry := compiler.pages[lib.name]
    verifyLib(entry, lib, entry.page)
    verifyLib(entry, lib, roundtrip(entry))

    // type
    spec := lib.spec("EqA")
    entry = compiler.pages.getChecked(spec.qname)
    verifyTypeSpec(entry, spec, entry.page)
    verifyTypeSpec(entry, spec, roundtrip(entry))

    // global
    spec = lib.spec("globalTag")
    entry = compiler.pages.getChecked(spec.qname)
    verifyGlobal(entry, spec, entry.page)
    verifyGlobal(entry, spec, roundtrip(entry))

    // instance
    Dict inst := lib.instance("test-a")
    entry = compiler.pages.getChecked(inst.id.toStr)
    verifyInstance(entry, inst, entry.page)
    verifyInstance(entry, inst, roundtrip(entry))

    // type sigs
    spec = lib.spec("Sigs")
    entry = compiler.pages.getChecked(spec.qname)
    verifyTypeRefs(spec, entry.page)
    verifyTypeRefs(spec, roundtrip(entry))
  }

  DocPage roundtrip(PageEntry entry)
  {
    file := tempDir + entry.uriJson.toStr[1..-1].toUri
    json := file.readAllStr
    // echo("\n#### rountrip $entry.uri\n$json")
    obj  := JsonInStream(json.in).readJson
    return DocPage.decode(obj)
  }

  Void verifyPage(PageEntry entry, DocPage n)
  {
    verifyEq(n.uri,      entry.uri)
    verifyEq(n.pageType, entry.pageType)
  }

  Void verifyLib(PageEntry entry, Lib lib, DocLib n)
  {
    verifyPage(entry, n)
    verifyEq(n.pageType, DocPageType.lib)
    verifyEq(n.name, lib.name)
    verifyScalar(n.meta.get("version"), "sys::Version", lib.version.toStr)

    verifySummaries(n.types,     lib.types)
    verifySummaries(n.globals,   lib.globals)
    verifySummaries(n.instances, lib.instances)
  }

  Void verifySpec(PageEntry entry, Spec spec, DocSpecPage n)
  {
    verifyPage(entry, n)
    verifyEq(n.qname,    spec.qname)
    verifyEq(n.name,     spec.name)
    verifyEq(n.libName,  spec.lib.name)
  }

  Void verifyTypeSpec(PageEntry entry, Spec spec, DocType n)
  {
    verifySpec(entry, spec, n)
    verifyEq(n.pageType, DocPageType.type)
  }

  Void verifyGlobal(PageEntry entry, Spec spec, DocGlobal n)
  {
    verifySpec(entry, spec, n)
    verifyEq(n.pageType, DocPageType.global)
  }

  Void verifyInstance(PageEntry entry, Dict inst, DocInstance n)
  {
    verifyPage(entry, n)
    verifyEq(n.pageType, DocPageType.instance)
  }


  Void verifySummaries(DocSummary[] nodes, Obj[] defs)
  {
    verifyEq(nodes.size, defs.size)
    nodes.each |n, i|
    {
      verifySummary(n, defs[i])
    }
  }

  Void verifySummary(DocSummary n, Obj def)
  {
    entry := compiler.page(def)
    verifyEq(n.link.uri, entry.uri)
    verifyEq(n.link.dis, entry.dis)
    verifySummaryText(n.text, entry.meta["doc"])
  }

  Void verifySummaryText(DocBlock n, Str? doc)
  {
    if (doc == null) doc = ""
    // echo("-- $n.text.toCode")
    // echo("   $doc.toCode")
    verify(doc.startsWith(n.text))
  }

  Void verifyTypeRefs(Spec spec, DocType n)
  {
    /*
      a: Str
      b: Str?
      c: A | B
      d: A & B
      e: A | B <maybe>
      f: A & B <maybe>
      g: List <of:Str>
      h: List <of:Ref<of:A>>
    */

    x := n.slots["a"].type
    verifyEq(x.qname, "sys::Str")
    verifyEq(x.isMaybe, false)
    verifyEq(x.isOf, false)
    verifyEq(x.isCompound, false)

    x = n.slots["b"].type
    verifyEq(x.qname, "sys::Str")
    verifyEq(x.isMaybe, true)
    verifyEq(x.isOf, false)
    verifyEq(x.isCompound, false)

    x = n.slots["c"].type
    verifyEq(x.qname, "sys::Or")
    verifyEq(x.isMaybe, false)
    verifyEq(x.isOf, false)
    verifyEq(x.isCompound, true)
    verifyEq(x.compoundSymbol, "|")
    verifyOfs := |->|
    {
      verifyEq(x.ofs.size, 2)
      verifyEq(x.ofs[0].name, "A")
      verifyEq(x.ofs[1].name, "B")
    }
    verifyOfs()

    x = n.slots["d"].type
    verifyEq(x.qname, "sys::And")
    verifyEq(x.isMaybe, false)
    verifyEq(x.isOf, false)
    verifyEq(x.isCompound, true)
    verifyEq(x.compoundSymbol, "&")
    verifyOfs()

    x = n.slots["e"].type
    verifyEq(x.qname, "sys::Or")
    verifyEq(x.isMaybe, true)
    verifyEq(x.isOf, false)
    verifyEq(x.isCompound, true)
    verifyEq(x.compoundSymbol, "|")
    verifyOfs()

    x = n.slots["f"].type
    verifyEq(x.qname, "sys::And")
    verifyEq(x.isMaybe, true)
    verifyEq(x.isOf, false)
    verifyEq(x.isCompound, true)
    verifyEq(x.compoundSymbol, "&")
    verifyOfs()

    x = n.slots["g"].type
    verifyEq(x.qname, "sys::List")
    verifyEq(x.isMaybe, false)
    verifyEq(x.isOf, true)
    verifyEq(x.isCompound, false)
    verifyEq(x.of.qname, "sys::Str")

    x = n.slots["h"].type
    verifyEq(x.qname, "sys::List")
    verifyEq(x.isMaybe, false)
    verifyEq(x.isOf, true)
    verifyEq(x.isCompound, false)
    verifyEq(x.of.qname, "sys::Ref")
    verifyEq(x.of.isOf, true)
    verifyEq(x.of.of.name, "A")

  }

  Void verifyScalar(DocScalar n, Str qname, Str s)
  {
    // echo("~~ verifyScalar $n.type $n.scalar")
    verifyEq(n.type.qname, qname)
    verifyEq(n.scalar, s)
  }
}

