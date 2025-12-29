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
** Encode every top-level node to a JSON file
**
internal class WriteJson : Step
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

