//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack::Etc
using haystack::Marker

internal class FitsCmd : XetoCmd
{
  override Str name() { "fits" }

  override Str summary() { "Validate input data against configured specs" }

  @Arg { help = "Input file" }
  File? input

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    readInput
    loadNamespace
    runFits
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Parse Input
//////////////////////////////////////////////////////////////////////////

  private Void readInput()
  {
    this.recs = readInputFile(input)
    this.recsById = Ref:Dict[:]
    recs.each |rec|
    {
      id := rec["id"] as Ref
      if (id == null) echo("WARN: input rec missing id: $rec")
      else recsById.add(id, rec)
    }
    echo("Read Inputs [$recs.size recs]")
  }

//////////////////////////////////////////////////////////////////////////
// Load Namespace
//////////////////////////////////////////////////////////////////////////

  private Void loadNamespace()
  {
    this.ns = LibRepo.cur.createFromData(recs)
    echo("Namesapce [$ns.libs.size libs")
  }

//////////////////////////////////////////////////////////////////////////
// Run Fits
//////////////////////////////////////////////////////////////////////////

  private Void runFits()
  {
    this.hits = XetoLogRec[,]
    logger := |XetoLogRec rec|
    {
      echo("~~ $rec")
      hits.add(rec)
    }

    optsMap := Str:Obj[:]
    optsMap["explain"] = Unsafe(logger)
    opts := Etc.makeDict(optsMap)

    recs.each |rec|
    {
      id := rec._id

      specTag := rec["spec"] as Ref
      if (specTag == null)
      {
        logger(XetoLogRec(LogLevel.err, id, "Missing 'spec' ref tag", FileLoc.unknown, null))
        return
      }

      spec := ns.spec(specTag.id, false)
      if (spec == null)
      {
        logger(XetoLogRec(LogLevel.err, id, "Unknown 'spec' ref: $specTag", FileLoc.unknown, null))
        return
      }

      ns.fits(FitsCmdContext(this), rec, spec, opts)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Files
//////////////////////////////////////////////////////////////////////////

  internal Dict[]? recs             // readInput
  internal [Ref:Dict]? recsById     // readInput
  internal LibNamespace? ns         // loadNamespace
  internal XetoLogRec[]? hits       // runFits
}

**************************************************************************
** FitsCmdContext
**************************************************************************

internal class FitsCmdContext : XetoContext
{
  new make(FitsCmd cmd) { this.cmd = cmd }

  override Dict? xetoReadById(Obj id)  { cmd.recsById.get(id) }

  override Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f)  { throw Err() }

  override Bool xetoIsSpec(Str spec, Dict rec) { throw Err() }

  FitsCmd cmd
}

