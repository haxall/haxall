//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2020  Brian Frank  COVID-19!
//

using concurrent
using haystack

**
** Observer is an actor which subscribes to an observable's data items
**
** NOTE: this API is subject to change
**
const mixin Observer
{
  ** Meta data for observer
  abstract Dict meta()

  ** Actor for observer
  abstract Actor actor()

  ** Callback to translate an observation to an actor message.
  ** Default behavior is to pass the observation itself as the message.
  @NoDoc virtual Obj toActorMsg(Observation obs) { obs }

  ** Callback to get sync message.  Default uses null for sync message.
  @NoDoc virtual Obj? toSyncMsg() { null }

}



