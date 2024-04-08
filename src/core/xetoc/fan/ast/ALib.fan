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
    this.nameCode = c.names.add(name)
    this.name     = c.names.toName(nameCode) // intern
    this.isSys    = name == "sys"
    this.asm      = XetoLib()
  }

  ** Node type
  override ANodeType nodeType() { ANodeType.lib }

  ** Name code in names table
  const Int nameCode

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
  Str:ASpec tops := [:] { ordered = true }

  ** Lookup top level spec
  ASpec? top(Str name) { tops.get(name) }

  ** Tree walk
  override Void walkBottomUp(|ANode| f)
  {
    meta.walkBottomUp(f)
    tops.each |x| { x.walkBottomUp(f) }
    instances.each |x| { if (!x.isNested) x.walkBottomUp(f) }
    f(this)
  }

  ** Tree walk
  override Void walkTopDown(|ANode| f)
  {
    f(this)
    meta.walkTopDown(f)
    tops.each |x| { x.walkTopDown(f) }
    instances.each |x| { if (!x.isNested) x.walkTopDown(f) }
  }

  ** Auto naming for synthetic specs
  Str autoName() { "_" + (autoNameCount++) }
  private Int autoNameCount

  ** Debug dump
  override Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    tops.each |spec|
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

