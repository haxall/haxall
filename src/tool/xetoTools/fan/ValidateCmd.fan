//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetom
using haystack

**
** ValidateCmd validates input data using the validation engine
**
internal class ValidateCmd : XetoCmd
{
  override Str cmdName() { "validate" }

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
    n := cmdName
    out.printLine("Examples:")
    out.printLine("  xeto $n recs.zinc            // Validate Zinc input file")
    out.printLine("  xeto $n recs.json            // Validate Hayson input file")
    out.printLine("  xeto $n recs.trio            // Validate Trio input file")
    out.printLine("  xeto $n recs.trio -graph     // Validate graph queries")
    out.printLine("  xeto $n recs.json -outFile stdout.zinc  // Output zinc to stdout")
    return 1
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    readInput
    loadNamespace
    runValidate
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
        id = Ref(i.toStr)
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
    this.ns = XetoEnv.cur.deriveNamespace(recs)
    if (outFile == null) echo("Load Namespace [$ns.libs.size libs]")
  }

//////////////////////////////////////////////////////////////////////////
// Run Validate
//////////////////////////////////////////////////////////////////////////

  private Void runValidate()
  {
    optsMap := Str:Obj[:]
    optsMap["haystack"] = Marker.val // input files are haystack fidelity
    if (graph) optsMap["graph"] = Marker.val
    if (ignoreRefs) optsMap["ignoreRefs"] = Marker.val

    cx := DataCmdContext(recsById, recs)
    Actor.locals[ActorContext.actorLocalsKey] = cx
    this.report = ns.validateAll(recs, Etc.makeDict(optsMap))
    Actor.locals.remove(ActorContext.actorLocalsKey)
  }

//////////////////////////////////////////////////////////////////////////
// Write Output
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
    table.add(["id", "dis", "level", "slot", "msg"])
    report.items.each |item|
    {
      id := item.subjectId
      table.add([id?.id, id?.dis, item.level.name, item.slot, item.msg])
    }

    numWarn := 0; numErr := 0
    recs.each |rec|
    {
      items := report.itemsForSubject(rec)
      if (items.isEmpty) return
      if (items.any |item| { item.level.isErr }) numErr++
      else numWarn++
    }

    con.info("")
    con.table(table)
    con.info("")
    con.info("Num recs ok:   ${recs.size - numWarn - numErr}")
    con.info("Num recs warn: $numWarn")
    con.info("Num recs err:  $numErr")
    con.info("")
  }

  private Void writeFile()
  {
    gb := GridBuilder()
    gb.addCol("id").addCol("level").addCol("slot").addCol("msg")
    report.items.each |item|
    {
      gb.addRow([item.subjectId, item.level.name, item.slot, item.msg])
    }
    writeOutputFile(outFile, gb.toGrid)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  internal Dict[]? recs             // readInput
  internal [Ref:Dict]? recsById     // readInput
  internal Namespace? ns            // loadNamespace
  private ValidateReport? report    // runValidate
}

**************************************************************************
** DataCmdContext
**************************************************************************

** Context to resolve refs and filters against the input data set
internal class DataCmdContext : HaystackContext
{
  new make([Ref:Dict] recsById, Dict[] recs)
  {
    this.recsById = recsById
    this.recs = recs
  }

  override xeto::Dict? xetoReadById(Obj id) { recsById.get(id) }

  override Obj? xetoReadAllEachWhile(Str filter, |xeto::Dict->Obj?| f)
  {
    x := Filter(filter)
    return recs.eachWhile |rec|
    {
      x.matches(rec) ? f(rec) : null
    }
  }

  override Bool xetoIsSpec(Str spec, xeto::Dict rec) { throw Err() }

  override xeto::Dict? deref(Ref id) { recsById.get(id) }

  override FilterInference inference() { FilterInference.nil }

  override xeto::Dict toDict() { Etc.dict0 }

  [Ref:Dict] recsById
  Dict[] recs
}
