//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//   3 Jul 2023  Brian Frank  Redesign the AST
//

using util
using xeto

**
** AST library
**
@Js
internal class ALib : ANode
{
   ** Constructor
  new make(FileLoc loc, Str name) : super(loc)
  {
    this.name = name
  }

  ** Dotted library name
  const Str name

  ** Instance data
  Str:AData instances := [:]

  ** Top level specs
  Str:ASpec specs := [:]

  ** Debug dump
  override Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    specs.each |spec|
    {
      spec.dump(out, indent)
      out.printLine.printLine
    }

    instances.each |data|
    {
      data.dump(out, indent)
      out.printLine.printLine
    }
  }
}

