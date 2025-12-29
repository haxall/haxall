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
    eachPage |entry|
    {
      writePage(entry)
    }
  }

  Void writePage(DocPage page)
  {
    uri := `${page.uri}.html`.relTo(`/`)
    file := compiler.outDir + uri
    file.out.print("// TODO: $page.title").close
    compiler.numFiles++
  }
}

