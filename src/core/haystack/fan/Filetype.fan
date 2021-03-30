//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2019  Brian Frank  Creation
//

**
** Filetype models filetype format definition
**
@NoDoc @Js
const mixin Filetype : Def
{
  ** Mime type
  abstract MimeType mimeType()

  ** Is this a text format
  Bool isText() { mimeType.mediaType == "text" || mimeType.subType.endsWith("json") }

  ** Is a reader type defined
  Bool hasWriter() { has("writer") }

  ** Is a reader type defined
  Bool hasReader() { has("reader") }

  ** GridWriter type
  Type? writerType()
  {
    if (has("writer")) return Type.find(this->writer)

    // writer is only merged in via defx for skyarc; but
    // we need it for defc and other stuff with just standard ph
    switch (name)
    {
      case "zinc":   return ZincWriter#
      case "trio":   return TrioWriter#
      case "json":   return JsonWriter#
      case "turtle": return Type.find("def::TurtleWriter")
      case "jsonld": return Type.find("def::JsonLdWriter")
      case "csv":    return Type.find("view::CsvWriter")
    }
    return null
  }

  ** GridReader type
  Type? readerType() { has("reader") ? Type.find(this->reader) : null }

  ** Instantiate GridWriter instance for this filetype.
  GridWriter writer(OutStream out, Dict? opts := null)
  {
    type := writerType ?: throw Err("No writer defined for filetype $name")
    ctor := type.method("make")
    if (ctor.params.size == 1) return ctor.call(out)
    if (ctor.params.size == 2) return ctor.call(out, opts ?: Etc.emptyDict)
    throw Err("Invalid GridWriter.make signature: $ctor")
  }

  ** Instantiate a GridReader instance for this filetype.
  GridReader reader(InStream in, Dict? opts := null)
  {
    type := readerType ?: throw Err("No reader defined for filetype $name")
    ctor := type.method("make")
    if (ctor.params.size == 1) return ctor.call(in)
    if (ctor.params.size == 2) return ctor.call(in, opts ?: Etc.emptyDict)
    throw Err("Invalid GridReader.make signature: $ctor")
  }

  ** Build standard opts dict for `writer` and `reader` methods.
  **  - ns: required for def aware formats like RDF
  **  - mime: if HTTP op, can be used to pick version fallbacks
  **  - arg: explicit opts argument such as ioReadJson options
  **  - settings: library settings used to change global defaults
  Dict ioOpts(Namespace ns, MimeType? mime, Dict arg, Dict settings)
  {
    if (name == "json")
    {
      v3 := false
      if (settings["jsonVersion"]?.toStr == "3") v3 = true
      if (arg.has("v3")) v3 = true
      if (arg.has("v4")) v3 = false
      if (mime != null)
      {
        mimeVersion := mime.params["version"]
        if (mimeVersion == "3") v3 = false
        if (mimeVersion == "4") v3 = true
      }
      if (v3) return Etc.dictMerge(arg, Etc.makeDict2("ns", ns, "v3", Marker.val))
    }
    return Etc.dictSet(arg, "ns", ns)
  }

  ** File extension to use (without dot)
  Str fileExt() { get("fileExt", name) }

  ** Logical icon name
  Str icon() { get("icon", "question") }

  ** Is this a format that supports view aware exports (versus data only export)
  Bool isView() { name == "pdf" || name == "svg" || name == "html" }

}