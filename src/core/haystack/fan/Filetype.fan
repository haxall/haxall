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
** Filetype models a grid format definition and its reader/writer.
** The registry is a fixed table - the skyarc view formats are
** registered only when the "view" pod is installed.
**
@NoDoc @Js
const class Filetype
{

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  ** List all filetypes in registration order
  static Filetype[] list() { byNameMap.vals }

  ** Lookup filetype by name such as "zinc"
  static Filetype? byName(Str name, Bool checked := true)
  {
    f := byNameMap[name]
    if (f != null) return f
    if (checked) throw UnknownFiletypeErr(name)
    return null
  }

  ** Lookup filetype by mime type.  Ignores mime params and accepts
  ** the "application/vnd.haystack+{name}" form.
  static Filetype? byMime(MimeType mime, Bool checked := true)
  {
    key := mime.noParams.toStr
    f := byMimeMap[key]
    if (f != null) return f
    if (key.startsWith(vndPrefix)) return byName(key[vndPrefix.size..-1], checked)
    if (checked) throw UnknownFiletypeErr(key)
    return null
  }

  static
  {
    byNameMap := Str:Filetype[:] { ordered = true }
    byMimeMap := Str:Filetype[:] { ordered = true }
    add := |Str n, Str dis, Str mime, Str fileExt, Str icon, Str? reader, Str? writer, Str? optsTemplate|
    {
      try
      {
        f := Filetype(n, dis, MimeType(mime), fileExt, icon, reader, writer, optsTemplate)
        byNameMap[n] = f
        byMimeMap[f.mimeType.noParams.toStr] = f
      }
      catch (Err e) echo("ERROR Filetype init: $n\n$e.traceToStr")
    }

    add("zinc",  "Zinc",  "text/zinc; charset=utf-8",        "zinc", "page",  "haystack::ZincReader", "haystack::ZincWriter", null)
    add("trio",  "Trio",  "text/trio; charset=utf-8",        "trio", "page",  "haystack::TrioReader", "haystack::TrioWriter", null)
    add("json",  "JSON",  "application/json; charset=utf-8", "json", "page",  "haystack::HaysonReader", "haystack::HaysonWriter", null)
    add("csv",   "CSV",   "text/csv; charset=utf-8",         "csv",  "table", "haystack::CsvReader",  "haystack::CsvWriter", "csvOpts")
    add("excel", "Excel", "application/vnd.ms-excel",        "xls",  "table", null, "hxUtil::ExcelWriter", null)
    add("xml",   "XML",   "text/xml; charset=utf-8",         "xml",  "page",  null, "hxUtil::XmlWriter", null)

    // skyarc view formats are only available when the view pod is installed
    if (Pod.find("view", false) != null)
    {
      add("pdf",  "PDF",  "application/pdf", "pdf",  "worksheet",  null, "view::PdfWriter", "pdfOpts")
      add("svg",  "SVG",  "image/svg+xml",   "svg",  "paintBrush", null, "view::SvgWriter", "svgOpts")
      add("html", "HTML", "text/html",       "html", "html",       null, "view::HtmlWriter", null)
    }

    Filetype.byNameMap = byNameMap.toImmutable
    Filetype.byMimeMap = byMimeMap.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  private new make(Str name, Str dis, MimeType mimeType, Str fileExt, Str icon, Str? reader, Str? writer, Str? optsTemplate)
  {
    this.name         = name
    this.dis          = dis
    this.mimeType     = mimeType
    this.fileExt      = fileExt
    this.icon         = icon
    this.readerName   = reader
    this.writerName   = writer
    this.optsTemplate = optsTemplate
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Programmatic name such as "zinc"
  const Str name

  ** Display name such as "Zinc"
  const Str dis

  ** Mime type
  const MimeType mimeType

  ** File extension to use (without dot)
  const Str fileExt

  ** Logical icon name
  const Str icon

  ** Name of the UI options template for export dialogs or null
  const Str? optsTemplate

  ** Is this a text format
  Bool isText() { mimeType.isText }

  ** Is this a format that supports view aware exports (versus data only export)
  Bool isView() { name == "pdf" || name == "svg" || name == "html" }

  ** Return name
  override Str toStr() { name }

//////////////////////////////////////////////////////////////////////////
// Reader/Writer
//////////////////////////////////////////////////////////////////////////

  ** Is a reader type defined
  Bool hasReader() { readerName != null }

  ** Is a writer type defined
  Bool hasWriter() { writerName != null }

  ** GridReader type or null if this format cannot be read
  Type? readerType(Bool checked := true) { readerName == null ? null : Type.find(readerName, checked) }

  ** GridWriter type or null if this format cannot be written
  Type? writerType(Bool checked := true) { writerName == null ? null : Type.find(writerName, checked) }

  ** Instantiate a GridReader instance for this filetype.
  GridReader reader(InStream in, Dict? opts := null)
  {
    type := readerType ?: throw Err("No reader defined for filetype $name")
    ctor := type.method("make")
    if (ctor.params.size == 1) return ctor.call(in)
    return ctor.call(in, opts ?: Etc.dict0)
  }

  ** Instantiate GridWriter instance for this filetype.
  GridWriter writer(OutStream out, Dict? opts := null)
  {
    type := writerType ?: throw Err("No writer defined for filetype $name")
    ctor := type.method("make")
    if (ctor.params.size == 1) return ctor.call(out)
    return ctor.call(out, opts ?: Etc.dict0)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str vndPrefix := "application/vnd.haystack+"

  private static const Str:Filetype byNameMap
  private static const Str:Filetype byMimeMap

  private const Str? readerName
  private const Str? writerName
}

