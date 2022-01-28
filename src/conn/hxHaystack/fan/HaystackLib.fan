//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jan 2012  Brian Frank  Creation
//   23 Jun 2021  Brian Frank  Redesign for Haxall
//

using hx
using hxConn

**
** Haystack connector library
**
const class HaystackLib : ConnLib
{
  override Str onConnDetails(Conn c)
  {
    rec     := c.rec
    uri     := rec["uri"]
    product := "" + rec["productName"] + " " + rec["productVersion"]
    module  := "" + rec["moduleName"]  + " " + rec["moduleVersion"]
    vendor  := "" + rec["vendorName"]
    watch   := c.data as WatchInfo

    s := StrBuf()
    s.add("""uri:           $uri
             product:       $product
             module:        $module
             vendor:        $vendor
             watchId:       ${watch?.id}
             """)
    if (watch != null)
    s.add("""watchLeaseReq: ${watch?.leaseReq}
             watchLeaseRes: ${watch?.leaseRes}
             """)
    return s.toStr
  }
}


