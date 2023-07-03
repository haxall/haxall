//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jul 2023  Brian Frank  Creation
//

using util
using xeto

**
** Base class for all AST nodes
**
@Js
internal abstract class ANode
{
   ** Constructor
  new make(FileLoc loc) { this.loc = loc }

  ** Source code location for reporting compiler errors
  const FileLoc loc

  ** Debug dump
  virtual Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    out.print(toStr)
  }
}