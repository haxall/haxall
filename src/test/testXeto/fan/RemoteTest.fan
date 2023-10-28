//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Oct 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack

**
** RemoteTest tests ability to serialize specs/data over Xeto binary I/O
**
@Js
class RemoteTest : AbstractXetoTest
{
  Void testIO()
  {
    s := TestTransport.makeServer(XetoEnv.cur)
    c := TestTransport.makeClient(s)
    c.bootRemoteEnv

    verifyIO(s, c, null)
    verifyIO(s, c, Marker.val)
    verifyIO(s, c, NA.val)
    verifyIO(s, c, Remove.val)
    verifyIO(s, c, "foo")
    verifyIO(s, c, n(123))
    verifyIO(s, c, n(123, "°F"))
    verifyIO(s, c, n(123, "_foo"))
    verifyIO(s, c, Number.posInf)
    verifyIO(s, c, Number.negInf)
    verifyIO(s, c, Number.nan)
    verifyIO(s, c, `foo/bar`)
    verifyIO(s, c, true)
    verifyIO(s, c, Date.today)
    verifyIO(s, c, Time.now)
    verifyIO(s, c, DateTime.now)
    verifyIO(s, c, haystack::Ref("foo"))
    verifyIO(s, c, haystack::Ref("foo", "Foo Dis"))
    verifyIO(s, c, 123)
    verifyIO(s, c, -32_000)
    verifyIO(s, c, 123567890)
    verifyIO(s, c, -1235678903)
    verifyIO(s, c, 123f)
    verifyIO(s, c, 123min)
    verifyIO(s, c, Version("1.2.3"))
    verifyIO(s, c, Etc.dict0)
    verifyIO(s, c, Etc.dict1("foo", m))
    verifyIO(s, c, Etc.dict2("foo", m, "bar", n(123)))
    verifyIO(s, c, Obj?[,])
    verifyIO(s, c, Obj?["a"])
    verifyIO(s, c, Obj?["a", n(123)])
    verifyIO(s, c, Obj?["a", null, n(123)])
    verifyIO(s, c, haystack::Coord(12f, -34f))
    verifyIO(s, c, haystack::Symbol("foo-bar"))
  }

  Void verifyIO(XetoTransport s, XetoTransport c, Obj? val)
  {
    buf := Buf()
    XetoBinaryWriter(s, buf.out).writeVal(val)
    // echo("--> $val [$buf.size bytes]")
    x := XetoBinaryReader(c, buf.flip.in).readVal
    verifyValEq(val, x)
  }
}