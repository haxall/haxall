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
**   - haystack grid formats: zinc, hayson, trio, csv (grid only)
**   - xeto formats: xeto, jeto (requires namespace)
**   - document formats: excel, pdf, svg, html (UI only)
**
@NoDoc @Js
const class Filetype
{

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  ** List all filetypes in registration order
  static Filetype[] list() { byNameMap.vals }

  ** Formats to offer for exporting a grid in UiExport dialog
  static Filetype[] exports() { exportsRef }

  ** Formats to offer as a text view of a grid, such as the shell's view
  ** picker.  This is `exports` minus the view aware formats, which render
  ** a document rather than the data itself.
  static Filetype[] textViews() { textViewsRef }

  ** Lookup filetype by name such as "zinc".
  ** Note "json" is accepted as an alias for "hayson"
  static Filetype? byName(Str name, Bool checked := true)
  {
    f := byNameMap[name]
    if (f != null) return f
    if (name == "json") return byNameMap["hayson"]
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
    add := |Filetype f|
    {
      byNameMap[f.name] = f

      // first registration wins: hayson and jsonV3 differ only by the
      // ";version" mime param, which noParams drops, so the entry listed
      // first is the one a bare mime resolves to
      key := f.mimeType.noParams.toStr
      if (byMimeMap[key] == null) byMimeMap[key] = f
    }

    // grid formats
    add(make("zinc",   "Zinc",    "text/zinc; charset=utf-8",                "zinc", "sys.files::ZincFile",           "page",  "haystack::ZincReader",   "haystack::ZincWriter",  null))
    add(make("trio",   "Trio",    "text/trio; charset=utf-8",                "trio", "sys.files::TrioFile",           "page",  "haystack::TrioReader",   "haystack::TrioWriter",  null))
    add(make("hayson", "Hayson",  "application/vnd.haystack+json;version=4", "json", "sys.files::HaysonFile",         "page",  "haystack::HaysonReader", "haystack::HaysonWriter", null))
    // jsonV3 is deprecated and will be removed in a future version
    add(make("jsonV3", "JSON V3", "application/vnd.haystack+json;version=3", "json", "sys.files::HaysonV3File",       "page",  "haystack::HaysonReader", "haystack::HaysonWriter", null))
    add(make("csv",    "CSV",     "text/csv; charset=utf-8",                 "csv",  "sys.files::CsvFile",            "table", "haystack::CsvReader",    "haystack::CsvWriter",   "csvOpts"))
    add(make("excel",  "Excel",   "application/vnd.ms-excel",                "xls",  "sys.files::MicorosftExcelFile", "table", null,                     "hxUtil::ExcelWriter",   null))
    add(make("xml",    "XML",     "text/xml; charset=utf-8",                 "xml",  "sys.files::XmlFile",            "page",  null,                     "hxUtil::XmlWriter",     null))

    // xeto formats
    add(make("xeto",   "Xeto",    "text/xeto; charset=utf-8",                "xeto", "sys.files::XetoFile",           "page",  null, null, null))
    add(make("jeto",   "Jeto",    "text/jeto; charset=utf-8",                "json", "sys.files::JetoFile",           "page",  null, null, null))

    // skyarc view formats are only available when the view pod is installed
    if (Pod.find("view", false) != null)
    {
      add(make("pdf",  "PDF",     "application/pdf",                         "pdf",  "sys.files::PdfFile",            "worksheet",  null, "view::PdfWriter",  "pdfOpts"))
      add(make("svg",  "SVG",     "image/svg+xml",                           "svg",  "sys.files::SvgFile",            "paintBrush", null, "view::SvgWriter",  "svgOpts"))
      add(make("html", "HTML",    "text/html",                               "html", "sys.files::HtmlFile",           "html",       null, "view::HtmlWriter", null))
    }

    // hayson also answers the plain "application/json" a version 4 client
    // sends; its own mime names the version explicitly
    byMimeMap["application/json"] = byNameMap["hayson"]

    Filetype.byNameMap = byNameMap.toImmutable
    Filetype.byMimeMap = byMimeMap.toImmutable

    // the UI menu sets.  The xeto formats are excluded by hasWriter: they
    // have no GridWriter at all, since they encode through XetoIO which
    // needs a namespace this API cannot reach
    exports := byNameMap.vals.findAll |f| { !f.isDeprecated && f.hasWriter }
    Filetype.exportsRef = exports.toImmutable
    Filetype.textViewsRef = exports.findAll |f| { f.isText && !f.isView }.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  private new make(Str name, Str dis, Str mime, Str fileExt, Str spec, Str icon, Str? reader, Str? writer, Str? optsTemplate)
  {
    this.name         = name
    this.dis          = dis
    this.mimeType     = MimeType(mime)
    this.fileExt      = fileExt
    this.spec         = spec
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

  ** Qname of the `sys.files` spec which models this format.  The spec is
  ** the full identity: it carries the mime type and file extension, and
  ** its inheritance says how formats relate - HaysonFile and JetoFile are
  ** both JsonFile, so both answer to "is this JSON".
  **
  ** Several formats share a file extension: hayson and jeto are both
  ** "json", so the extension alone resolves to the general JsonFile rather
  ** than to either of them.  A caller with more context asks by spec.
  const Str spec

  ** Logical icon name
  const Str icon

  ** Name of the UI options template for export dialogs or null
  const Str? optsTemplate

  ** Is this a text format
  Bool isText() { mimeType.isText }

  ** Is this a format that supports view aware exports (versus data only export)
  Bool isView() { name == "pdf" || name == "svg" || name == "html" }

  ** Is this format deprecated and slated for removal.  A deprecated format
  ** is still read and written for existing clients, but is left out of the
  ** UI pickers so that nothing new is authored in it.
  Bool isDeprecated() { name == "jsonV3" }

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
  private static const Filetype[] exportsRef
  private static const Filetype[] textViewsRef

  private const Str? readerName
  private const Str? writerName
}

