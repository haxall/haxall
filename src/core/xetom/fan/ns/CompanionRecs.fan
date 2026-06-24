//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jun 2026  Brian Frank  Split out of MNamespace
//

using concurrent
using util
using xeto
using haystack

**
** CompanionRecs is the set of records that compose the companion ("proj") lib.
** Each rec carries a mutable per-rec status (see `CompanionRec`) so that partial
** compilation can mark individual recs in error while the rest of the lib still
** loads.  The lib-level rollup is the namespace's normal `LibStatus`; the count
** of recs in error is computed by walking the recs.
**
@Js
const class CompanionRecs
{
  ** Construct with list of recs and thunks to reuse.  Dicts without a 'name'
  ** tag are silently skipped: a nameless rec cannot compile to a valid spec,
  ** func, or instance, so it has no place in the companion lib.
  new make(Dict[] recs, Str:Thunk thunks)
  {
    list := CompanionRec[,]
    byId := Ref:CompanionRec[:]
    recs.each |dict|
    {
      name := dict["name"] as Str
      if (name == null) return
      rec := CompanionRec(dict, name)
      list.add(rec)
      byId[rec.id] = rec
    }
    this.list    = list
    this.byIdMap = byId
    this.thunks  = thunks
  }

  ** Companion recs
  const CompanionRec[] list

  ** Thunks to reuse by spec name
  const Str:Thunk thunks

  ** Lookup rec by id
  CompanionRec? rec(Ref id, Bool checked := true)
  {
    r := byIdMap[id]
    if (r != null) return r
    if (checked) throw UnknownRecErr(id.toStr)
    return null
  }

  ** Iterate the recs
  Void each(|CompanionRec| f) { list.each(f) }

  ** Recs currently in error
  CompanionRec[] errRecs() { list.findAll |r| { r.status.isErr } }

  ** Number of recs currently in error
  Int numErrs() { errRecs.size }

  ** Are any recs currently in error
  Bool hasErrs() { list.any |r| { r.status.isErr } }

  ** Reset every rec back to ok status (start of a fresh compile)
  Void reset() { list.each |r| { r.reset } }

  private const Ref:CompanionRec byIdMap
}

**************************************************************************
** CompanionRec
**************************************************************************

**
** CompanionRec wraps one companion record dict with a mutable status.  The
** status starts `CompanionRecStatus.ok` and is set to error by the partial
** compilation driver when the rec (or a rec it depends on) fails to compile.
**
@Js
const class CompanionRec
{
  ** Construct ok wrapping the given dict with its (non-null) name
  internal new make(Dict rec, Str name)
  {
    this.rec  = rec
    this.id   = rec.id
    this.name = name
    this.loc  = FileLoc(id.id)
  }

  ** Underlying record dict
  const Dict rec

  ** Record id
  const Ref id

  ** Spec/func/instance name
  const Str name

  ** File location used when this rec is parsed/compiled.  Errors are attributed
  ** back to this rec via 'loc.file', so this is the single source of truth for
  ** the rec<->loc mapping (the id, which is unique even across recs that share
  ** a name).
  const FileLoc loc

  ** Is this rec a function (rt == "func")
  Bool isFunc() { rec["rt"] == "func" }

  ** Current status (mutable; starts ok)
  CompanionRecStatus status() { statusRef.val }

  ** Mark this rec in error with the given errors
  Void setErr(CompanionRecErr[] errs)
  {
    statusRef.val = CompanionRecStatus.makeErr(errs)
  }

  ** Reset back to ok status
  Void reset() { statusRef.val = CompanionRecStatus.ok }

  private const AtomicRef statusRef := AtomicRef(CompanionRecStatus.ok)

  override Str toStr() { "$name [$status]" }
}

**************************************************************************
** CompanionRecStatus
**************************************************************************

**
** CompanionRecStatus is the per-rec status: either ok, or err carrying the
** compiler errors for the rec.
**
@Js
const class CompanionRecStatus
{
  ** The ok singleton
  static const CompanionRecStatus ok := make(CompanionRecErr#.emptyList)

  ** Construct an error status
  internal static new makeErr(CompanionRecErr[] errs) { make(errs) }

  private new make(CompanionRecErr[] errs) { this.errs = errs }

  ** Compiler errors for this rec (empty if ok)
  const CompanionRecErr[] errs

  ** Is this ok (no errors)
  Bool isOk() { errs.isEmpty }

  ** Is this in error
  Bool isErr() { !errs.isEmpty }

  override Str toStr() { isOk ? "ok" : "err ($errs.size)" }
}

**************************************************************************
** CompanionRecErr
**************************************************************************

**
** CompanionRecErr is a single compiler error message with its source location,
** flattened from a compiler error for the rec status.
**
@Js
const class CompanionRecErr
{
  ** Construct with message and location
  new make(Str msg, FileLoc loc) { this.msg = msg; this.loc = loc }

  ** Error message
  const Str msg

  ** Source location of the error
  const FileLoc loc

  override Str toStr() { "$msg [$loc]" }
}

