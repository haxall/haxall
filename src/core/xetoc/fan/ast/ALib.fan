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
internal class ALib : ADoc
{
   ** Constructor
  new make(XetoCompiler c, FileLoc loc, Str name) : super(c, loc)
  {
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

  ** From pragma (set in ProcessPragma)
  ADict? meta

  ** Version parsed from pragma (set in ProcessPragma)
  Version? version

  ** Top level specs
  Str:ASpec specs := [:] { ordered = true }

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

  ** Auto naming for synthetic specs
  Str autoName() { "_" + (autoNameCount++) }
  private Int autoNameCount

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

