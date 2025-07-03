using haystack

class TurtleWriterTest : Test
{
  Buf b := Buf()
  TurtleWriter turtle(DefNamespace ns := compile, Buf buf := b)
  {
    TurtleWriter(buf.clear.out, Etc.makeDict1("ns", ns))
  }

  JsonLdWriter jsonld(DefNamespace ns := compile, Buf buf := b)
  {
    JsonLdWriter(buf.clear.out, Etc.makeDict1("ns", ns))
  }

  DefNamespace compile()
  {
    c := Type.find("defc::DefCompiler").make
    c->log->level = LogLevel.err
    return c->compileNamespace
  }

  Void test()
  {
    ds := compile
    w := turtle(ds)
    g := Etc.makeDictsGrid(null, [ds.def("xstr")])
    w.writeGrid(g)
    // echo(b.flip.readAllStr)
    // TODO: actual tests...

    // echo("---")
    // def := ds.def("number")
    // def.each |v,t| { echo("$t: $v ($v.typeof)") }
    // echo(.symbolToUri(def.symbol.toStr))

    // def := .def("equip")
    // echo(ds.symbolToUri("equip"))
    // def.each |v,t| { echo("$t: $v ($v.typeof)") }
    // (def["is"] as List).each { echo("$it ($it.typeof)") }
    // echo(def.lib.uri)
    // echo(ds.symbolToUri(def.lib.symbol.toStr))

    // def = ds.def(def.lib.symbol.toStr) as DefImpl
    // echo(def)
    // echo(def.lib.name)
    // echo(def.meta)

  }
}

