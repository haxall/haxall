//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Nov 2024  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetom
using haystack

internal class FitsCmd : XetoCmd
{
  override Str name() { "fits" }

  override Str summary() { "Validate input data against configured specs" }

  @Opt { help = "Check graph of query references such as required points" }
  Bool graph

  @Opt { help = "Ignore if refs resolve to valid target in input data set" }
  Bool ignoreRefs

  @Opt { help = "Output to file, use 'stdout.zinc' for stdout (must have zinc, trio, json ext)" }
  File? outFile

  @Arg { help = "Input file (must have zinc, trio, json extension)" }
  File? input

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto $name recs.zinc            // Validate Zinc input file")
    out.printLine("  xeto $name recs.json            // Validate Hayson input file")
    out.printLine("  xeto $name recs.trio            // Validate Trio input file")
    out.printLine("  xeto $name recs.trio -graph     // Validate graph queries")
    out.printLine("  xeto $name recs.json -outFile stdout.zinc  // Output zinc to stdout")
    return 1
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    readInput
    loadNamespace
    runFits
    writeOutput
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Parse Input
//////////////////////////////////////////////////////////////////////////

  private Void readInput()
  {
    this.recsById = Ref:Dict[:] { ordered = true }
    readInputFile(input).each |rec, i|
    {
      id := rec["id"] as Ref
      if (id == null)
      {
        id =  Ref(i.toStr)
        rec = Etc.dictSet(rec, "id", id)
      }
      recsById.add(id, rec)
    }
    this.recs = recsById.vals
    if (outFile == null) echo("Read Inputs [$recs.size recs]")
  }

//////////////////////////////////////////////////////////////////////////
// Load Namespace
//////////////////////////////////////////////////////////////////////////

  private Void loadNamespace()
  {
    this.ns = XetoEnv.cur.createNamespaceFromData(recs)
    if (outFile == null) echo("Load Namespace [$ns.libs.size libs]")
  }

//////////////////////////////////////////////////////////////////////////
// Run Fits
//////////////////////////////////////////////////////////////////////////

  private Void runFits()
  {
    this.hits = XetoLogRec[,]
    logger := |XetoLogRec rec| { hits.add(rec) }

    optsMap := Str:Obj[:]
    optsMap["explain"] = Unsafe(logger)
    optsMap["haystack"] = Marker.val // force use for haystack level fidelity
    if (graph) optsMap["graph"] = Marker.val
    if (ignoreRefs) optsMap["ignoreRefs"] = Marker.val
    opts := Etc.makeDict(optsMap)

    recs.each |rec|
    {
      id := rec.id
      startSize := hits.size

      specTag := rec["spec"] as Ref
      if (specTag == null)
      {
        logger(XetoLogRec(LogLevel.err, id, "Missing 'spec' ref tag", FileLoc.unknown, null))
        numErr++
        return
      }

      spec := ns.spec(specTag.id, false)
      if (spec == null)
      {
        logger(XetoLogRec(LogLevel.err, id, "Unknown 'spec' ref: $specTag", FileLoc.unknown, null))
        numErr++
        return
      }

      cx := FitsCmdContext(this)
      Actor.locals[ActorContext.actorLocalsKey] = cx
      ns.fits(rec, spec, opts)
      Actor.locals.remove(ActorContext.actorLocalsKey)

      if (hits.size == startSize)
        numOk++
      else
        numErr++
    }
  }

//////////////////////////////////////////////////////////////////////////
// Write Ouput
//////////////////////////////////////////////////////////////////////////

  private Void writeOutput()
  {
    if (outFile == null)
      writeConsole(Console.cur)
    else
      writeFile
  }

  private Void writeConsole(Console con)
  {
    table := Obj[][,]
    table.add(["id", "dis", "msg"])
    hits.each |hit|
    {
      table.add([hit.id.id, hit.id.dis, hit.msg])
    }

    con.info("")
    con.table(table)
    con.info("")
    con.info("Num recs ok:  $numOk")
    con.info("Num recs err: $numErr")
    con.info("")
  }

  private Void writeFile()
  {
    gb := GridBuilder()
    gb.addCol("id").addCol("msg")
    hits.each |hit|
    {
      gb.addRow2(hit.id, hit.msg)
    }
    writeOutputFile(outFile, gb.toGrid)
  }

//////////////////////////////////////////////////////////////////////////
// Files
//////////////////////////////////////////////////////////////////////////

  internal Dict[]? recs             // readInput
  internal [Ref:Dict]? recsById     // readInput
  internal Namespace? ns            // loadNamespace
  internal XetoLogRec[]? hits       // runFits
  private Int numOk                 // runFits
  private Int numErr                // runFits

}

**************************************************************************
** FitsCmdContext
**************************************************************************

internal class FitsCmdContext : XetoContext
{
  new make(FitsCmd cmd) { this.cmd = cmd }

  override xeto::Dict? xetoReadById(Obj id)  { cmd.recsById.get(id) }

  override Obj? xetoReadAllEachWhile(Str filter, |xeto::Dict->Obj?| f)  { throw Err() }

  override Bool xetoIsSpec(Str spec, xeto::Dict rec) { throw Err() }

  FitsCmd cmd
}

