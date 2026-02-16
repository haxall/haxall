//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Dec 2025  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Encode every page to HTML file
**
internal class WriteHtml : Step
{
  override Void run()
  {
    // doc setup
    footerText = compiler.footer

    // write each page
    eachPage |entry| { writePage(entry) }

    // copy images
    compiler.libs.each |lib| { copyImages(lib) }

    // write css file
    writeCss
  }

  Void writePage(DocPage page)
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

  Void writeCss()
  {
    css := typeof.pod.file(`/res/css/style.css`).readAllStr
    file := compiler.outDir + `xetodoc.css`
    file.out.print(css).close
  }

  Str? footerText
}

