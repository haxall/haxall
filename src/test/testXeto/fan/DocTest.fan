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
using xetoDoc

**
** DocTest
**
class DocTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    ns := createNamespace(["ph.points", "hx.test.xeto"])
    lib := ns.lib("hx.test.xeto")
    c := DocCompiler { it.ns = ns; it.libs = [lib]; it.outDir = tempDir }
    c.compile

    // DocLib
    entry := c.pages[lib.name]
    verifyLib(entry, lib, entry.page)
    verifyLib(entry, lib, roundtrip(entry))

    // DocType
    spec := lib.spec("EqA")
    entry = c.pages[spec.qname]
    verifyTypeSpec(entry, spec, entry.page)
    verifyTypeSpec(entry, spec, roundtrip(entry))
  }

  DocPage roundtrip(PageEntry entry)
  {
    file := tempDir + entry.uriJson
    json := file.readAllStr
 echo("#### rountripo $entry.uri")
 echo(json)
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
    verifyEq(n.name, lib.name)
/*
    verifyEq(n.meta.get("doc"),     lib.meta["doc"])
    verifyEq(n.meta.get("version"), lib.version.toStr)

    n.types.each |s| { verifySpecSummary(ns, lib, s, DocNodeType.type) }
    n.globals.each |s| { verifySpecSummary(ns, lib, s, DocNodeType.global) }
    n.instances.each |s| { verifyInstanceSummary(ns, lib, s) }
*/
  }

  Void verifySpec(PageEntry entry, Spec spec, DocSpec n)
  {
    verifyEq(n.qname,   spec.qname)
    verifyEq(n.name,    spec.name)
    verifyEq(n.libName, spec.lib.name)
  }

  Void verifyTypeSpec(PageEntry entry, Spec spec, DocSpec n)
  {
    verifyPage(entry, n)
    verifySpec(entry, spec, n)
  }

  /*
  Void verifySpecSummary(LibNamespace ns, Lib lib, DocSummary x, DocNodeType nt)
  {
    name := x.link.dis
    spec := lib.spec(name)
    verifyEq(x.link.href.nodeType, nt)
    verifyEq(x.link.href.uri, `$lib.name/${name}`)
    verifySummaryText(x.text, spec.meta["doc"])
  }

  Void verifyInstanceSummary(LibNamespace ns, Lib lib, DocSummary x)
  {
    name := x.link.dis
    instance := lib.instance(x.link.dis)
    verifyEq(x.link.href.nodeType, DocNodeType.instance)
    verifyEq(x.link.href.uri, `$lib.name/${name}`)
    verifySummaryText(x.text, instance["doc"])
  }
  */

  Void verifySummaryText(DocBlock n, Str? doc)
  {
    if (doc == null) doc = ""
    //echo("-- $n.text.toCode")
    //echo("   $doc.toCode")
    verify(doc.startsWith(n.text))
  }
}

