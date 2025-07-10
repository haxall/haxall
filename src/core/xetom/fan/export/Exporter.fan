//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Aug 2024  Brian Frank  Creation
//

using concurrent
using util
using xeto

**
** Exporter
**
@Js
abstract class Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts)
  {
    this.ns          = ns
    this.out         = out
    this.opts        = opts
    this.indentation = XetoUtil.optInt(opts, "indent", 0)
    this.isEffective = XetoUtil.optBool(opts, "effective", false)
  }

//////////////////////////////////////////////////////////////////////////
// Api
//////////////////////////////////////////////////////////////////////////

  ** Start export
  abstract This start()

  ** End export
  abstract This end()

  ** Export one library and all its specs and instances
  abstract This lib(Lib lib)

  ** Export one spec
  abstract This spec(Spec spec)

  ** Export one instance
  abstract This instance(Dict instance)

  ** Iterate all the lib instances which are not nested
  internal Dict[] nonNestedInstances(Lib lib)
  {
    instances := lib.instances
    if (instances.isEmpty) return instances

    // first build map of all instances
    acc := Ref:Dict[:]
    instances.each |x| { acc[x->id] = x }

    // now recursively walk thru removing nested instances
    instances.each |x| { removeNested(acc, x, 0) }

    return acc.vals
  }

  private static Void removeNested(Ref:Dict acc, Dict x, Int level)
  {
    if (level > 0)
    {
       id := x["id"] as Ref
       if (id != null) acc.remove(id)
    }

    x.each |v|
    {
      if (v is Dict) removeNested(acc, v, level+1)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Write Utils
//////////////////////////////////////////////////////////////////////////

  This w(Obj obj)
  {
    str := obj.toStr
    out.print(str)
    return this
  }

  This wc(Int char)
  {
    out.writeChar(char)
    return this
  }

  This nl()
  {
    out.printLine
    return this
  }

  This sp() { wc(' ') }

  This indent() { w(Str.spaces(indentation*2)) }

  This flush() { out.flush; return this }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns             // namespace
  const Dict opts                 // options
  const Bool isEffective          // options
  const Ref specRef := Ref("sys::Spec")
  protected OutStream out         // output stream
  Int indentation                 // current level of indentation
}

