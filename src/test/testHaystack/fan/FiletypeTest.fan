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

    // the six standard filetypes are always registered in order
    verifyEq(list[0..5].map |f->Str| { f.name },
      ["zinc", "trio", "json", "csv", "excel", "xml"])

    // every entry is reachable by its own name and mime
    list.each |f|
    {
      verifySame(Filetype.byName(f.name), f)
      verifySame(Filetype.byMime(f.mimeType), f)
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
  }

//////////////////////////////////////////////////////////////////////////
// ByMime
//////////////////////////////////////////////////////////////////////////

  Void testByMime()
  {
    zinc := Filetype.byName("zinc")
    json := Filetype.byName("json")
    csv  := Filetype.byName("csv")

    // bare mime type
    verifySame(Filetype.byMime(MimeType("text/zinc")), zinc)
    verifySame(Filetype.byMime(MimeType("text/csv")), csv)
    verifySame(Filetype.byMime(MimeType("application/json")), json)

    // params such as charset/version are ignored for lookup
    verifySame(Filetype.byMime(MimeType("text/zinc; charset=utf-8")), zinc)
    verifySame(Filetype.byMime(MimeType("application/json;version=3")), json)
    verifySame(Filetype.byMime(MimeType("application/json; charset=utf-8")), json)

    // the "application/vnd.haystack+{name}" form
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+zinc")), zinc)
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+trio")), Filetype.byName("trio"))
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+json")), json)
    verifySame(Filetype.byMime(MimeType("application/vnd.haystack+json;version=3")), json)

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
    verifyEq(Filetype.byName("json").isText, true)   // subType ends with "json"
    verifyEq(Filetype.byName("excel").isText, false)

    // isView is only the skyarc view formats
    verifyEq(Filetype.byName("zinc").isView, false)
    verifyEq(Filetype.byName("csv").isView, false)

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
