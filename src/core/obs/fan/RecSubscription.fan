//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jul 2021  Brian Frank  Creation
//

using concurrent
using haystack

**
** RecSubscription is used for 'obsRecs' to handle filtering
**
** NOTE: this API is subject to change
**
const class RecSubscription : Subscription
{
  ** Constructor
  new make(Observable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
    this.filter = parseFilter(config["obsFilter"])
  }

  ** Parse the 'obsFilter' tag
  private static Filter? parseFilter(Obj? val)
  {
    if (val == null) return null
    if (val isnot Str)
    {
      if (val is Filter) return val
      throw Err("obsFilter must be filter string")
    }
    try
      return Filter.fromStr(val)
    catch (Err e)
      throw Err("obsFilter invalid: $e")
  }

  ** Filter is configured
  const Filter? filter

  ** Match the record against configured filter
  Bool include(Dict rec)
  {
    if (rec.isEmpty) return false
    if (filter == null) return true
    return filter.matches(rec)
  }
}

