//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

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

  Void writePage(PageEntry entry)
  {
    file := compiler.outDir + entry.uriJson.relTo(`/`)
    obj := entry.page.encode
    str := JsonOutStream.prettyPrintToStr(obj)
    file.out.print(str).close
  }
}

