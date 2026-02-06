//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Feb 2026  Brian Frank  Creation
//

using xeto
using xetom
using haystack
using concurrent

**
** FixLinksTest
**
class FixLinksTest : HaystackTest
{
  Void test()
  {
    fixer = FixLinks.load
    base = "docHaystack::Overview"
    verifyFix("now()", "now()")
    verifyFix("docHaystack::Overview", "ph.doc::Overview")
    verifyFix("docHaystack::Filters", "ph.doc::Filters")
    verifyFix("docHaystack::Filters#numbers", "ph.doc::Filters#number-comparisons")
    verifyFix("docHaystack::Filters#notfound", "ph.doc::Filters#notfound")
    verifyFix("Filters#numbers", "Filters#number-comparisons")
    verifyFix("Filters#notfound", "Filters#notfound")
  }

  Void verifyFix(Str v3, Str v4)
  {
    x := fixer.fix(base, v3)
    // echo("--> $v3 => $x")
    verifyEq(v4, x)
  }

  FixLinks? fixer
  Str base := ""
}

