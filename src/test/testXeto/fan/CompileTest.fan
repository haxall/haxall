//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Feb 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** CompileTest
**
@Js
class CompileTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Scalars
//////////////////////////////////////////////////////////////////////////

  Void testScalars()
  {
    ns := createNamespace(["sys"])
    verifyScalar(ns, "sys::Marker",   Str<|Marker "marker"|>, m)
    verifyScalar(ns, "sys::Marker",   Str<|sys::Marker "marker"|>, m)
    verifyScalar(ns, "sys::None",     Str<|None "none"|>, none)
    verifyScalar(ns, "sys::None",     Str<|sys::None "none"|>, none)
    verifyScalar(ns, "sys::NA",       Str<|sys::NA "na"|>, na)
    verifyScalar(ns, "sys::Str",      Str<|"hi"|>, "hi")
    verifyScalar(ns, "sys::Str",      Str<|Str "123"|>, "123")
    verifyScalar(ns, "sys::Str",      Str<|sys::Str "123"|>, "123")
    verifyScalar(ns, "sys::Bool",     Str<|Bool "true"|>, true)
    verifyScalar(ns, "sys::Int",      Str<|Int "123"|>, 123)
    verifyScalar(ns, "sys::Int",      Str<|Int 123|>, 123)
    verifyScalar(ns, "sys::Int",      Str<|Int -123|>, -123)
    verifyScalar(ns, "sys::Float",    Str<|Float 123|>, 123f)
    verifyScalar(ns, "sys::Duration", Str<|Duration "123sec"|>, 123sec)
    verifyScalar(ns, "sys::Number",   Str<|Number "123kW"|>, n(123, "kW"))
    verifyScalar(ns, "sys::Number",   Str<|Number 123kW|>, n(123, "kW"))
    verifyScalar(ns, "sys::Number",   Str<|Number -89m/s|>, n(-89, "m/s"))
    verifyScalar(ns, "sys::Number",   Str<|Number 100$|>, n(100, "\$"))
    verifyScalar(ns, "sys::Number",   Str<|Number 50%|>, n(50, "%"))
    verifyScalar(ns, "sys::Date",     Str<|Date "2023-02-24"|>, Date("2023-02-24"))
    verifyScalar(ns, "sys::Date",     Str<|Date 2023-03-04|>, Date("2023-03-04"))
    verifyScalar(ns, "sys::Time",     Str<|Time "02:30:00"|>, Time("02:30:00"))
    verifyScalar(ns, "sys::Time",     Str<|Time 02:30:00|>, Time("02:30:00"))
    verifyScalar(ns, "sys::Ref",      Str<|Ref "abc"|>, Ref("abc"))
    verifyScalar(ns, "sys::Version",  Str<|Version "1.2.3"|>, Version("1.2.3"))
    verifyScalar(ns, "sys::Version",  Str<|sys::Version "1.2.3"|>, Version("1.2.3"))
    verifyScalar(ns, "sys::Uri",      Str<|Uri "file.txt"|>, `file.txt`)
    verifyScalar(ns, "sys::DateTime", Str<|DateTime "2023-02-24T10:51:47.21-05:00 New_York"|>, DateTime("2023-02-24T10:51:47.21-05:00 New_York"))
    verifyScalar(ns, "sys::DateTime", Str<|DateTime "2023-03-04T12:26:41.495Z"|>, DateTime("2023-03-04T12:26:41.495Z UTC"))
    verifyScalar(ns, "sys::DateTime", Str<|DateTime 2023-03-04T12:26:41.495Z|>, DateTime("2023-03-04T12:26:41.495Z UTC"))
  }

  Void verifyScalar(LibNamespace ns, Str qname, Str src, Obj? expected)
  {
    actual := ns.compileData(src)
    // echo("-- $src")
    // echo("   $actual [$actual.typeof]")
    verifyEq(actual, expected)

    type := ns.specOf(actual)
    verifyEq(type.qname, qname)

    pattern := type.get("pattern")
    if (pattern != null && !src.contains("\n"))
    {
      sp := src.index(" ")
      if (src[sp+1] == '"' || src[-1] == '"')
      {
        str := src[sp+2..-2]
        regex := Regex(pattern)
        verifyEq(regex.matches(str), true)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Multi-line Strings
//////////////////////////////////////////////////////////////////////////

  Void testMultiLineStrs()
  {
    // single lines
    verifyMultiLineStr(Str<|Str """"""|>, "")
    verifyMultiLineStr(Str<|Str """x"""|>, "x")
    verifyMultiLineStr(Str<|Str """\u2022 \u{1f973}"""|>, "\u2022 \u{1f973}")
    verifyMultiLineStr(Str<|Str """ """|>, " ")

    // newlines
    verifyMultiLineStr(
      Str<|Str """
           """|>, "")
    verifyMultiLineStr(
      Str<|Str """
             """|>, "")

    // no indention
    verifyMultiLineStr(
      Str<|Str """
           a
            b
             c
           """|>,
      Str<|a
            b
             c
           |>)

    // with indention
    verifyMultiLineStr(
      Str<|Str """
             a
              b
               c
             """|>,
      Str<|a
            b
             c
           |>)

    // with indention in and out
    verifyMultiLineStr(
      Str<|Str """
                 a
                b
               c
                 """|>,
      Str<|  a
            b
           c
           |>)

    // with quotes on last line
    verifyMultiLineStr(
      Str<|Str """
             a
              b
               c"""|>,
      Str<|a
            b
             c|>)

    // based on closing quotes
    verifyMultiLineStr(
      Str<|Str """
              a
               b
                c
             """|>,
      Str<| a
             b
              c
           |>)

    // with first line
    verifyMultiLineStr(
      Str<|Str """a
                   b
                    c
                  """|>,
      Str<|a
            b
             c
           |>)

    // blank lines
    verifyMultiLineStr(
      Str<|Str """a

                   b

                    c

                  """|>,
      Str<|a

            b

             c

           |>)

    // with tabs
    verifyMultiLineStr(
      Str<|Str """a
                  \tb
                  \t\tc
                  """|>,
      """a
         \tb
         \t\tc
         """)

    verifyMultiLineStr(
      """\tStr \"\"\"a
         \t        b
         \t         c
         \t       \"\"\"
         """,
      """a
          b
           c
         """)
  }

  Void verifyMultiLineStr(Str src, Str expect)
  {
    Str actual := compileData(src)

    //actual.splitLines.each |line| { echo("| " +  line.replace(" ", ".")) }

    verifyEq(actual, expect)
  }


//////////////////////////////////////////////////////////////////////////
// HereDocs
//////////////////////////////////////////////////////////////////////////

  Void testHereDocs()
  {
    ns := createNamespace(["sys"])

    // first test with triple quotes
    lib := ns.compileLib(
       Str<|Foo: {
              bar: """
              line 1
                line 2

              line 4
              """
              }
           |>)
    foo := lib.type("Foo")
    verifyHeredoc(foo.slot("bar").meta["val"],
      Str<|line 1
             line 2

           line 4
           |>)

    // same with heredoc
    lib = ns.compileLib(
       Str<|Foo: {
              bar: ---
              line 1
                line 2

              line 4
              ---
              }
           |>)
    foo = lib.type("Foo")
    verifyHeredoc(foo.slot("bar").meta["val"],
      Str<|line 1
             line 2

           line 4
           |>)

    // tabs
    lib = ns.compileLib(
       """Foo: {
            \tbar: ---
            \t line 1
            \t   line 2

            \tline 4
              ---
              }
           """)
    foo = lib.type("Foo")
    verifyHeredoc(foo.slot("bar").meta["val"],
      Str<| line 1
              line 2

           line 4
           |>)

    // heredoc don't use escape sequences
    lib = ns.compileLib(
       Str<|Foo: {
              bar: ---
              line1: "foo"
              line2: $foo
              line3: """foo"""
              ---
              }
           |>)
    foo = lib.type("Foo")
    verifyHeredoc(foo.slot("bar").meta["val"],
      Str<|line1: "foo"
           line2: $foo
           line3: """foo"""
           |>)

    // heredoc with multiple -
    lib = ns.compileLib(
       Str<|Foo: {
              bar: -----
              line1
              ---- // ok
              line3
              -----
              }
           |>)
    foo = lib.type("Foo")
    verifyHeredoc(foo.slot("bar").meta["val"],
      Str<|line1
           ---- // ok
           line3
           |>)
  }

  Void verifyHeredoc(Str actual, Str expect)
  {
    // echo("verify heredoc"); echo("---"); echo(actual); echo("---")
    verifyEq(actual, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Dicts
//////////////////////////////////////////////////////////////////////////

  Void testDicts()
  {
    // spec-less
    verifyDict(Str<|{}|>, [:])
    verifyDict(Str<|Dict {}|>, [:])
    verifyDict(Str<|{foo}|>, ["foo":m])
    verifyDict(Str<|{foo, bar}|>, ["foo":m, "bar":m])
    verifyDict(Str<|{dis:"Hi", mark}|>, ["dis":"Hi", "mark":m])

    // LibOrg
    verifyDict(Str<|LibOrg {}|>, ["dis":"", "uri":``, "spec":Ref("sys::LibOrg")], "sys::LibOrg")
    verifyDict(Str<|sys::LibOrg {}|>, ["dis":"", "uri":``, "spec":Ref("sys::LibOrg")], "sys::LibOrg")
    verifyDict(Str<|LibOrg { dis:"Acme" }|>, ["dis":"Acme", "uri":``, "spec":Ref("sys::LibOrg")], "sys::LibOrg")
    verifyDict(Str<|LibOrg { dis:"Acme", uri:Uri "http://acme.com" }|>, ["dis":"Acme", "uri":`http://acme.com`, "spec":Ref("sys::LibOrg")], "sys::LibOrg")

    // whitespace
    /* TODO: how much variation do we want to allow
    verifyDict(Str<|LibOrg
                    {

                    }|>, [:], "sys::LibOrg")
    verifyDict(Str<|LibOrg


                                   {

                    }|>, [:], "sys::LibOrg")
      */
  }

  Void verifyDict(Str src, Str:Obj expected, Str type := "sys::Dict")
  {
    Dict actual := compileData(src)
     // echo("-- $actual [$actual.spec]"); TrioWriter(Env.cur.out).writeDict(actual)
    if (expected.isEmpty && type == "sys::Dict")
    {
      verifyEq(actual.isEmpty, true)
      verifySame(actual, Etc.dict0)
      return
    }
    verifyDictEq(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// Self
//////////////////////////////////////////////////////////////////////////

  Void testSelf()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
      Str<|A: {
            n: Number <minVal:0, maxVal:100>
            i: Int <minVal:0, maxVal:100>
            d: Duration <minVal:0sec, maxVal:100sec>
           }|>)

    a := lib.type("A")
    // env.print(a)

    verifyEq(a.slot("n").meta["minVal"], Number(0))
    verifyEq(a.slot("n").meta["maxVal"], Number(100))

    verifyEq(a.slot("i").meta["minVal"], 0)
    verifyEq(a.slot("i").meta["maxVal"], 100)

    verifyEq(a.slot("d").meta["minVal"], 0sec)
    verifyEq(a.slot("d").meta["maxVal"], 100sec)
  }

//////////////////////////////////////////////////////////////////////////
// Lib Instances
//////////////////////////////////////////////////////////////////////////

  Void testLibInstances()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
      Str<|Person: Dict {
             person
             first: Str
             last: Str
             born: Date "2000-01-01"
             obj: Obj
           }

           @brian: Person {first:"Brian", last:"Frank"}

           @alice: Person {
             first: "Alice"
             last: "Smith"
             born: "1980-06-15"
             boss: @brian
             obj: "string"

             @nest1: Person {
               first: "Bird"
               last: "Nest1"
               boss: @nest2
             }

             n2 @nest2: Person {
               first: "Bird"
               last: "Nest2"
               boss: @nest1
             }
           }

           |>)

    spec := lib.type("Person")

    b := verifyLibInstance(lib, spec, "brian",
      ["person":m, "first":"Brian", "last":"Frank", "born": Date("2000-01-01")])

    n1 := verifyLibInstance(lib, spec, "nest1",
      ["person":m, "first":"Bird", "last":"Nest1", "born": Date("2000-01-01"), "boss":Ref("${lib.name}::nest2")])

    n2 := verifyLibInstance(lib, spec, "nest2",
      ["person":m, "first":"Bird", "last":"Nest2", "born": Date("2000-01-01"), "boss":n1->id])

    a := verifyLibInstance(lib, spec, "alice",
      ["person":m, "first":"Alice", "last":"Smith", "born": Date("1980-06-15"), "boss":b->id, "obj":"string", "_0":n1, "n2":n2])

    verifySame(n1, a->_0)
    verifySame(n2, a->n2)
  }

  Dict verifyLibInstance(Lib lib, Spec spec, Str name, Str:Obj expect)
  {
    x := lib.instance(name)
    id := Ref(lib.name + "::" + name, null)
    // echo("\n-- $id =>"); TrioWriter(Env.cur.out).writeDict(x)
    verifyEq(lib.instances.containsSame(x), true)
    verifyRefEq(x->id, id)
    verifyDictEq(x, expect.dup.set("id", id).set("spec", Ref(spec.qname)))
    return x
  }

//////////////////////////////////////////////////////////////////////////
// List Instances
//////////////////////////////////////////////////////////////////////////

  Void testListInstances()
  {
    ns := createNamespace(["hx.test.xeto"])
    x := ns.instance("hx.test.xeto::lists")

    a := (List)x->a
    verifyEq(a[0], Date("2024-11-26"))
    verifyEq(a, Obj[Date("2024-11-26"), Date("2024-11-27")])
  }

//////////////////////////////////////////////////////////////////////////
// Data Instances
//////////////////////////////////////////////////////////////////////////

  Void testDataInstances()
  {
    Dict[] dicts := compileData(
      Str<|@brian: {first:"Brian", last:"Frank"}

           @alice: {
             first: "Alice"
             last: "Smith"
             born: Date "1980-06-15"
             boss: @brian

             @nest1: { first: "Bird", last: "Nest1", boss: @nest2  }

             n2 @nest2: { first: "Bird", last: "Nest2", boss: @nest1 }
           }
           |>)

    // echo(dicts.join("\n"))

    b := dicts[0]
    a := dicts[1]
    n1 := a["_0"] as Dict
    n2 := a["n2"] as Dict

    verifyDictEq(b,  ["id":Ref("brian"), "first":"Brian", "last":"Frank"])
    verifyDictEq(n1, ["id":Ref("nest1"), "first":"Bird", "last":"Nest1", "boss":Ref("nest2")])
    verifyDictEq(n2, ["id":Ref("nest2"), "first":"Bird", "last":"Nest2", "boss":Ref("nest1")])
    verifyDictEq(a,  ["id":Ref("alice"), "first":"Alice", "last":"Smith", "born": Date("1980-06-15"), "boss":b->id, "_0":n1, "n2":n2])
  }

//////////////////////////////////////////////////////////////////////////
// Inherit
//////////////////////////////////////////////////////////////////////////

  Void testInheritSlots()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
      Str<|A: {
             foo: Number <a> 123  // a-doc
           }

           B: A

           C: A {
             foo: Int <c>
           }

           D: A {
             foo: Number 456 // d-doc
           }

           E: D {
           }

           F: D {
             foo: Number <f, baz:"hi">
           }

           a: Marker <meta>
           c: Marker <meta>
           f: Marker <meta>
           baz: Str <meta>
           |>)

    // env.print(lib)

    num := ns.type("sys::Number")
    int := ns.type("sys::Int")

    a := lib.type("A"); af := a.slot("foo")
    b := lib.type("B"); bf := b.slot("foo")
    c := lib.type("C"); cf := c.slot("foo")
    d := lib.type("D"); df := d.slot("foo")
    e := lib.type("E"); ef := e.slot("foo")
    f := lib.type("F"); ff := f.slot("foo")

    verifyInheritSlot(a, af, num, num, ["a":m, "val":n(123), "doc":"a-doc"], "a,val,doc")
    verifySame(bf, af)
    verifyInheritSlot(c, cf, af, int, ["a":m, "val":n(123), "doc":"a-doc", "c":m], "c")
    verifyInheritSlot(d, df, af, num, ["a":m, "val":n(456), "doc":"d-doc"], "val,doc")
    verifySame(ef, df)
    verifyInheritSlot(f, ff, df, num, ["a":m, "val":n(456), "doc":"d-doc", "f":m, "baz":"hi"], "f, baz")
  }

  Void verifyInheritSlot(Spec parent, Spec s, Spec base, Spec type, Str:Obj meta, Str ownNames)
  {
    // echo
    // echo("-- testInheritSlot $s base:$s.base type:$s.type")
    // echo("   own = $s.metaOwn")
    // s.each |v, n| { echo("   $n: $v [$v.typeof] " + (s.metaOwn.has(n) ? "own" : "inherit")) }

    verifySame(s.parent, parent)
    verifyEq(s.qname, parent.qname + "." + s.name)
    verifySame(s.base, base)
    verifySame(s.type, type)

    own := ownNames.split(',')
    meta.each |v, n|
    {
      verifyEq(s[n], v)
      verifyEq(s.trap(n), v)
      verifyEq(s.has(n), true)
      verifyEq(s.missing(n), false)

      isOwn := own.contains(n)
      verifyEq(s.metaOwn[n], isOwn ? v : null)
      verifyEq(s.metaOwn.has(n), isOwn)
      verifyEq(s.metaOwn.missing(n), !isOwn)
    }

    s.each |v, n|
    {
      switch (n)
      {
        case "id":   verifyEq(v, s.id)
        case "spec": verifyEq(v, ref("sys::Spec"))
        case "type": verifyEq(v, s.type.id)
        default:     verifyEq(meta[n], v, n)
      }
    }

    if (base !== type)
    {
      x := parent.slotsOwn.get(s.name)
      // echo("   ownSlot $x base:$x.base type:$x.type")
      // x.metaOwn.each |v, n| { echo("   $n: $v") }
      verifySame(s, x)
      verifyEq(x.name, s.name)
      verifyEq(x.qname, x.qname)
      verifySame(x.parent, parent)
      verifySame(x.type, type)
      x.metaOwn.each |v, n| { verifyEq(own.contains(n), true) }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Inherit None
//////////////////////////////////////////////////////////////////////////

  Void testInheritNone()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
       Str<|A: Dict <baz, foo: NA "na"> {
              foo: Date <bar, qux> "2023-04-07"
            }
            B : A <baz:None "none"> {
              foo: Date <qux:None "none">
            }

            foo: Obj <meta>
            bar: Obj <meta>
            baz: Obj <meta>
            qux: Obj <meta>
           |>)

    // env.print(lib)

    a := lib.type("A"); af := a.slot("foo")
    b := lib.type("B"); bf := b.slot("foo")

    verifyInheritNone(a, "baz",  m, m)
    verifyInheritNone(a, "foo",  na, na)
    verifyInheritNone(af, "bar", m, m)
    verifyInheritNone(af, "qux", m, m)

    verifyInheritNone(b, "baz",  none, null)
    verifyInheritNone(b, "foo",  null, na)
    verifyInheritNone(bf, "bar", null, m)
    verifyInheritNone(bf, "qux", none, null)
  }

  private Void verifyInheritNone(Spec s, Str name, Obj? own, Obj? effective)
  {
    // echo("~~ $s.qname own=" + s.metaOwn[name] + " effective=" + s[name])
    verifyEq(s.metaOwn[name], own)
    verifyEq(s[name], effective)
  }

//////////////////////////////////////////////////////////////////////////
// Inherit And
//////////////////////////////////////////////////////////////////////////

  Void testInheritAnd()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
       Str<|A: {
              enum: Str?    // nullable
              foo:  Str?    // nullable
            }
            A1 : A {
              enum: Str     // non-nullable
            }
            A2 : A {
              foo: Str      // non-nullable
            }
            A12 : A1 & A2 {
            }
            B1 : A1 {
              enum: Str <x>     // more
            }
            B2 : A2 {
              foo: Str <x>      // more
            }
            B12 : B1 & B2 {
            }

            x: Marker <meta>
         |>)

    // lib.tops.each |x| { env.print(x) }

    str := ns.spec("sys::Str")

    a   := lib.type("A")
    a1  := lib.type("A1")
    a2  := lib.type("A2")
    a12 := lib.type("A12")
    b1  := lib.type("B1")
    b2  := lib.type("B2")
    b12 := lib.type("B12")

    e   := verifyInheritAnd(a,  "enum", str, str, ["val":"", "doc":"nullable", "maybe":m])
    eA1 := verifyInheritAnd(a1, "enum", e,   str, ["val":"", "doc":"non-nullable"])
    eB1 := verifyInheritAnd(b1, "enum", eA1, str, ["val":"", "doc":"more", "x":m])
    verifySame(a2.slot("enum"), e)
    verifySame(b2.slot("enum"), e)
    verifySame(a12.slot("enum"), eA1)
    verifySame(b12.slot("enum"), eB1)

    f   := verifyInheritAnd(a,  "foo", str, str, ["val":"", "doc":"nullable", "maybe":m])
    fA2 := verifyInheritAnd(a2, "foo", f,   str, ["val":"", "doc":"non-nullable"])
    fB2 := verifyInheritAnd(b2, "foo", fA2, str, ["val":"", "doc":"more", "x":m])
    verifySame(a1.slot("foo"), f)
    verifySame(a12.slot("foo"), fA2)
    verifySame(b12.slot("foo"), fB2)

  }

  Spec verifyInheritAnd(Spec x, Str slotName, Spec base, Spec type, Str:Obj meta)
  {
    slot := x.slot(slotName)
    // echo("  ~~ $slot.name <= $slot.base : $slot.type $slot.meta")
    verifySame(slot.base, base)
    verifySame(slot.type, type)
    verifyDictEq(slot.meta, meta)
    return slot
  }

//////////////////////////////////////////////////////////////////////////
// Nested specs
//////////////////////////////////////////////////////////////////////////

  Void testNestedSpecs()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
       Str<|Foo: {
              a: List<of:Foo>
              b: List<of:Spec>
              c: List<of:Ref<of:Foo>>
              d: List<of:Ref<of:Spec>>
              e: List<of:Foo <qux>>
              f: List<of:Foo <> { extra: Str }>
              g: List<of:Foo <qux> { extra: Str }>
              h: List<of:Foo | Bar>
              i: List<of:Foo & Bar>
              j: Dict < x:Foo? >
              k: Dict < x:Foo<qux> >
              l: Dict < x:Foo<y:Bar<z:Str>> >
            }

            Bar: {}

            x: Obj <meta>
            y: Obj <meta>
            z: Obj <meta>
            qux: Obj <meta>
           |>)

    foo := lib.type("Foo")
    /*
    env.print(lib)
    foo.slots.each |slot|
    {
      echo("${slot.name}: " + toNestedSpecSig(lib, slot))
    }
    */

    verifyNestedSpec(foo.slot("a"), "List<of:Foo>")
    verifyNestedSpec(foo.slot("b"), "List<of:Spec>")
    verifyNestedSpec(foo.slot("c"), "List<of:Ref<of:Foo>>")
    verifyNestedSpec(foo.slot("d"), "List<of:Ref<of:Spec>>")
    verifyNestedSpec(foo.slot("e"), "List<of:Foo<qux>>")
    verifyNestedSpec(foo.slot("f"), "List<of:Foo{extra:Str}>")
    verifyNestedSpec(foo.slot("g"), "List<of:Foo<qux>{extra:Str}>")
    verifyNestedSpec(foo.slot("h"), "List<of:Foo|Bar>")
    verifyNestedSpec(foo.slot("i"), "List<of:Foo&Bar>")
    verifyNestedSpec(foo.slot("j"), "Dict<x:Foo<maybe>>")
    verifyNestedSpec(foo.slot("k"), "Dict<x:Foo<qux>>")
    verifyNestedSpec(foo.slot("l"), "Dict<x:Foo<y:Bar<z:Str>>>")
  }

  Void verifyNestedSpec(Spec x, Str expect)
  {
    actual := toNestedSpecSig(x.lib, x)
    verifyEq(actual, expect)
  }

  Str toNestedSpecSig(Lib lib, Spec x)
  {
    if (x.isCompound)
    {
      sep := x.isAnd ? "&" : "|"
      return x.ofs.join(sep) |c| { c.name }
    }

    s := StrBuf()
    if (x.type.name[0] == '_')
      s.add(x.base.name)
    else
      s.add(x.type.name)

    if (!x.metaOwn.isEmpty)
    {
      s.add("<")
      x.metaOwn.each |v, n|
      {
        s.add(n)
        if (v === Marker.val) return
        s.add(":").add(toNestedSpecRef(lib, v))
      }
      s.add(">")
    }

    if (!x.slotsOwn.isEmpty)
    {
      s.add("{")
      x.slotsOwn.each |slot| { s.add(slot.name).add(":").add(slot.type.name) }
      s.add("}")
    }

    return s.toStr
  }

  Str toNestedSpecRef(Lib lib, Ref x)
  {
    name := x.toStr[x.toStr.indexr(":")+1..-1]
    if (name[0] != '_') return name

    deref := lib.type(name)
    return toNestedSpecSig(lib, deref)
  }
}

