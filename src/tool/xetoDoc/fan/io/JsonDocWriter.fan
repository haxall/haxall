//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Encode documentation AST into JSON for serialization and long term storage
**
class JsonDocWriter : DocWriter
{
  new make(OutStream out)
  {
    this.out = out
  }

  override Void writeLib(DocLib lib)
  {
    out.printLine("// writeLib $lib")
    /*
    echo("### types")
    lib.types.each |x| { echo(x) }
    echo("### globals")
    lib.globals.each |x| { echo(x) }
    echo("### instances")
    lib.instances.each |x| { echo(x) }
    */
  }

  override Void writeType(DocSpec type)
  {
  }

  private OutStream out
}

