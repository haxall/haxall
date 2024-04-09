//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using haystack
using haystack::Ref

**
** CheckTest
**
@Js
class CheckTest : AbstractXetoTest
{

  Void testNumbers()
  {
    ns := createNamespace(["sys"])
    verifyNumber(ns, n(123), "<>", [,])
    verifyNumber(ns, n(123), "<minVal:123>", [,])
    // TODO
    // verifyNumber(n(123), "<minVal:124>", ["Min val too low"])
  }

  Void verifyNumber(LibNamespace ns, Number n, Str meta, Str[] errs)
  {
    // try all three ways:
    //   - instance with fits
    //   - lib slot defalut value
    //   - lib instance

    src :=
    """Foo: {
         n: Number $meta
       }"""

    // first try fits against lib
    lib := ns.compileLib(src, dict1("register", m))
    foo := lib.type("Foo")
    instance := dict(["dis":"A", "spec":Ref(foo.qname), "n":n])
    verifyFitsExplain(ns, instance, foo, errs)
  }
}

