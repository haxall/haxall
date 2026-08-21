//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2019  Brian Frank  Creation
//   27 Jul 2026  Brian Frank  Redesign as standalone registry
//

using web
using xeto

**
** Filetype models a the table of data reader/writers:
**   - haystack grid formats: zinc, hayson, trio, csv (isGridIO)
**   - xeto formats: xeto, jeto (isXetoIO)
**   - document formats: excel, pdf, svg, html (isView, ui3 only)
**
@NoDoc @Js
const class Filetype
{

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  ** List all filetypes sorted by name
  static const Filetype[] list

  ** Lookup filetype by name such as "zinc"
  static Filetype? byName(Str name, Bool checked := true)
  {
    f := byNameMap[name]
    if (f != null) return f
    if (checked) throw UnknownFiletypeErr(name)
    return null
  }

  ** Lookup filetype by mime type.  The mime is the key: a param which
  ** selects a format such as ";version=3" resolves its own filetype,
  ** while unregistered params such as charset fall back to the bare
  ** mime.  The "application/vnd.haystack+{name}" form is accepted.
  static Filetype? byMime(MimeType mime, Bool checked := true)
  {
    f := byMimeMap[mime.toStr] ?: byMimeMap[mime.noParams.toStr]
    if (f != null) return f
    key := mime.noParams.toStr
    if (key.startsWith(vndPrefix)) return byName(key[vndPrefix.size..-1], checked)
    if (checked) throw UnknownFiletypeErr(mime.toStr)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Static Init
//////////////////////////////////////////////////////////////////////////

  private static const Str vndPrefix := "application/vnd.haystack+"
  private static const Str vndJson   := "application/vnd.haystack+json"

  private static const Str:Filetype byNameMap
  private static const Str:Filetype byMimeMap

  static
  {
    byNameMap := Str:Filetype[:]
    byMimeMap := Str:Filetype[:]
    try
    {
      sinit(byNameMap, byMimeMap)
    }
    catch (Err e) e.trace

    Filetype.list      = byNameMap.vals.sort.toImmutable
    Filetype.byNameMap = byNameMap.toImmutable
    Filetype.byMimeMap = byMimeMap.toImmutable
    Filetype.jeto      = byNameMap["jeto"]
    Filetype.zinc      = byNameMap["zinc"]
    Filetype.hayson    = byNameMap["hayson"]
  }

  private static Void sinit(Str:Filetype byNameMap, Str:Filetype byMimeMap)
  {
    add := |Filetype f|
    {
      byNameMap[f.name] = f
      byMimeMap[f.mime.toStr] = f
    }

    // grid formats
    add(make("zinc",   "Zinc",    "text/zinc",                "zinc", "sys.files::ZincFile",           "haystack::ZincReader",   "haystack::ZincWriter"))
    add(make("trio",   "Trio",    "text/trio",                "trio", "sys.files::TrioFile",           "haystack::TrioReader",   "haystack::TrioWriter"))
    add(make("hayson", "Hayson",  "$vndJson",                 "json", "sys.files::HaysonFile",         "haystack::HaysonReader", "haystack::HaysonWriter"))
    add(make("jsonV3", "JSON V3", "$vndJson;version=3",       "json", "sys.files::HaysonV3File",       "haystack::HaysonReader", "haystack::HaysonWriter"))
    add(make("csv",    "CSV",     "text/csv",                 "csv",  "sys.files::CsvFile",            "haystack::CsvReader",    "haystack::CsvWriter"))
    add(make("excel",  "Excel",   "application/vnd.ms-excel", "xls",  "sys.files::MicorosftExcelFile",  null,                    "hxUtil::ExcelWriter"))
    add(make("xml",    "XML",     "text/xml",                 "xml",  "sys.files::XmlFile",             null,                    "hxUtil::XmlWriter"))

    // xeto formats
    add(make("xeto",   "Xeto",    "text/xeto",                "xeto", "sys.files::XetoFile",  null, null))
    add(make("jeto",   "Jeto",    "text/jeto",                "json", "sys.files::JetoFile",  null, null))

    // skyarc view formats are only available when the view pod is installed
    if (Pod.find("view", false) != null)
    {
      add(make("pdf",  "PDF",     "application/pdf",          "pdf",  "sys.files::PdfFile",  null, "view::PdfWriter"))
      add(make("svg",  "SVG",     "image/svg+xml",            "svg",  "sys.files::SvgFile",  null, "view::SvgWriter"))
      add(make("html", "HTML",    "text/html",                "html", "sys.files::HtmlFile", null, "view::HtmlWriter"))
    }

    // hayson also answers to "application/vnd.haystack+json;version=4"
    byMimeMap["application/vnd.haystack+json;version=4"] = byNameMap["hayson"]
  }

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  private new make(Str name, Str dis, Str mimeStr, Str fileExt, Str spec, Str? reader, Str? writer)
  {
    this.name           = name
    this.dis            = dis
    this.mime           = MimeType(mimeStr)
    this.mimeRes        = toMimeRes(name, mime)
    this.fileExt        = fileExt
    this.spec           = spec
    this.gridReaderName = reader
    this.gridWriterName = writer
    this.isText         = mime.isText
    this.isGridIO       = reader != null || writer != null
    this.isXetoIO       = name == "xeto" || name == "jeto"
    this.isView         = name == "pdf" || name == "svg" || name == "html"
  }

  private static MimeType toMimeRes(Str name, MimeType mime)
  {
    // the JSON dialects are all served as plain application/json
    json := name == "jeto" || name == "hayson" || name == "jsonV3"
    if (json) return MimeType("application/json")

    if (mime.mediaType != "text") return mime
    return MimeType("$mime; charset=utf-8")
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Programmatic name such as "zinc"
  const Str name

  ** Display name such as "Zinc"
  const Str dis

  ** Mime type
  const MimeType mime

  ** Mime type to use for Content-Type response header - adds charset for text/*
  const MimeType mimeRes

  ** File extension to use (without dot)
  const Str fileExt

  ** Qname of the `sys.files` spec which models this format
  const Str spec

  ** Is this a text format (includes application/json, image/svg+xml)
  const Bool isText

  ** Does this format encode grids through a GridReader/GridWriter
  const Bool isGridIO

  ** Is this the xeto family (xeto, jeto) which encodes any value through
  ** the namespace codec rather than a GridReader/GridWriter
  const Bool isXetoIO

  ** Is this a format that supports view aware exports (versus data only export)
  const Bool isView

  ** Is this format deprecated and slated for removal.  A deprecated format
  ** is still read and written for existing clients, but is left out of the
  ** UI pickers so that nothing new is authored in it.
  Bool isDeprecated() { name == "jsonV3" }

//////////////////////////////////////////////////////////////////////////
// Fresco UI3
//////////////////////////////////////////////////////////////////////////

  ** Formats to offer for exporting a grid in UiExport dialog
  static Filetype[] exports3()
  {
    list.findAll |f| { !f.isDeprecated && f.hasGridWriter }
  }

  ** Formats to offer as a text view of a grid, such as the shell's view
  ** picker.  This is `exports` minus the view aware formats, which render
  ** a document rather than the data itself.
  static Filetype[] textViews3()
  {
    exports3.findAll |f| { f.isText && !f.isView }
  }

  ** Return ui3 Fresco options template for export dialogs or null
  Str? optsTemplate()
  {
    if (name == "pdf") return "pdfOpts"
    if (name == "csv") return "csvOpts"
    if (name == "svg") return "svgOpts"
    return null
  }

  ** Return ui3 Fresco icon name
  Str icon3()
  {
    if (name == "csv" || name == "excel") return "table"
    if (name == "pdf")  return "worksheet"
    if (name == "svg")  return "paintBrush"
    if (name == "html") return "html"
    return "page"
  }

  ** Return name
  override Str toStr() { name }

//////////////////////////////////////////////////////////////////////////
// Grid I/O
//////////////////////////////////////////////////////////////////////////

  ** Is a GridReader type defined
  Bool hasGridReader() { gridReaderName != null }

  ** Is a GridWriter type defined
  Bool hasGridWriter() { gridWriterName != null }

  ** GridReader type or null if this format cannot read grids
  Type? gridReaderType(Bool checked := true) { gridReaderName == null ? null : Type.find(gridReaderName, checked) }

  ** GridWriter type or null if this format cannot write grids
  Type? gridWriterType(Bool checked := true) { gridWriterName == null ? null : Type.find(gridWriterName, checked) }

  ** Instantiate a GridReader instance for this filetype.
  GridReader gridReader(InStream in, Dict? opts := null)
  {
    type := gridReaderType ?: throw Err("No grid reader defined for filetype $name")
    ctor := type.method("make")
    if (ctor.params.size == 1) return ctor.call(in)
    return ctor.call(in, opts ?: Etc.dict0)
  }

  ** Instantiate GridWriter instance for this filetype.
  GridWriter gridWriter(OutStream out, Dict? opts := null)
  {
    type := gridWriterType ?: throw Err("No grid writer defined for filetype $name")
    ctor := type.method("make")
    if (ctor.params.size == 1) return ctor.call(out)
    return ctor.call(out, opts ?: Etc.dict0)
  }

//////////////////////////////////////////////////////////////////////////
// HTTP API
//////////////////////////////////////////////////////////////////////////

  ** Can this filetype decode an HTTP request body
  Bool canRead() { hasGridReader || isXetoIO }

  ** Can this filetype encode an HTTP response body
  Bool canWrite() { hasGridWriter || isXetoIO }

  ** Map an HTTP API request mime type to file format or return null
  static Filetype? apiMime(MimeType? mime, ApiVersion version)
  {
    // default by version
    if (mime == null) return version.isV4 ? zinc: jeto

    // by mime
    f := byMime(mime, false)
    if (f != null) return f

    // special handling for application/json by version
    json := mime.mediaType == "application" && mime.subType == "json"
    if (json)
    {
      if (!version.isV4) return jeto
      return mime.params["version"] == "3" ? byName("jsonV3") : hayson
    }

    // no joy
    return null
  }

  ** Decode an HTTP request body.  Grid formats return a Grid; the xeto
  ** family returns the decoded value with refs resolved externally (API
  ** refs point at recs, not xeto instances).  The dialect is fully
  ** selected by `byMime` resolution, so no mime threads through here.
  ** Caller must have verified `canRead`.
  Obj? apiDecode(Namespace ns, InStream in)
  {
    if (isXetoIO)
    {
      if (name == "xeto") return ns.io.readXeto(in.readAllStr, externRefs)
      return ns.io.readJeto(in)
    }
    return gridReader(in, ioOpts).readGrid
  }

  ** Encode a value to an HTTP response body.  Grid formats bridge any
  ** value through Etc.toGrid with null as the empty grid; the xeto
  ** family writes the value whole.  Opts carry encode options such as
  ** the "box" mode for jeto.  Caller must have verified `canWrite`.
  Void apiEncode(Namespace ns, OutStream out, Obj? val, Dict opts := Etc.dict0)
  {
    if (isXetoIO)
    {
      // xeto has no null literal, so a null result is an empty body
      if (name == "xeto") { if (val != null) ns.io.writeXeto(out, val) }
      else ns.io.writeJeto(out, val, opts)
      return
    }

    // a null result encodes as the empty grid clients expect; Etc.toGrid
    // would otherwise make a single row with a null val col
    grid := val == null ? Etc.emptyGrid : Etc.toGrid(val)
    gridWriter(out, ioOpts).writeGrid(grid)
  }

  ** Reader/writer options: the jsonV3 dialect rides the hayson codec
  private Dict ioOpts() { name == "jsonV3" ? v3Opts : Etc.dict0 }

  private static const Dict v3Opts := Etc.dict1("v3", Marker.val)

  ** Xeto family reads resolve refs externally: API refs point at recs
  private static const Dict externRefs := Etc.dict1("externRefs", Marker.val)

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Filetype? jeto
  private static const Filetype? zinc
  private static const Filetype? hayson

  private const Str? gridReaderName
  private const Str? gridWriterName
}

