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
using xetom

**
** AST library
**
@Js
internal const class ALib : Lib, ADoc
{
   ** Constructor
  new make(MXetoCompiler c, FileLoc loc, Str name)
  {
    this.loc      = loc
    this.astRef   = Unsafe(ALibState(c))
    this.id       = Ref("lib:$name")
    this.name     = name
    this.isSys    = name == "sys"
    this.asm      = XetoLib()
  }

  ** File location
  override const FileLoc loc

  ** Compiler
  override MXetoCompiler compiler() { ast.compiler }

  ** Node type
  override ANodeType nodeType() { ANodeType.lib }

  ** Lib id as "lib:{name}"
  override const Ref id

  ** Dotted library name
  override const Str name

  ** Is this the core sys library
  override const Bool isSys

  ** XetoLib instance - we backpatch the "m" field in Assemble step
  const override XetoLib asm

  ** Files support (set in Parse)
  override LibFiles files() { ast.files ?: throw NotReadyErr() }

  ** From pragma (set in ProcessPragma)
  override Dict meta() { ast.meta.asm }

  ** Flags
  Int flags() { ast.flags }

  ** Version parsed from pragma (set in ProcessPragma)
  override Version version() { ast.version ?: throw NotReadyErr() }

  ** Top level specs
  Str:ASpec tops() { ast.tops }

  ** TODO
  ASpec? top(Str name) { tops.get(name) }

  ** Lookup type spec
  /*
  ASpec? type(Str name)
  {
    x := tops.get(name)
    if (x != null && x.isType) return x
    return null
  }

  ** List type specs ordered by inheritance (set in InheritSlots)
  ASpec[] types() { ast.types ?: throw NotReadyErr(name) }
  */

  ** Tree walk
  override Void walkBottomUp(|ANode| f)
  {
    walkMetaBottomUp(f)
    walkInstancesBottomUp(f)
    f(this)
  }

  ** Tree walk
  override Void walkTopDown(|ANode| f)
  {
    f(this)
    walkMetaTopDown(f)
    walkInstancesTopDown(f)
  }

  override Void walkMetaBottomUp(|ANode| f)
  {
    ast.meta.walkBottomUp(f)
    tops.each |x| { x.walkBottomUp(f) }
  }

  override Void walkMetaTopDown(|ANode| f)
  {
    ast.meta.walkTopDown(f)
    tops.each |x| { x.walkTopDown(f) }
  }

  override Void walkInstancesBottomUp(|ANode| f)
  {
    ast.instances.each |x| { if (!x.isNested) x.walkBottomUp(f) }
  }

  override Void walkInstancesTopDown(|ANode| f)
  {
    ast.instances.each |x| { if (!x.isNested) x.walkTopDown(f) }
  }

  ** Auto naming for synthetic specs
  Str autoName() { "_" + (ast.autoNameCount++) }

  ** Debug dump
  override Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    tops.each |spec|
    {
      spec.dump(out, indent)
      out.printLine.printLine
    }

    ast.instances.each |data|
    {
      data.dump(out, indent)
      out.printLine.printLine
    }
  }

  ** Mutable AST state
  override ALibState ast() { astRef.val }
  const Unsafe astRef

//////////////////////////////////////////////////////////////////////////
// Dict (unsupported)
//////////////////////////////////////////////////////////////////////////

  override Bool isEmpty() { throw UnsupportedErr() }

  @Operator override Obj? get(Str name) { throw UnsupportedErr() }

  override Bool has(Str name) { throw UnsupportedErr() }

  override Bool missing(Str name) { throw UnsupportedErr() }

  override Void each(|Obj val, Str name| f) { throw UnsupportedErr() }

  override Obj? eachWhile(|Obj val, Str name->Obj?| f) { throw UnsupportedErr() }

  override Obj? trap(Str name, Obj?[]? args := null) { throw UnsupportedErr() }

//////////////////////////////////////////////////////////////////////////
// Lib (unsupported)
//////////////////////////////////////////////////////////////////////////

  override LibDepend[] depends() { throw UnsupportedErr() }

  override Spec[] specs()  { throw UnsupportedErr() }

  override Spec? spec(Str name, Bool checked := true)  { throw UnsupportedErr() }

  override Spec[] types()  { throw UnsupportedErr() }

  override Spec? type(Str name, Bool checked := true)  { throw UnsupportedErr() }

  override Spec[] mixins()  { throw UnsupportedErr() }

  override Spec? mixinFor(Spec type, Bool checked := true) { throw UnsupportedErr() }

  override Dict[] instances() { throw UnsupportedErr() }

  override Dict? instance(Str name, Bool checked := true) { throw UnsupportedErr() }

  override Void eachInstance(|Dict| f) { throw UnsupportedErr() }

  override Bool hasMarkdown() { throw UnsupportedErr() }
}

**************************************************************************
** ALibState
**************************************************************************

@Js
internal class ALibState : ADocAst
{
  new make(MXetoCompiler c)
  {
    this.compiler = c
  }

  MXetoCompiler compiler
  LibFiles? files
  ADict? meta
  Int flags
  Version? version
  Str:ASpec tops := [:] { ordered = true }
  ASpec[]? types
  Int autoNameCount

  ASpec? spec(Str name)
  {
    tops[name]
  }

  ASpec? type(Str name)
  {
    x := tops.get(name)
    if (x != null && x.isType) return x
    return null
  }

  ASpec? mixIn(Str name)
  {
    x := tops.get(name)
    if (x != null && x.isMixin) return x
    return null
  }

}

