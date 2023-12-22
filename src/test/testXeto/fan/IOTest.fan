//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Oct 2023  Brian Frank  Creation
//

using util
using xeto
using xeto::Dict
using xetoEnv
using haystack
using haystack::Ref

**
** IOTest tests ability to serialize specs/data over Xeto text and binary I/O
**
@Js
class IOTest : AbstractXetoTest
{
  TestTransport? client
  TestTransport? server

  Void test()
  {
    env.lib("ph")
    server = TestTransport.makeServer(env)
    client = TestTransport.makeClient(server)
    client.bootRemoteEnv

    verifyIO(null)
    verifyIO(Marker.val)
    verifyIO(NA.val)
    verifyIO(Remove.val)
    verifyIO("foo")
    verifyIO(n(123))
    verifyIO(n(123, "°F"))
    verifyIO(n(123, "_foo"))
    verifyIO(Number.posInf)
    verifyIO(Number.negInf)
    verifyIO(Number.nan)
    verifyIO(`foo/bar`)
    verifyIO(true)
    verifyIO(Date.today)
    verifyIO(Time.now)
    verifyIO(DateTime.now)
    verifyIO(DateTime("2023-11-17T07:46:32.573-05:00 New_York"))
    verifyIO(haystack::Ref("foo"))
    verifyIO(haystack::Ref("foo-bar:baz~qux"))
    verifyIO(haystack::Ref("foo", "Foo Dis"))
    verifyIO(123)
    verifyIO(-32_000)
    verifyIO(123567890)
    verifyIO(-1235678903)
    verifyIO(123f)
    verifyIO(123min)
    verifyIO(Version("1.2.3"))
    verifyIO(Etc.dict0)
    verifyIO(Etc.dict1("foo", m))
    verifyIO(Etc.dict2("foo", m, "bar", n(123)))
    verifyIO(Obj?[,])
    verifyIO(Obj?["a"])
    verifyIO(Obj?["a", n(123)])
    verifyIO(Obj?["a", null, n(123)])
    verifyIO(haystack::Coord(12f, -34f))
    verifyIO(haystack::Symbol("foo-bar"))

    a := env.instantiate(env.spec("ph::AcElecMeter"))
    b := env.dict(["spec":Ref("ph::Rtu"), "dis":"RTU", "equip":m, "ahu":m, "rtu":m])
    verifyIO(a)
    verifyIO(b)
    verifyIO([a, b])
    verifyIO(["foo", n(123), a, b])

    a = Etc.dictSet(a, "id", Ref.gen)
    b = Etc.dictSet(b, "id", Ref.gen)
    verifyIO(a)
    verifyIO(b)
    verifyIO([a, b])
    verifyIO(["foo", n(123), a, b])
  }

  Void verifyIO(Obj? val)
  {
    // binary format
    buf := Buf()
    XetoBinaryWriter(server, buf.out).writeVal(val)
    //echo("--> $val [$buf.size bytes]")
    x := XetoBinaryReader(client, buf.flip.in).readVal
    verifyValEq(val, x)

    // Xeto format does not support null
    if (val == null) return null
    list := val as Obj?[]
    if (list != null)
    {
      if (list.contains(null)) return
      if (!list.isEmpty && list.all { it is xeto::Dict })
        val = xeto::Dict[,].addAll(list)
      else
        val = Obj[,].addAll(list)
    }

    // xeto text format
    buf.clear
    env.writeData(buf.out, val)
    str := buf.flip.readAllStr
    opts := env.dict1("externRefs", m)
    x = env.compileData(str, opts)
    verifyValEq(val, x)

    // compileDicts
    if (val is Dict)
    {
      dicts := env.compileDicts(str, opts)
      verifyEq(dicts.size, 1)
      verifyDictEq(dicts[0], val)
    }
    else if (val is List && ((List)val).all { it is Dict })
    {
      dicts := env.compileDicts(str, opts)
      verifyDictsEq(dicts, val)
    }
    else
    {
      verifyErr(IOErr#) { env.compileDicts(str, opts) }
    }
  }
}