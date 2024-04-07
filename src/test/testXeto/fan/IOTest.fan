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
  TestClient? client
  TestServer? server

  Void test()
  {
    ns := createNamespace(["sys", "ph"])
    env.lib("ph")
    server = TestServer(env)
    client = TestClient(server)
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

    a := ns.instantiate(ns.spec("ph::AcElecMeter"))
    b := dict(["spec":Ref("ph::Rtu"), "dis":"RTU", "equip":m, "ahu":m, "rtu":m])
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

    g := Etc.makeMapsGrid(["meta":"val"], [
        ["dis":"A", "foo":n(123)],
        ["dis":"B", "bar":m]
      ])
    g = g.addColMeta("dis", ["disMeta":m])
    verifyIO(g)
  }

  Void verifyIO(Obj? val)
  {
    // binary format
    buf := Buf()
    server.io.writer(buf.out).writeVal(val)
    // echo("--> $val [$buf.size bytes]")
    x := client.io.reader(buf.flip.in).readVal
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

    // for now don't try to map grids to Xeto text format...
    if (val is Grid) return

    // xeto text format
    buf.clear
    env.writeData(buf.out, val)
    str := buf.flip.readAllStr
    opts := dict1("externRefs", m)
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

