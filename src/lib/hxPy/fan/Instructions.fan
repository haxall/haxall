//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jul 2021  Matthew Giannini  Creation
//

using haystack

**************************************************************************
** Instr
**************************************************************************

internal abstract const class Instr
{
  abstract Dict encode()
}

**************************************************************************
** DefineInstr
**************************************************************************

  internal const class DefineInstr : Instr
  {
    new make(Str name, Obj? val)
    {
      this.name = name
      this.val = toVal(val)
    }

    const Str name
    const Obj? val

    override Dict encode() { Etc.makeDict2("def",name, "v",toVal(val)) }

    private static Obj? toVal(Obj? val)
    {
      val is Grid ? NDArray.encode(val) : val
    }
  }

**************************************************************************
** ExecInstr
**************************************************************************

  internal const class ExecInstr : Instr
  {
    new make(Str code) { this.code = code }

    const Str code

    override Dict encode() { Etc.makeDict1("exec", code) }
  }

**************************************************************************
** EvalInstr
**************************************************************************

internal const class EvalInstr : Instr
{
  new make(Str expr) { this.expr = expr }

  const Str expr

  override Dict encode() { Etc.makeDict1("eval", expr) }
}