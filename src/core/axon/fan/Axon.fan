//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Apr 2010  Brian Frank  Refactor axon vs axond
//

using xeto
using haystack

**
** Facet applied to methods which should be exposed as Axon functions.
**
@Js
facet class Axon : Define
{
  ** Mark a function as superuser only.
  const Bool su := false

  ** Marks a function as admin-only.  Any functions that modify the database
  ** or perform ad hoc I/O should set this field to true.  Functions with
  ** side effects should clearly document what side effects are.
  const Bool admin := false

  ** Meta data for the function encoded as a Trio string
  const Obj? meta

  ** Decode into meta tag name/value pairs
  @NoDoc override Void decode(|Str,Obj| f)
  {
    if (su) f("su", Marker.val)
    if (admin) f("admin", Marker.val)
    if (meta != null)
    {
      if (meta is Str)
      {
        TrioReader(meta.toStr.in).readDict.each |v, n| { f(n, v) }
      }
      else
      {
        ((Str:Obj)meta).each |v, n| { f(n, v) }
      }
    }
  }
}

