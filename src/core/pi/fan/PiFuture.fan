//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Oct 2025  Brian Frank  Creation
//   12 Sep 2026  Brian Frank  Move from ion as PiFuture
//

using concurrent
using util
using xeto
using haystack

**
** Future with conveniences for presentation model and user interface
**
@Js
const class PiFuture : Future
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Wrapper constructor
  @NoDoc new make(Future w := Future.makeCompletable) : super(w) {}

//////////////////////////////////////////////////////////////////////////
// Future
//////////////////////////////////////////////////////////////////////////

  ** Wrap
  @NoDoc override This wrap(Future w) { make(w) }

//////////////////////////////////////////////////////////////////////////
// Callback Registration
//////////////////////////////////////////////////////////////////////////

  ** Register callback to handle when future completes successfully.
  ** Return result to chain to next future.
  This onOk(|Obj?->Obj?| cb)
  {
    cbOkRef.val = Unsafe(cb)
    return cbThen
  }

  ** Register callback to handle when future completes with an error.
  ** Return result to chain to next future.
  This onErr(|Err->Obj?| cb)
  {
    cbErrRef.val = Unsafe(cb)
    return cbThen
  }

  ** Register a callback to handle both ok and error conditions
  ** Return result to chain to next future.
  This onComplete(|Err?,Obj?->Obj?| cb)
  {
    cbOkRef.val  = Unsafe(|Obj? r->Obj?| { cb(null, r) })
    cbErrRef.val = Unsafe(|Err e->Obj?| { cb(e, null) })
    return cbThen
  }

  ** Convenience to handle [onOk] with dict result.
  This onDict(|Dict?->Obj?| cb)
  {
    onOk(cb)
  }

  ** Convenience to handle [onOk] with grid result.
  This onGrid(|Grid?->Obj?| cb)
  {
    onOk(cb)
  }

  ** Convenience to handle [onOk] with item result.
  This onItem(|Item?->Obj?| cb)
  {
    onOk(cb)
  }

  ** Register callback to handle progress with message and/or a percent
  ** complete (0% to 100%). Return this instance.
  @NoDoc This onProgress(|Str? msg, Int? percent| cb)
  {
    cbProgressRef.val = Unsafe(cb)
    return this
  }


//////////////////////////////////////////////////////////////////////////
// Utilities
//////////////////////////////////////////////////////////////////////////

  ** Get the description of this future set via [describe]
  Str description()
  {
    descriptionRef.val
  }

  ** Set to summary message that describes the operation of this future
  This describe(Str msg)
  {
    descriptionRef.val = msg
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Completion Handling
//////////////////////////////////////////////////////////////////////////

  ** Complete with either err or ok
  @NoDoc This completeEither(Err? err, Obj? res)
  {
    err != null ? completeErr(err) : complete(res)
  }

  ** Setup then callbacks and return future to chain
  private This cbThen()
  {
    then(|Obj? r->Obj?| { thenOk(r) }, |Err e->Obj?| { thenErr(e) })
  }

  ** Handle ok completion
  private Obj? thenOk(Obj? res)
  {
    try
    {
      cb := cbOk
      if (cb != null) return cb(res)
      return null
    }
    catch (Err e)
    {
      Console.cur.err("Future onOk failed", e)
      throw e
    }
  }

  ** Handle error completion
  private Obj? thenErr(Err err)
  {
    cb := cbErr
    if (cb != null) return cb(err)

    msg := "$<futureFailed>: $descriptionRef"
    PiEnv.cur.flash(msg, err)
    throw err
  }

  ** Update progress
  @NoDoc This progress(Str? msg, Int? percent)
  {
    cb := cbProgress
    if (msg == null && percent != null) msg = "${percent}% $<complete>"
    if (cb != null) cb(msg, percent)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private |Obj?->Obj?|? cbOk()  { (cbOkRef.val as Unsafe)?.val }
  private |Err->Obj?|?  cbErr() { (cbErrRef.val as Unsafe)?.val }
  private |Str?,Int?|?  cbProgress() { (cbProgressRef.val as Unsafe)?.val }
  private const AtomicRef cbOkRef := AtomicRef()
  private const AtomicRef cbErrRef := AtomicRef()
  private const AtomicRef cbProgressRef := AtomicRef()
  private const AtomicRef descriptionRef := AtomicRef("async operation")
}

