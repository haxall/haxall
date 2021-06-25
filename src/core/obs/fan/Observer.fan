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
@NoDoc
const mixin Observer
{
  ** Meta data for observer
  abstract Dict meta()

  ** Actor for observer
  abstract Actor actor()
}


