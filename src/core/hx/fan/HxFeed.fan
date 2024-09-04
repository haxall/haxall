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
using haystack::Dict
using axon
using folio

**
** HxFeed manages a data stream subscription for one client side view
**
@NoDoc
abstract const class HxFeed
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(HxContext cx)
  {
    this.rt     = cx.rt
    this.viewId = cx.feedViewId
    this.key    = cx.feedKey
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** View id for client side view component
  const Str viewId

  ** Key to uniquely identifies the feed
  const Str key

  ** Runtime reference
  const HxRuntime rt

  ** Debug string
  override Str toStr() { "$typeof.name $key" }

//////////////////////////////////////////////////////////////////////////
// Lifecycle Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Subscribe and return initial data
  virtual Obj subscribe(Dict req, HxContext cx)
  {
    throw UnsupportedErr("${typeof}.subscribe")
  }

  ** Poll for new data or null if no new data
  abstract Obj? poll(HxContext cx)

  ** Unsubscribe and cleanup resources
  virtual Void unsubscribe() {}

  ** Invoke an call operation on a feed
  virtual Obj? call(Dict req, HxContext cx)
  {
    throw UnsupportedErr("${typeof}.call")
  }

}

