//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jun 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** CompanionCompiler drives partial compilation of the companion lib.  It wraps
** the strict compiler pipeline in a quarantine loop: compile the candidate rec
** set, and if it fails, mark every rec that errored with an error status and
** recompile.  The parser skips recs already in error, so each pass sees only
** the still-ok recs.  This isolates a bad rec so the rest of the companion lib
** still loads, with per-rec status recorded on each [CompanionRec].
**
** The dependency cascade is automatic: marking a bad base spec in error makes
** its subtypes fail to resolve on the next pass, so they get quarantined
** naturally without any dependency graph.
**
@Js
internal class CompanionCompiler
{
  ** Construct for one companion compile
  new make(MEnv env, MNamespace ns, LibVersion version)
  {
    this.env     = env
    this.ns      = ns
    this.version = version
    this.recs    = ns.companionRecs
  }

  ** Run the quarantine loop and return the (possibly partial) companion lib.
  ** Per-rec status is recorded on each CompanionRec.  Throws if the lib fails
  ** in a way that cannot be fixed by trimming recs (whole-lib failure).
  XetoLib compile()
  {
    // every rec starts ok for this fresh compile
    recs.reset

    // loop until we have quarantined all bad recs
    while (true)
    {
      // try to compile; parser skips recs already marked in error
      c := env.initCompiler(ns, version)
      lib := tryCompile(c)
      if (lib != null) return lib  // clean compile of the ok subset

      // attribute the failing stage's errors to recs by FileLoc.file (rec id)
      errsByRec := groupByRec(c.errs)
      newlyBad := errsByRec.keys.findAll |CompanionRec rec->Bool| { rec.status.isOk }

      // no newly bad error means nothing to quarantine, this is a whole-lib failure
      if (newlyBad.isEmpty)
        throw c.errs.first ?: Err("Companion lib failed with no attributable error")

      // mark all recs that errored this pass
      newlyBad.each |rec|
      {
        errs := errsByRec[rec].map |e->CompanionRecErr| { CompanionRecErr(e.msg, e.loc) }
        rec.setErr(errs)
      }

      // everything is now in error -> recompile empty set (succeeds ok)
    }
    throw Err("unreachable")
  }

  ** Compile, swallowing the bomb; return lib on success or null on error
  private XetoLib? tryCompile(XetoCompiler c)
  {
    try
      return c.compileLib
    catch (XetoCompilerErr e)
      return null
  }

  ** Group accumulated errors by the rec they are attributed to.  Companion
  ** recs parse under FileLoc(rec.id.id), so loc.file is the rec id string.
  ** Errors that do not map to a rec (lib-global) are dropped here
  private CompanionRec:XetoCompilerErr[] groupByRec(XetoCompilerErr[] errs)
  {
    acc := CompanionRec:XetoCompilerErr[][:]
    errs.each |e|
    {
      rec := recs.rec(Ref.fromStr(e.loc.file), false)
      if (rec == null) return
      acc.getOrAdd(rec) { XetoCompilerErr[,] }.add(e)
    }
    return acc
  }

  private const MEnv env
  private const MNamespace ns
  private const LibVersion version
  private const CompanionRecs recs
}

