//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using util
using xeto

**
** AFile models one Fantom source file containing @Gen types.
** All line numbers in the AST are zero based indices into lines.
**
internal class AFile
{
  new make(APod pod, File file, Str[] lines)
  {
    this.pod   = pod
    this.file  = file
    this.lines = lines
  }

  APod pod                 // parent pod
  const File file          // Fantom source file
  Str[] lines              // source lines, zero based
  AType[] types := [,]     // types tagged with @Gen

  Void dump(Console con := Console.cur)
  {
    con.group(file.osPath)
    types.each |t| { t.dump(con) }
    con.groupEnd
  }

  override Str toStr() { file.osPath }
}

