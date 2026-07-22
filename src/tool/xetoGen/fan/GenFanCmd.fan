//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Generate Fantom source code from xeto specs.  Fantom types and
** slots tagged with the '@Gen' facet are kept in sync with their
** specs: tagged slots are regenerated in place, slots missing from
** the source are inserted, and tagged slots no longer declared by
** the spec are removed.
**
class GenFanCmd : XetoCmd
{
  override Str cmdName() { "gen-fan" }

  override Str summary() { "Generate Fantom source code from xeto specs" }

  @Opt { help = "Report what would change without writing any files" }
  Bool preview

  @Opt { help = "Dump the parsed AST to the console" }
  Bool dump

  @Arg { help = "Lib names to generate; default is all matched pods in working dir" }
  Str[]? libs

  override Int run()
  {
    c := GenCompiler
    {
      it.libNames = this.libs
      it.preview  = this.preview
    }
    try
    {
      c.compile
      if (dump) c.dump
      return 0
    }
    catch (Err e)
    {
      return err("Compile failed [$c.errs.size errors]")
    }
  }
}

