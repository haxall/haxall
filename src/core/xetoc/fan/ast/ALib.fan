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
    this.asm = XetoLib()
  }

  ** Node type
  override ANodeType nodeType() { ANodeType.lib }

  ** Dotted library name
  const Str name

  ** XetoLib instance - we backpatch the "m" field in Assemble step
  const XetoLib asm

// TODO
Dict meta := haystack::Etc.dict0

  ** Version parsed from pragma (set in ProcessPragma)
  Version? version

  ** Instance data
  Str:AData instances := [:]

  ** Top level specs
  Str:ASpec specs := [:]

  ** Lookup top level instance data
  AData? instance(Str name) { instances.get(name) }

  ** Lookup top level spec
  ASpec? spec(Str name) { specs.get(name) }

  ** Tree walk
  override Void walk(|ANode| f)
  {
    instances.each |x| { x.walk(f) }
    specs.each |x| { x.walk(f) }
    f(this)
  }

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

