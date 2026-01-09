//
// Copyright (c) 2026, Brian Frank
// All Rights Reserved
//
// History:
//   9 Jan 2026  Mike Jarmy
//

using util
using xeto
using xetom
using haystack

**
** JsonTest
**
@Js
class JsonTest : AbstractXetoTest
{
  // make sure the spec tag is written first
  Void testSpec()
  {
    ns   := createNamespace(["hx.test.xeto"])
    spec := ns.spec("hx.test.xeto::Fidelity")
    a    := ns.instance("hx.test.xeto::fidelityA")

    buf := Buf()
    XetoJsonWriter(buf.out, Etc.dict1("pretty", m)).writeVal(a)
    str := buf.flip.readAllStr
    //echo(str)
    verifyEq(
      str.split('\n', false)[1],
      "  \"spec\":\"hx.test.xeto::Fidelity\",")
  }
}

