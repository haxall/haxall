//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Mar 2026  Matthew Giannini  Creation
//

using util
using xeto
using xetom
using haystack
using hx

/*
internal class StubResourceCli : StubCli
{

//////////////////////////////////////////////////////////////////////////
// Options
//////////////////////////////////////////////////////////////////////////

  @Arg { help = "Xeto lib name to create (e.g. acme.fooresource)" }
  Str? libName

//////////////////////////////////////////////////////////////////////////
// StubCli
//////////////////////////////////////////////////////////////////////////

  override Str name() { "stub-res" }

  override Str summary() { "Stub a new Xeto resource library" }

  override protected Void init()
  {
    initXetoLibName(this.libName)
    super.init
  }

  override protected Void sanityChecks()
  {
    super.sanityChecks
    podName := XetoUtil.dottedToCamel(this.xetoLibName)
    if (Pod.find(podName, false) != null)
    {
      if (!promptConfirm("WARN: There exists a Fantom pod with name '${podName}' - Continue?"))
        throw StubErr("Generation cancelled")
    }
  }

  override protected Void stubFiles()
  {
    confirm
    genXetoLib
    genXetoDoc
    genXetoFuncs
  }

  private Void confirm()
  {
    printLine("=== Stub Xeto Resource Lib ${xetoLibName.toCode} ===")
    printLine("Author: ${author}")
    printLine("Summary: ${desc}")
    printLine

    listGeneratedFiles
    if (!promptConfirm("Continue?")) throw StubErr("Cancelled")
  }
}
*/
