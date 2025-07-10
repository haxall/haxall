//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Apr 2025  Brian Frank  Creation
//

using xeto

**
** Debug dump Exporter
**
@Js
class DumpExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts) : super(ns, out, opts)
  {
    this.printer = Printer(ns, out, opts)
  }

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  override This start()
  {
    return this
  }

  override This end()
  {
    nl
    return this
  }

  override This lib(Lib lib)
  {
    printer.val(lib)
    lib.specs.each |x|
    {
      printer.nl.nl
      spec(x)
    }
    lib.instances.each |x|
    {
      printer.nl.nl
      instance(x)
    }
    return this
  }

  override This spec(Spec spec)
  {
    printer.val(spec)
    return this
  }

  override This instance(Dict instance)
  {
    printer.val(instance)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Printer printer
}

