//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Base class for WriteHtml and WriteJson
**
internal abstract class WriteStep : Step
{
  override Void run()
  {
    // write each page
    eachPage |entry| { writePage(entry) }

    // copy images
    compiler.libs.each |lib| { copyImages(lib) }
  }

  abstract Void writePage(DocPage page)

  Void copyImages(Lib lib)
  {
    lib.files.list.each |uri|
    {
      if (uri.path.size == 1 && uri.mimeType.mediaType == "image")
        copyImage(lib, uri)
    }
  }

  Void copyImage(Lib lib, Uri uri)
  {
    try
    {
      dst := compiler.outDir + `${lib.name}/$uri.name`
      lib.files.get(uri).copyTo(dst, ["overwrite":true])
    }
    catch (Err e) err("Cannot copy image $lib.name::$uri.name", FileLoc(lib.name), e)
  }
}

**************************************************************************
** HTML
**************************************************************************

**
** Encode every page to HTML file
**
internal class WriteHtml : WriteStep
{
  override Void run()
  {
    // doc setup
    footerText = compiler.footer

    // write pages and images
    super.run

    // write css file
    writeCss
  }

  override Void writePage(DocPage page)
  {
    uri := `${page.uri}.html`.relTo(`/`)
    file := compiler.outDir + uri
    out := file.out
    try
    {
      w := DocHtmlWriter(out)
      w.footerText = footerText
      w.page(page)
    }
    finally out.close
    compiler.numFiles++
  }

  Void writeCss()
  {
    css := typeof.pod.file(`/res/css/style.css`).readAllStr
    file := compiler.outDir + `xetodoc.css`
    file.out.print(css).close
  }

  Str? footerText
}

**************************************************************************
** JSON
**************************************************************************

**
** Encode every top-level node to a JSON file
**
internal class WriteJson : WriteStep
{
  override Void writePage(DocPage page)
  {
    obj := page.encode
    json := JsonOutStream.prettyPrintToStr(obj)
    writeToFile(page, json)
  }

  Void writeToFile(DocPage page, Str json)
  {
    uri := `${page.uri}.json`.relTo(`/`)
    file := compiler.outDir + uri
    file.out.print(json).close
    compiler.numFiles++
  }
}

