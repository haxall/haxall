//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetom
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

  DocCompiler? compiler

  Void testBasics()
  {
    ns := createNamespace(["ph.points", "hx.test.xeto", "doc.xeto"])
    lib := ns.lib("hx.test.xeto")
    docXeto := ns.lib("doc.xeto")
    compiler = DocCompiler { it.ns = ns; it.libs = [lib, docXeto]; it.outDir = tempDir }
    compiler.compile

    // lib - hx.test.xeto
    entry := compiler.entries[lib.name]
    verifyHxLib(entry, lib, entry.page)
    verifyHxLib(entry, lib, roundtrip(entry))

    // lib - doc.xeto
    verifyEq(docXeto.hasMarkdown, true)
    entry = compiler.entries.getChecked(docXeto.name)
    verifyDocLib(entry, docXeto, entry.page)
    verifyDocLib(entry, docXeto, roundtrip(entry))

    // type
    spec := lib.spec("EqA")
    entry = compiler.entries.getChecked(spec.qname)
    verifyTypeSpec(entry, spec, entry.page)
    verifyTypeSpec(entry, spec, roundtrip(entry))

    // mixin
    spec = lib.spec("TestGlobalsD")
    entry = compiler.entries.getChecked(spec.qname)
    verifySpec(entry, spec, entry.page)
    verifySpec(entry, spec, roundtrip(entry))

    // meta
    /* TODO
    spec = lib.spec("Spec").slot("q")
    entry = compiler.entries.getChecked(spec.qname)
    verifySpec(entry, spec, entry.page)
    verifySpec(entry, spec, roundtrip(entry))

    // func
    spec = lib.spec("add2")
    entry = compiler.entries.getChecked(spec.qname)
    verifySpec(entry, spec, entry.page)
    verifySpec(entry, spec, roundtrip(entry))
    */

    // instance
    Dict inst := lib.instance("test-a")
    entry = compiler.entries.getChecked(inst.id.toStr)
    verifyInstance(entry, inst, entry.page)
    verifyInstance(entry, inst, roundtrip(entry))

    // type sigs
    spec = lib.spec("Sigs")
    entry = compiler.entries.getChecked(spec.qname)
    verifyTypeRefs(spec, entry.page)
    verifyTypeRefs(spec, roundtrip(entry))

    // supertypes
    spec = lib.spec("AB")
    entry = compiler.entries.getChecked(spec.qname)
    verifySupertypes(spec, entry.page)
    verifySupertypes(spec, roundtrip(entry))

    // subtypes
    spec = lib.spec("A")
    entry = compiler.entries.getChecked(spec.qname)
    verifySubtypes(spec, entry.page)
    verifySubtypes(spec, roundtrip(entry))

    // nested queries with points
    spec = lib.spec("EqAX")
    entry = compiler.entries.getChecked(spec.qname)
    verifyPoints(spec, entry.page)
    verifyPoints(spec, roundtrip(entry))

    // chapter
    entry = compiler.entries.getChecked("doc.xeto::Namespaces")
    verifyChapter(entry.page)
    verifyChapter(roundtrip(entry))

    // tags
    verifySame(DocTag.intern("lib"), DocTags.lib)
    verifySame(DocTag.intern("type"), DocTags.type)
    verifyEq(DocTag.intern("foobar").name, "foobar")

    // search
    search := DocSearch { it.pattern = "q"; it.hits = [
      DocSummary(DocLink(`/foo`, "Foo"), DocMarkdown("summary"), [DocTags.chapter, DocTags.lib]),
      DocSummary(DocLink(`/bar`, "Bar"), DocMarkdown("here")),
    ]}
    search = roundtripMem(search)
    // echo(JsonOutStream.prettyPrintToStr(search.encode))
    verifyEq(search.pattern, "q")
    verifyEq(search.hits.size, 2)
    verifyEq(search.hits[0].tags.size, 2)
    verifyEq(search.hits[1].tags.size, 0)
    verifySame(search.hits[0].tags[0], DocTags.chapter)
    verifySame(search.hits[0].tags[1], DocTags.lib)
  }

  DocPage roundtrip(PageEntry entry)
  {
    file := tempDir + entry.uriJson.toStr[1..-1].toUri
    json := file.readAllStr
    // echo("\n#### rountrip $entry.uri\n$json")
    obj  := JsonInStream(json.in).readJson
    return DocPage.decode(obj)
  }

  DocPage roundtripMem(DocPage p)
  {
    buf := StrBuf()
    JsonOutStream(buf.out).writeJson(p.encode)
    obj := JsonInStream(buf.toStr.in).readJson
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

    docTypes := lib.types.list.findAll { it.name[0] != '_' }

    verifySummaries(n.types,     docTypes)
// TODO
//    verifySummaries(n.mixins,    lib.mixins)
    verifySummaries(n.instances, lib.instances)
  }

  Void verifyHxLib(PageEntry entry, Lib lib, DocLib n)
  {
    verifyLib(entry, lib, n)

    // walk thru all the lib specs
    lib.specs.each |a|
    {
      if (XetoUtil.isAutoName(a.name)) return
      if (a.isMixin) return
      b := n.specs.find { it.link.dis == a.name } ?: throw Err("$a.name $a.flavor")
      verifyEq(a.flavor, b.flavor)
      if (!a.isType) verifyEq(a.type.qname, b.type.qname)
    }

    // DocLib.depends
    verifyEq(n.depends.size, lib.depends.size)
    d1 := n.depends.find { it.lib.name == "ph" }
    d2 := lib.depends.find { it.name == "ph" }
    verifyEq(d1.versions.toStr, d2.versions.toStr)
  }

  Void verifyDocLib(PageEntry entry, Lib lib, DocLib n)
  {
    verifyLib(entry, lib, n)
  }

  Void verifySpec(PageEntry entry, Spec spec, DocSpec n)
  {
    verifyPage(entry, n)
    verifyEq(n.pageType, DocPageType.spec)
    verifyEq(n.qname,    spec.qname)
    verifyEq(n.name,     spec.name)
    verifyEq(n.libName,  spec.lib.name)
    verifyEq(n.lib.name, spec.lib.name)
    verifyEq(n.lib.uri,  "/${spec.lib.name}/index".toUri)
    verifyEq(n.flavor,   spec.flavor)
  }

  Void verifyTypeSpec(PageEntry entry, Spec spec, DocSpec n)
  {
    verifySpec(entry, spec, n)
    verifyEq(n.pageType, DocPageType.spec)

    siteRef := n.slots.getChecked("siteRef")
    verifyEq(siteRef.parent.qname, "ph::Equip")
    verifyEq(siteRef.base.dis, "ph::PhEntity.siteRef")
    // TODO
    //verifyEq(siteRef.base.uri, `/ph/PhEntity.siteRef`)
    verifyEq(siteRef.type.qname, "sys::Ref")

    verifyEq(n.doc.text, "Equip with *points*")
    verifyEq(n.doc.html.trim, "<p>Equip with <em>points</em></p>")
  }

  Void verifyInstance(PageEntry entry, Dict inst, DocInstance n)
  {
    verifyPage(entry, n)
    verifyEq(n.pageType, DocPageType.instance)
    verifyEq(n.lib.name, n.libName)
    verifyEq(n.lib.uri,  "/${n.libName}/index".toUri)
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
    entry := compiler.entry(def)
    verifyEq(n.link.uri, entry.uri)
    verifyEq(n.link.dis, entry.dis)
    verifySummaryText(n.text, entry.meta["doc"])
  }

  Void verifySummaryText(DocMarkdown n, Str? doc)
  {
    if (doc == null) doc = ""
    // echo("-- $n.text.toCode")
    // echo("   $doc.toCode")
    verify(doc.startsWith(n.text))
  }

  Void verifyTypeRefs(Spec spec, DocSpec n)
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

  Void verifySupertypes(Spec spec, DocSpec n)
  {
    /*
       A: Dict
       B: Dict
       AB: A & B
    */

    x := n.supertypes
    e := x.edges[0]
    verifyEq(e.mode, DocTypeGraphEdgeMode.and)
    verifyEq(e.types.size, 2)
    e0a := e.types[0]
    e0b := e.types[1]
    verifyEq(x.types[0].name, "AB")
    verifyEq(x.types[e0a].name, "A")
    verifyEq(x.types[e0b].name, "B")
  }

  Void verifySubtypes(Spec spec, DocSpec n)
  {
    /*
       A: Dict
       C: A
       AB: A & B
    */

    x := n.subtypes
    verifyEq(x.types.size, 2)
    verifyEq(x.types[0].name, "AB")
    verifyEq(x.types[1].name, "C")
  }

  Void verifyScalar(DocScalar n, Str qname, Str s)
  {
    // echo("~~ verifyScalar $n.type $n.scalar")
    verifyEq(n.type.qname, qname)
    verifyEq(n.scalar, s)
  }

  Void verifyPoints(Spec spec, DocSpec n)
  {
    /*
    EqA: Equip {
      points: {
        a: ZoneCo2Sensor
        b: ZoneCo2Sensor { foo:"!" }
      }
    }

    EqAX: EqA {
      points: {
        c: DischargeAirTempSensor
      }
    }
    */

    points := n.slots.getChecked("points").slots

    a := points.getChecked("a")
    verifyEq(a.type.qname, "ph.points::ZoneCo2Sensor")
    verifyEq(a.slots.size, 0)
    verifyEq(a.parent.qname, "hx.test.xeto::EqA.points")

    b := points.getChecked("b")
    verifyEq(b.type.qname, "ph.points::ZoneCo2Sensor")
    verifyEq(b.slots.size, 1)
    verifyEq(b.slots["foo"].type.name, "Str")
    verifyEq(b.parent.qname, "hx.test.xeto::EqA.points")

    c := points.getChecked("c")
    verifyEq(c.type.qname, "ph.points::DischargeAirTempSensor")
    verifyEq(c.slots.size, 0)
    verifyEq(c.parent, null)
  }

  Void verifyChapter(DocChapter c)
  {
    verifyEq(c.qname, "doc.xeto::Namespaces")
    verifyEq(c.doc.text.contains("A namespace is defined by a list"), true)
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  Void testUtil()
  {
    verifyUriToRef(`/index`)
    verifyUriToRef(`/acme.foo`)
    verifyUriToRef(`/acme.foo/Baz`)
    verifyUriToRef(`/search`)
    verifyUriToRef(`/search?q=foo bar`)
    verifyEq(DocUtil.uriToRef(`/foo/bar#baz`), Ref("foo::bar"))
  }

  Void verifyUriToRef(Uri uri)
  {
    id := DocUtil.uriToRef(uri)
    verifyEq(uri, DocUtil.refToUri(id))
  }

}

