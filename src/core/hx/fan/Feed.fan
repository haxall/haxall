//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Sep 2024  Brian Frank  Pull into separate file
//

using concurrent
using xeto
using haystack

**
** Feed manages a data stream subscription for one client side view
**
@NoDoc
abstract const class Feed
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor - must safe not perform any I/O or multi-threading!
  new make(Context cx)
  {
    init := cx.feedInit

    this.rt     = init.rt
    this.viewId = init.viewId
    this.key    = init.key
    this.log    = init.log
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** View id for client side view component
  const Str viewId

  ** Key to uniquely identifies the feed
  const Str key

  ** Sys or proj runtime
  const Runtime rt

  ** Debug string
  override Str toStr() { "$typeof.name $key" }

  ** Log to use for feed
  const Log log

//////////////////////////////////////////////////////////////////////////
// Lifecycle Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Subscribe and return initial data
  virtual Obj subscribe(Dict req, Context cx)
  {
    throw UnsupportedErr("${typeof}.subscribe")
  }

  ** Poll for new data or null if no new data
  abstract Obj? poll(Context cx)

  ** Unsubscribe and cleanup resources
  virtual Void unsubscribe() {}

  ** Invoke an call operation on a feed
  virtual Obj? call(Dict req, Context cx)
  {
    throw UnsupportedErr("${typeof}.call")
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Convenience for log.err
  Void err(Str msg, Err? err)
  {
    log.err("Feed $key: $msg", err)
  }

}

**************************************************************************
** FeedInit
**************************************************************************

@NoDoc
const class FeedInit
{
  new make(|This| f) { f(this) }
  const Runtime rt
  const Str viewId
  const Str key
  const Log log
}

