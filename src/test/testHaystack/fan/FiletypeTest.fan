//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jul 2026  Brian Frank  Creation
//

using web
using xeto
using haystack

**
** FiletypeTest tests the Filetype registry lookups
**
@Js
class FiletypeTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// List
//////////////////////////////////////////////////////////////////////////

  Void testList()
  {
    list := Filetype.list
    verifyEq(list.of, Filetype#)

    // the list is sorted by name and always includes the standard set
    names := list.map |f->Str| { f.name }
    verifyEq(names, names.dup.sort)
    ["zinc", "trio", "hayson", "jsonV3", "csv", "excel", "xml", "xeto", "jeto"].each |n|
    {
      verify(names.contains(n), n)
    }

    // every entry is reachable by its own name, and names its file spec
    list.each |f|
    {
      verifySame(Filetype.byName(f.name), f)
      verify(f.spec.startsWith("sys.files::"), f.name)
    }

    // every entry is reachable by its own mime: the mime is the key,
    // so a version param selects its own filetype
    list.each |f| { verifySame(Filetype.byMime(f.mime), f) }

  }

//////////////////////////////////////////////////////////////////////////
// ByName
//////////////////////////////////////////////////////////////////////////

  Void testByName()
  {
    f := Filetype.byName("zinc")
    verifyEq(f.name,     "zinc")
    verifyEq(f.dis,      "Zinc")
    verifyEq(f.fileExt,  "zinc")
    verifyEq(f.icon3,    "page")
    verifyEq(f.toStr,    "zinc")
    verifyEq(f.mime,     MimeType("text/zinc"))

    // mimeRes is the response Content-Type while mime stays the pure
    // lookup key: charset is added for text/*, and the JSON dialects
    // are all served as plain application/json
    verifyEq(f.mimeRes, MimeType("text/zinc; charset=utf-8"))
    verifyEq(Filetype.byName("jeto").mimeRes,   MimeType("application/json"))
    verifyEq(Filetype.byName("hayson").mimeRes, MimeType("application/json"))
    verifyEq(Filetype.byName("jsonV3").mimeRes, MimeType("application/json"))
    verifyEq(Filetype.byName("xeto").mimeRes,   MimeType("text/xeto; charset=utf-8"))

    verifyEq(Filetype.byName("badOne", false), null)
    verifyErr(UnknownFiletypeErr#) { Filetype.byName("badOne") }
    verifyErr(UnknownFiletypeErr#) { Filetype.byName("badOne", true) }

    // there is no "json" filetype: bare JSON cannot say which dialect
    // it holds, so resolution is protocol policy via apiMime
    verifyEq(Filetype.byName("json", false), null)
    verifyErr(UnknownFiletypeErr#) { Filetype.byName("json") }
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  ** Every filetype names a sys.files spec, and the spec is the fuller
  ** identity: the JSON dialects are distinct specs which share a file
  ** extension, so the extension alone resolves to the general JsonFile.
  Void testSpecs()
  {
    verifyEq(Filetype.byName("zinc").spec,   "sys.files::ZincFile")
    verifyEq(Filetype.byName("trio").spec,   "sys.files::TrioFile")
    verifyEq(Filetype.byName("csv").spec,    "sys.files::CsvFile")
    verifyEq(Filetype.byName("xeto").spec,   "sys.files::XetoFile")

    // the three JSON encodings are three specs, not one
    verifyEq(Filetype.byName("hayson").spec, "sys.files::HaysonFile")
    verifyEq(Filetype.byName("jsonV3").spec, "sys.files::HaysonV3File")
    verifyEq(Filetype.byName("jeto").spec,   "sys.files::JetoFile")

    // and they all carry the "json" extension, which is why the extension
    // cannot say which dialect a file holds
    verifyEq(Filetype.byName("hayson").fileExt, "json")
    verifyEq(Filetype.byName("jsonV3").fileExt, "json")
    verifyEq(Filetype.byName("jeto").fileExt,   "json")
  }

//////////////////////////////////////////////////////////////////////////
// ByMime
//////////////////////////////////////////////////////////////////////////

  Void testByMime()
  {
    zinc   := Filetype.byName("zinc")
    hayson := Filetype.byName("hayson")
    csv    := Filetype.byName("csv")
    jeto   := Filetype.byName("jeto")

    // bare mime type
    verifySame(Filetype.byMime(MimeType("text/zinc")), zinc)
    verifySame(Filetype.byMime(MimeType("text/csv")), csv)
    verifySame(Filetype.byMime(MimeType("text/jeto")), jeto)

    // plain "application/json" is deliberately NOT registered: which
    // codec it binds to is protocol version policy (hayson in v4, jeto
    // in v5), not registry truth
    verifyEq(Filetype.byMime(MimeType("application/json"), false), null)
    verifyErr(UnknownFiletypeErr#) { Filetype.byMime(MimeType("application/json")) }

    // the mime is the key: a version param selects its own filetype,
    // while an unregistered param such as charset falls back to the
    // bare mime
    verifySame(Filetype.byMime(MimeType("text/zinc; charset=utf-8")), zinc)
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+json;version=3")), Filetype.byName("jsonV3"))
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+json;version=4")), hayson)
    verifyEq(Filetype.byMime(MimeType("application/json;version=3"), false), null)
    verifyEq(Filetype.byMime(MimeType("application/json; charset=utf-8"), false), null)

    // the "application/vnd.haystack+{name}" form
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+zinc")), zinc)
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+trio")), Filetype.byName("trio"))
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+json")), hayson)
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+zinc; charset=utf-8")), zinc)

    // unknown
    verifyEq(Filetype.byMime(MimeType("text/foo"), false), null)
    verifyEq(Filetype.byMime(MimeType("application/vnd.haystack+foo"), false), null)
    verifyErr(UnknownFiletypeErr#) { Filetype.byMime(MimeType("text/foo")) }
    verifyErr(UnknownFiletypeErr#) { Filetype.byMime(MimeType("application/vnd.haystack+foo")) }
  }

//////////////////////////////////////////////////////////////////////////
// ApiMime
//////////////////////////////////////////////////////////////////////////

  ** apiMime maps a request/accept mime to its filetype per protocol
  ** version: null is the version default, and bare application/json is
  ** protocol policy since the mime alone cannot say which dialect
  Void testApiMime()
  {
    zinc   := Filetype.byName("zinc")
    hayson := Filetype.byName("hayson")
    jeto   := Filetype.byName("jeto")

    // null is the version default
    verifySame(Filetype.apiMime(null, ApiVersion.v4), zinc)
    verifySame(Filetype.apiMime(null, ApiVersion.v5), jeto)

    // bare application/json binds per version
    verifySame(Filetype.apiMime(MimeType("application/json"), ApiVersion.v4), hayson)
    verifySame(Filetype.apiMime(MimeType("application/json"), ApiVersion.v5), jeto)

    // the legacy ";version=3" param selects the v3 dialect under v4
    verifySame(Filetype.apiMime(MimeType("application/json;version=3"), ApiVersion.v4), Filetype.byName("jsonV3"))
    verifySame(Filetype.apiMime(MimeType("application/json;version=4"), ApiVersion.v4), hayson)

    // a registered mime resolves the same in both versions
    verifySame(Filetype.apiMime(MimeType("text/zinc"), ApiVersion.v4), zinc)
    verifySame(Filetype.apiMime(MimeType("text/zinc"), ApiVersion.v5), zinc)
    verifySame(Filetype.apiMime(MimeType("text/jeto"), ApiVersion.v4), jeto)
    verifySame(Filetype.apiMime(MimeType("application/vnd.haystack+json;version=3"), ApiVersion.v5), Filetype.byName("jsonV3"))

    // unknown
    verifyEq(Filetype.apiMime(MimeType("text/foo"), ApiVersion.v4), null)
    verifyEq(Filetype.apiMime(MimeType("text/foo"), ApiVersion.v5), null)
  }

//////////////////////////////////////////////////////////////////////////
// Reader/Writer
//////////////////////////////////////////////////////////////////////////

  Void testReaderWriter()
  {
    // the four grid formats round-trip
    verifyRoundTrip("zinc")
    verifyRoundTrip("trio")
    verifyRoundTrip("hayson")

    // zinc/trio/json/csv all have readers
    ["zinc", "trio", "hayson", "csv"].each |n|
    {
      f := Filetype.byName(n)
      verifyEq(f.hasGridReader, true)
      verifyEq(f.hasGridWriter, true)
      verifyNotNull(f.gridReaderType)
      verifyNotNull(f.gridWriterType)
    }

    // excel/xml are write-only
    ["excel", "xml"].each |n|
    {
      f := Filetype.byName(n)
      verifyEq(f.hasGridReader, false)
      verifyEq(f.gridReaderType, null)
      verifyEq(f.hasGridWriter, true)
      verifyErrMsg(Err#, "No grid reader defined for filetype $n") { f.gridReader("".in) }
    }

    // zinc reader/writer resolve to the expected types
    zinc := Filetype.byName("zinc")
    verifyEq(zinc.gridReaderType, ZincReader#)
    verifyEq(zinc.gridWriterType, ZincWriter#)
  }

  private Void verifyRoundTrip(Str name)
  {
    f := Filetype.byName(name)
    grid := GridBuilder()
      .addCol("str").addCol("num").addCol("date")
      .addRow(["hi", n(7), Date("2026-07-27")]).toGrid

    buf := Buf()
    f.gridWriter(buf.out).writeGrid(grid)
    back := f.gridReader(buf.flip.readAllStr.in).readGrid

    // trio is a dict format with no column concept, so it does not
    // preserve col order; compare the row dicts rather than the grid
    verifyEq(back.size, grid.size)
    grid.each |row, i| { verifyDictEq(back[i], row) }
  }

//////////////////////////////////////////////////////////////////////////
// Json v3
//////////////////////////////////////////////////////////////////////////

  Void testJsonVersions()
  {
    json := Filetype.byName("hayson")
    grid := Etc.toGrid(Date("2026-07-27"))

    // v4/hayson is the default: scalars encode with an explicit _kind
    v4 := StrBuf()
    json.gridWriter(v4.out).writeGrid(grid)
    verify(v4.toStr.contains("_kind"))

    // v3 is selected by the explicit "v3" opt
    v3 := StrBuf()
    json.gridWriter(v3.out, Etc.dict1("v3", Marker.val)).writeGrid(grid)
    verifyEq(v3.toStr.contains("_kind"), false)
    verify(v3.toStr.contains("d:2026-07-27"))

    // each version round-trips with its own opts
    verifyGridEq(json.gridReader(v4.toStr.in).readGrid, grid)
    verifyGridEq(json.gridReader(v3.toStr.in, Etc.dict1("v3", Marker.val)).readGrid, grid)
  }

//////////////////////////////////////////////////////////////////////////
// Misc
//////////////////////////////////////////////////////////////////////////

  Void testFlags()
  {
    // isText
    verifyEq(Filetype.byName("zinc").isText, true)
    verifyEq(Filetype.byName("csv").isText, true)
    verifyEq(Filetype.byName("excel").isText, false)

    // a "+json" suffix is text even though its media type is application;
    // the UI export menus filter on this, so a text format which answered
    // false here would silently vanish from them
    verifyEq(Filetype.byName("hayson").isText, true)
    verifyEq(Filetype.byName("jsonV3").isText, true)
    verifyEq(Filetype.byName("jeto").isText, true)
    verifyEq(Filetype.byName("xeto").isText, true)

    // isView is only the skyarc view formats
    verifyEq(Filetype.byName("zinc").isView, false)
    verifyEq(Filetype.byName("csv").isView, false)

    // a deprecated format stays resolvable by name and mime so existing
    // clients keep working, but the UI pickers leave it out
    verifyEq(Filetype.byName("jsonV3").isDeprecated, true)
    verifyEq(Filetype.byName("hayson").isDeprecated, false)
    verifyEq(Filetype.byName("jeto").isDeprecated, false)
    verifyEq(Filetype.list.findAll |f| { f.isDeprecated }.map |f->Str| { f.name },
             ["jsonV3"])
  }

//////////////////////////////////////////////////////////////////////////
// HTTP API
//////////////////////////////////////////////////////////////////////////

  ** Capability is what the HTTP API can serve; mechanism is whether a
  ** GridReader/GridWriter exists.  The xeto family is fully capable with
  ** no grid codec at all.
  Void testApiCapability()
  {
    verifyApiCap("zinc",   true,  true)
    verifyApiCap("trio",   true,  true)
    verifyApiCap("hayson", true,  true)
    verifyApiCap("jsonV3", true,  true)
    verifyApiCap("csv",    true,  true)
    verifyApiCap("excel",  false, true)
    verifyApiCap("xml",    false, true)
    verifyApiCap("xeto",   true,  true)
    verifyApiCap("jeto",   true,  true)

    verifyEq(Filetype.byName("xeto").isXetoIO, true)
    verifyEq(Filetype.byName("jeto").isXetoIO, true)
    verifyEq(Filetype.byName("zinc").isXetoIO, false)
    verifyEq(Filetype.byName("hayson").isXetoIO, false)

    // isGridIO is the mechanism flag: a GridReader/GridWriter exists
    verifyEq(Filetype.byName("zinc").isGridIO, true)
    verifyEq(Filetype.byName("xml").isGridIO, true)
    verifyEq(Filetype.byName("xeto").isGridIO, false)
    verifyEq(Filetype.byName("jeto").isGridIO, false)
  }

  private Void verifyApiCap(Str name, Bool canRead, Bool canWrite)
  {
    f := Filetype.byName(name)
    verifyEq(f.canRead,  canRead,  name)
    verifyEq(f.canWrite, canWrite, name)
  }

  ** apiEncode/apiDecode round trip per readable+writable format, plus
  ** the null result and jsonV3 mime param handling
  Void testApiIO()
  {
    ns := XetoEnv.cur.resolveNamespace(["sys", "ph"])
    grid := Etc.makeMapGrid(["title":"T"], ["dis":"A", "num":n(123), "when":Date("2026-08-20")])

    // every readable+writable format round trips a grid; csv erases
    // scalars to strings so it only verifies the encoded dis cell
    Filetype.list.each |f|
    {
      if (!f.canRead || !f.canWrite) return
      buf := Buf()
      f.apiEncode(ns, buf.out, grid)
      Grid rt := Etc.toGrid(f.apiDecode(ns, buf.flip.in))
      if (f.name == "csv") { verifyEq(rt.first->dis, "A"); return }
      verifyEq(rt.first->dis, "A")
      verifyEq(rt.first->num, n(123), f.name)
      verifyEq(rt.first->when, Date("2026-08-20"), f.name)
    }

    // the jsonV3 dialect is selected by mime resolution: it is its own
    // filetype and its codec opts come from the filetype itself
    v3 := Filetype.byName("jsonV3")
    buf := Buf()
    v3.apiEncode(ns, buf.out, grid)
    str := buf.flip.readAllStr
    verify(str.contains("n:123"))  // v3 encodes numbers as "n:123"
    Grid rt := v3.apiDecode(ns, str.in)
    verifyEq(rt.first->num, n(123))

    // null encodes as the empty grid on grid formats
    buf = Buf()
    Filetype.byName("zinc").apiEncode(ns, buf.out, null)
    verifyEq(ZincReader(buf.flip.in).readGrid.size, 0)

    // the xeto family writes the value whole: a null is a jeto null,
    // and an empty xeto body since xeto has no null literal
    buf = Buf()
    Filetype.byName("jeto").apiEncode(ns, buf.out, null)
    verifyEq(buf.flip.readAllStr.trim, "null")
    buf = Buf()
    Filetype.byName("xeto").apiEncode(ns, buf.out, null)
    verifyEq(buf.flip.readAllStr, "")
  }

//////////////////////////////////////////////////////////////////////////
// Fresco UI3
//////////////////////////////////////////////////////////////////////////

  ** The two sets the UI menus offer.  Everything listed can actually be
  ** written: a format with no working GridWriter would throw when picked.
  Void testFresco()
  {
    Filetype.exports3.each |f|
    {
      verify(f.hasGridWriter, f.name)
      verifyNotNull(f.gridWriterType(false), f.name)
      verifyFalse(f.isDeprecated, f.name)
    }

    // textViews is exports minus the view aware formats, which render a
    // document rather than the data
    Filetype.textViews3.each |f|
    {
      verify(Filetype.exports3.contains(f), f.name)
      verify(f.isText, f.name)
      verifyFalse(f.isView, f.name)
    }

    // excel is exportable but not a text view
    verify(Filetype.exports3.contains(Filetype.byName("excel")))
    verifyFalse(Filetype.textViews3.contains(Filetype.byName("excel")))

    // the xeto formats encode through XetoIO rather than a GridWriter, so
    // they are in neither set: offering them would throw when picked
    ["xeto", "jeto"].each |n|
    {
      f := Filetype.byName(n)
      verifyFalse(f.hasGridWriter, n)
      verifyFalse(Filetype.exports3.contains(f), n)
      verifyFalse(Filetype.textViews3.contains(f), n)
    }

    // optsTemplate
    verifyEq(Filetype.byName("csv").optsTemplate, "csvOpts")
    verifyEq(Filetype.byName("zinc").optsTemplate, null)
  }

  Void testViewFormats()
  {
    // pdf/svg/html are registered only when the skyarc view pod is installed
    installed := Pod.find("view", false) != null
    ["pdf", "svg", "html"].each |n|
    {
      f := Filetype.byName(n, false)
      verifyEq(f != null, installed, n)
      if (f != null)
      {
        verifyEq(f.isView, true)
        verifyEq(f.hasGridReader, false)
        verifyEq(f.hasGridWriter, true)
      }
    }
  }
}

