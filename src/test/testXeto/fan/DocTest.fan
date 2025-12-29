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
using xetodoc

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
    page := toPage(compiler, `/$lib.name/index`)
    verifyHxLib(lib, page)
    verifyHxLib(lib, roundtrip(page))

    // lib - doc.xeto
    verifyEq(docXeto.hasMarkdown, true)
    page = toPage(compiler, `/$docXeto.name/index`)
    verifyDocLib(docXeto, page)
    verifyDocLib(docXeto, roundtrip(page))

    // type
    spec := lib.spec("EqA")
    page = toPage(compiler, `/$lib.name/$spec.name`)
    verifyTypeSpec(spec, page)
    verifyTypeSpec(spec, roundtrip(page))

    // mixin
    spec = lib.spec("TestGlobalsD")
    page = toPage(compiler, `/$lib.name/$spec.name`)
    verifySpec( spec, page)
    verifySpec( spec, roundtrip(page))

    // instance
    Dict inst := lib.instance("test-a")
    page = toPage(compiler, `/$lib.name/test-a`)
    verifyInstance(inst, page)
    verifyInstance(inst, roundtrip(page))

    // type sigs
    spec = lib.spec("Sigs")
    page = toPage(compiler, `/$lib.name/$spec.name`)
    verifyTypeRefs(spec, page)
    verifyTypeRefs(spec, roundtrip(page))

    // supertypes
    spec = lib.spec("AB")
    page = toPage(compiler, `/$lib.name/$spec.name`)
    verifySupertypes(spec, page)
    verifySupertypes(spec, roundtrip(page))

    // subtypes
    spec = lib.spec("A")
    page = toPage(compiler, `/$lib.name/$spec.name`)
    verifySubtypes(spec, page)
    verifySubtypes(spec, roundtrip(page))

    // nested queries with points
    spec = lib.spec("EqAX")
    page = toPage(compiler, `/$lib.name/$spec.name`)
    verifyPoints(spec, page)
    verifyPoints(spec, roundtrip(page))

    // chapter
    page = toPage(compiler, `/doc.xeto/Namespaces`)
    verifyChapter(page)
    verifyChapter(roundtrip(page))

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

  DocPage toPage(DocCompiler c, Uri uri)
  {
    c.pages.find { it.uri == uri } ?: throw Err("Not found: $uri")
  }

  DocPage roundtrip(DocPage page)
  {
    file := tempDir + (page.uri.toStr[1..-1] + `.json`).toUri
    json := file.readAllStr
    // echo("\n#### rountrip $page.uri\n$json")
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

  Void verifyLib(Lib lib, DocLib n)
  {
    verifyEq(n.pageType, DocPageType.lib)
    verifyEq(n.name, lib.name)
    verifyScalar(n.meta.get("version"), "sys::Version", lib.version.toStr)

    docTypes := lib.types.list.findAll { it.name[0] != '_' }

    verifySummaries(n.types,     docTypes)
    verifySummaries(n.mixins,    lib.mixins.list)
    verifySummaries(n.instances, lib.instances)
  }

  Void verifyHxLib(Lib lib, DocLib n)
  {
    verifyLib(lib, n)

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

  Void verifyDocLib(Lib lib, DocLib n)
  {
    verifyLib(lib, n)
  }

  Void verifySpec(Spec spec, DocSpec n)
  {
    verifyEq(n.pageType, DocPageType.spec)
    verifyEq(n.qname,    spec.qname)
    verifyEq(n.name,     spec.name)
    verifyEq(n.libName,  spec.lib.name)
    verifyEq(n.lib.name, spec.lib.name)
    verifyEq(n.lib.uri,  "/${spec.lib.name}/index".toUri)
    verifyEq(n.flavor,   spec.flavor)
  }

  Void verifyTypeSpec(Spec spec, DocSpec n)
  {
    verifySpec(spec, n)
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

  Void verifyInstance(Dict inst, DocInstance n)
  {
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
    if (def is Spec)
    {
      x := (Spec)def
      verifyEq(n.link.uri, "/$x.lib.name/$x.name".toUri)
      verifyEq(n.link.dis, x.name)
    }
    else if (def is Dict)
    {
      x := (Dict)def
      qname := x.id.id
      lib := XetoUtil.qnameToLib(qname)
      name := XetoUtil.qnameToName(qname)
      verifyEq(n.link.uri, "/$lib/$name".toUri)
      verifyEq(n.link.dis, name)
    }
    else
    {
      echo("TODO: verfiySummary $n.link.uri | $def.typeof")
    }
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

