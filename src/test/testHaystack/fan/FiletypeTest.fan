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

    // the standard filetypes are always registered in order
    verifyEq(list[0..8].map |f->Str| { f.name },
      ["zinc", "trio", "hayson", "jsonV3", "csv", "excel", "xml", "xeto", "jeto"])

    // every entry is reachable by its own name, and names its file spec
    list.each |f|
    {
      verifySame(Filetype.byName(f.name), f)
      verify(f.spec.startsWith("sys.files::"), f.name)
    }

    // every entry is reachable by its own mime, except where two formats
    // differ only by a mime param that lookup drops: hayson and jsonV3
    // are both "application/vnd.haystack+json", and the first wins
    list.each |f|
    {
      expect := f.name == "jsonV3" ? Filetype.byName("hayson") : f
      verifySame(Filetype.byMime(f.mimeType), expect)
    }
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
    verifyEq(f.icon,     "page")
    verifyEq(f.toStr,    "zinc")
    verifyEq(f.mimeType.noParams, MimeType("text/zinc"))

    verifyEq(Filetype.byName("badOne", false), null)
    verifyErr(UnknownFiletypeErr#) { Filetype.byName("badOne") }
    verifyErr(UnknownFiletypeErr#) { Filetype.byName("badOne", true) }

    // "json" is the name this filetype had before the two JSON encodings
    // had to be told apart; it still resolves so that command lines and
    // the vnd.haystack+json mime keep working
    verifySame(Filetype.byName("json"), Filetype.byName("hayson"))
    verifySame(Filetype.byName("json", false), Filetype.byName("hayson"))
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

    // plain "application/json" is hayson, which is what a version 4 client
    // sends; jeto has its own mime because the two cannot share one
    verifySame(Filetype.byMime(MimeType("application/json")), hayson)

    // params such as charset/version are ignored for lookup, so the version
    // is read from the mime params rather than selecting the filetype
    verifySame(Filetype.byMime(MimeType("text/zinc; charset=utf-8")), zinc)
    verifySame(Filetype.byMime(MimeType("application/json;version=3")), hayson)
    verifySame(Filetype.byMime(MimeType("application/json; charset=utf-8")), hayson)

    // the "application/vnd.haystack+{name}" form
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+zinc")), zinc)
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+trio")), Filetype.byName("trio"))
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+json")), hayson)
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+json;version=3")), hayson)

    // unknown
    verifyEq(Filetype.byMime(MimeType("text/foo"), false), null)
    verifyEq(Filetype.byMime(MimeType("application/vnd.haystack+foo"), false), null)
    verifyErr(UnknownFiletypeErr#) { Filetype.byMime(MimeType("text/foo")) }
    verifyErr(UnknownFiletypeErr#) { Filetype.byMime(MimeType("application/vnd.haystack+foo")) }
  }

//////////////////////////////////////////////////////////////////////////
// Reader/Writer
//////////////////////////////////////////////////////////////////////////

  Void testReaderWriter()
  {
    // the four grid formats round-trip
    verifyRoundTrip("zinc")
    verifyRoundTrip("trio")
    verifyRoundTrip("json")

    // zinc/trio/json/csv all have readers
    ["zinc", "trio", "json", "csv"].each |n|
    {
      f := Filetype.byName(n)
      verifyEq(f.hasReader, true)
      verifyEq(f.hasWriter, true)
      verifyNotNull(f.readerType)
      verifyNotNull(f.writerType)
    }

    // excel/xml are write-only
    ["excel", "xml"].each |n|
    {
      f := Filetype.byName(n)
      verifyEq(f.hasReader, false)
      verifyEq(f.readerType, null)
      verifyEq(f.hasWriter, true)
      verifyErrMsg(Err#, "No reader defined for filetype $n") { f.reader("".in) }
    }

    // zinc reader/writer resolve to the expected types
    zinc := Filetype.byName("zinc")
    verifyEq(zinc.readerType, ZincReader#)
    verifyEq(zinc.writerType, ZincWriter#)
  }

  private Void verifyRoundTrip(Str name)
  {
    f := Filetype.byName(name)
    grid := GridBuilder()
      .addCol("str").addCol("num").addCol("date")
      .addRow(["hi", n(7), Date("2026-07-27")]).toGrid

    buf := Buf()
    f.writer(buf.out).writeGrid(grid)
    back := f.reader(buf.flip.readAllStr.in).readGrid

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
    json := Filetype.byName("json")
    grid := Etc.toGrid(Date("2026-07-27"))

    // v4/hayson is the default: scalars encode with an explicit _kind
    v4 := StrBuf()
    json.writer(v4.out).writeGrid(grid)
    verify(v4.toStr.contains("_kind"))

    // v3 is selected by the explicit "v3" opt
    v3 := StrBuf()
    json.writer(v3.out, Etc.dict1("v3", Marker.val)).writeGrid(grid)
    verifyEq(v3.toStr.contains("_kind"), false)
    verify(v3.toStr.contains("d:2026-07-27"))

    // each version round-trips with its own opts
    verifyGridEq(json.reader(v4.toStr.in).readGrid, grid)
    verifyGridEq(json.reader(v3.toStr.in, Etc.dict1("v3", Marker.val)).readGrid, grid)
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
// Menu Sets
//////////////////////////////////////////////////////////////////////////

  ** The two sets the UI menus offer.  Everything listed can actually be
  ** written: a format with no working GridWriter would throw when picked.
  Void testMenuSets()
  {
    Filetype.exports.each |f|
    {
      verify(f.hasWriter, f.name)
      verifyNotNull(f.writerType(false), f.name)
      verifyFalse(f.isDeprecated, f.name)
    }

    // textViews is exports minus the view aware formats, which render a
    // document rather than the data
    Filetype.textViews.each |f|
    {
      verify(Filetype.exports.contains(f), f.name)
      verify(f.isText, f.name)
      verifyFalse(f.isView, f.name)
    }

    // excel is exportable but not a text view
    verify(Filetype.exports.contains(Filetype.byName("excel")))
    verifyFalse(Filetype.textViews.contains(Filetype.byName("excel")))

    // the xeto formats encode through XetoIO rather than a GridWriter, so
    // they are in neither set: offering them would throw when picked
    ["xeto", "jeto"].each |n|
    {
      f := Filetype.byName(n)
      verifyFalse(f.hasWriter, n)
      verifyFalse(Filetype.exports.contains(f), n)
      verifyFalse(Filetype.textViews.contains(f), n)
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
        verifyEq(f.hasReader, false)
        verifyEq(f.hasWriter, true)
      }
    }
  }
}
