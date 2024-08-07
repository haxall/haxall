//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Aug 2024  Brian Frank  Creation
//

using xeto
using xeto::Lib
using haystack::Dict

**
** JSON Exporter
**
@Js
class JsonExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts) : super(ns, out, opts)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Api
//////////////////////////////////////////////////////////////////////////

  override This start()
  {
    w("{").nl
  }

  override This end()
  {
    nl.w("}").nl
  }

  override This lib(Lib lib)
  {
    top(lib.name)
    topEnd
    return this
  }

  override This spec(Spec spec)
  {
    top(spec.qname)
    topEnd
    return this
  }

  override This instance(Dict instance)
  {
    top(instance.id.id)
    topEnd
    return this
  }

  private Void top(Str name)
  {
    // start top-level definition
    if (first) first = false
    else w(",").nl.nl
    str(name).w(": {").nl
  }

  private Void topEnd()
  {
    // end top-level definition
    indention--
    w("}")
  }

  private This str(Str s)
  {
    w(s.toCode)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  Bool first := true
}

