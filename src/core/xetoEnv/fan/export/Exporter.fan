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
using xeto::Lib
using haystack::Dict

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
    this.ns        = ns
    this.out       = out
    this.opts      = opts
    this.indention = XetoUtil.optInt(opts, "indent", 0)
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

  This indent() { w(Str.spaces(indention*2)) }

  This flush() { out.flush; return this }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns             // namespace
  const Dict opts                 // options
  private OutStream out           // output stream
  Int indention                  // current level of indentation
}

