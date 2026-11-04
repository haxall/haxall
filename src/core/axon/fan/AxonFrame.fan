//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Oct 2009  Brian Frank  Creation
//   3 Nov 2026  Brian Frank  Move into own file as AxonFrame
//

using util
using xeto
using haystack

**
** AxonFrame manages the state/scope of function call
**
@NoDoc @Js
class AxonFrame
{
  new make(Fn func, Obj?[] args, FileLoc callLoc, Str:Obj? vars, CallFrameMode mode := CallFrameMode.fn)
  {
    this.func    = func
    this.callLoc = callLoc
    this.vars    = vars
    this.mode    = mode

    // bind parameter variables to arguments
    if (!func.isNative)
      func.params.each |param, i| { set(param.name, args[i]) }
  }

  new makeRoot()
  {
    this.func    = rootFunc
    this.callLoc = func.loc
    this.vars    = Str:Obj?[:]
    this.mode    = CallFrameMode.top
  }

  ** Does this frame contain the given var name (taking null into account)
  Bool has(Str name) { vars.containsKey(name) }

  ** Get variable
  Obj? get(Str name)
  {
    vars[name]
  }

  ** Set variable
  Obj? set(Str name, Obj? val)
  {
    vars[name] = val
    return val
  }

  ** Iterate variables in this frame
  Void each(|Obj? v, Str n| f) { vars.each(f) }

  ** Convert frame variables to debug dict
  Dict toDict()
  {
    acc := Str:Obj?[:]
    vars.each |v, n|
    {
      if (v != null && !v.isImmutable) v = v.toStr
      acc[n] = v
    }
    return Etc.makeDict(acc)
  }

  ** Does the given function have variable visibility into
  ** this frame's variables?  Only if the function is lexically
  ** scoped inside this frame's function, or this is a top level frame.
  Bool isVisibleTo(Fn? f)
  {
    while (f != null)
    {
      if (this.func === f) return true
      f = f.outer
    }
    return mode.isTopLevel
  }

  ** Debug string
  override Str toStr() { "AxonFrame $func.name [$callLoc]" }

  private static const Fn rootFunc := Fn(FileLoc("root"), "root", FnParam[,])

  const FileLoc callLoc
  const Fn func
  const CallFrameMode mode
  AxonFrame? parent  // next frame in lexical scope or null if root
  private Str:Obj? vars
}

**************************************************************************
** CallFrameMode
**************************************************************************

**
** CallFrameMode is the kind of call frame
**
@NoDoc @Js
enum class CallFrameMode
{
  fn,    // func call: visible only to lexically enclosed funcs
  top,   // top level eval or root: visible to every func
  repl;  // top level REPL session such as AI eval: defines rebind

  ** Top level frame of an eval such as root is visible to every func
  Bool isTopLevel() { this !== fn }

  ** Define of an existing var rebinds it instead of raising an error
  Bool redefineOk() { this === repl }
}

