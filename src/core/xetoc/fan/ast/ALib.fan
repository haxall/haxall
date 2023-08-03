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
using xetoEnv

**
** AST library
**
internal class ALib : ANode
{
   ** Constructor
  new make(XetoCompiler c, FileLoc loc, Str name) : super(loc)
  {
    this.compiler = c
    this.name     = name
    this.isSys    = name == "sys"
    this.asm      = XetoLib()
  }

  ** Node type
  override ANodeType nodeType() { ANodeType.lib }

  ** Dotted library name
  const Str name

  ** Is this the core sys library
  const Bool isSys

  ** XetoLib instance - we backpatch the "m" field in Assemble step
  const override XetoLib asm

  ** Compiler
  XetoCompiler compiler { private set }

  ** From pragma (set in ProcessPragma)
  ADict? meta

  ** Version parsed from pragma (set in ProcessPragma)
  Version? version

  ** Instance data
  Str:AData instances := [:]

  ** Top level specs
  Str:ASpec specs := [:] { ordered = true }

  ** Lookup top level instance data
  AData? instance(Str name) { instances.get(name) }

  ** Lookup top level spec
  ASpec? spec(Str name) { specs.get(name) }

  ** Tree walk
  override Void walk(|ANode| f)
  {
    meta.walk(f)
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

