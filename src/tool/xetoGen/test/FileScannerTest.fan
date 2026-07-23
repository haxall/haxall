//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using xeto
using xetom

**
** FileScannerTest verifies token scanning of in-memory source strings.
** Expected line numbers are zero based to match the AST.
**
class FileScannerTest : Test
{

  Void testBasics()
  {
    src := [
      "using xeto",                                                          //  0
      "",                                                                    //  1
      "** Foo docs",                                                         //  2
      "** second line",                                                      //  3
      "@Gen",                                                                //  4
      "class Foo : Bar, Mixin",                                              //  5
      "{",                                                                   //  6
      "  ** Name slot",                                                      //  7
      "  @Gen virtual Str? name() { get(\"name\") }",                        //  8
      "",                                                                    //  9
      "  @Gen virtual Int count { get {get(\"count\")} set {set(\"count\", it)} }",  // 10
      "",                                                                    // 11
      "  override Void onExecute()",                                         // 12
      "  {",                                                                 // 13
      "    echo(\"{ unbalanced brace in str\")",                             // 14
      "  }",                                                                 // 15
      "",                                                                    // 16
      "  private Int counter := 3",                                          // 17
      "}",                                                                   // 18
      ].join("\n")

    file := scan(src)
    verifyEq(file.types.size, 1)

    t := file.types[0]
    verifyAType(t, "Foo", 2..18)
    verifyEq(t.docLines, 2..3)
    verifyEq(t.gen.line, 4)
    verifyEq(t.gen.raw, null)
    verifyEq(t.bodyOpen, 6)
    verifyEq(t.items, null)

    // only @Gen tagged slots are recorded
    verifyEq(t.slots.size, 2)
    verifyASlot(t.slots[0], "name",  7..8)
    verifyASlot(t.slots[1], "count", 10..10)
    verifyEq(t.slots[0].docLines, 7..7)
    verifyEq(t.slots[0].parent, t)
  }

  Void testTypes()
  {
    src := [
      "@Gen",                                                                //  0
      "class Alpha : Base",                                                  //  1
      "{",                                                                   //  2
      "}",                                                                   //  3
      "",                                                                    //  4
      "class NotGen",                                                        //  5
      "{",                                                                   //  6
      "  Void stuff() { x := \"{{{\" }",                                     //  7
      "}",                                                                   //  8
      "",                                                                    //  9
      "** Mixin docs",                                                       // 10
      "@NoDoc @Gen",                                                         // 11
      "const mixin Beta : Dict",                                             // 12
      "{",                                                                   // 13
      "  ** Q doc",                                                          // 14
      "  @Gen abstract Str? qux()",                                          // 15
      "",                                                                    // 16
      "  ** Task doc",                                                       // 17
      "  @NoDoc @Api @Axon { admin = true }",                                // 18
      "  static Str? task(Obj? id, Bool checked := true) { doTask(id) }",    // 19
      "",                                                                    // 20
      "  @Gen override Duration? timeout()",                                 // 21
      "}",                                                                   // 22
      ].join("\n")

    file := scan(src)
    verifyEq(file.types.size, 2)

    a := file.types[0]
    verifyAType(a, "Alpha", 0..3)
    verifyEq(a.slots.size, 0)

    b := file.types[1]
    verifyAType(b, "Beta", 10..22, "const,mixin")
    verifyEq(b.docLines, 10..10)

    // untagged task slot is not recorded
    verifyEq(b.slots.size, 2)
    verifyASlot(b.slots[0], "qux",     14..15, "abstract")
    verifyASlot(b.slots[1], "timeout", 21..21, "override")
  }

  Void testEnum()
  {
    src := [
      "@Gen",                                                                //  0
      "enum class Color",                                                    //  1
      "{",                                                                   //  2
      "  ** Red doc",                                                        //  3
      "  red,",                                                              //  4
      "  green(\"g\"),",                                                     //  5
      "  blue",                                                              //  6
      "",                                                                    //  7
      "  static Color defVal() { red }",                                     //  8
      "}",                                                                   //  9
      ].join("\n")

    file := scan(src)
    t := file.types[0]
    verifyAType(t, "Color", 0..9, "enum")
    verifyEq(t.items, 3..6)
    verifyEq(t.slots.size, 0)
  }

  Void testFacets()
  {
    src := [
      "@NoDoc @Js @Gen",                                                     //  0
      "class Alpha : Base",                                                  //  1
      "{",                                                                   //  2
      "  @Js @Gen virtual Str? x() { get(\"x\") }",                          //  3
      "",                                                                    //  4
      "  @Gen @NoDoc virtual Str? y() { get(\"y\") }",                       //  5
      "",                                                                    //  6
      "  ** Zed doc",                                                        //  7
      "  @Serializable { simple = true }",                                   //  8
      "  @Gen { meta = \"foo\" }",                                           //  9
      "  @Deprecated { msg = \"old\" }",                                     // 10
      "  virtual Str? z() { get(\"z\") }",                                   // 11
      "}",                                                                   // 12
      "",                                                                    // 13
      "@Js",                                                                 // 14
      "@xeto::Gen",                                                          // 15
      "class Beta",                                                          // 16
      "{",                                                                   // 17
      "  @xeto::Gen virtual Int q() { get(\"q\") }",                         // 18
      "}",                                                                   // 19
      ].join("\n")

    file := scan(src)
    verifyEq(file.types.size, 2)

    // @Gen last in facet list on one line
    a := file.types[0]
    verifyAType(a, "Alpha", 0..12)
    verifyEq(a.gen.line, 0)
    verifyEq(a.slots.size, 3)
    verifyASlot(a.slots[0], "x", 3..3)
    verifyASlot(a.slots[1], "y", 5..5)

    // @Gen between other facets with it-blocks; only Gen block is meta
    z := a.slots[2]
    verifyASlot(z, "z", 7..11)
    verifyEq(z.docLines, 7..7)
    verifyEq(z.gen.line, 9)
    verifyEq(z.gen.raw, "foo")
    verifyEq(z.gen.meta->foo, Marker.val)

    // qualified facet names on own lines
    b := file.types[1]
    verifyAType(b, "Beta", 14..19)
    verifyEq(b.gen.line, 15)
    verifyEq(b.slots.size, 1)
    verifyASlot(b.slots[0], "q", 18..18)
  }

  Void testClosures()
  {
    src := [
      "@Gen",                                                                //  0
      "class Alpha",                                                         //  1
      "{",                                                                   //  2
      "  @Gen virtual Str? name() { get(\"name\") }",                        //  3
      "",                                                                    //  4
      "  @Gen Str[] tags := stuff.map |x->Str| { x.name }",                  //  5
      "",                                                                    //  6
      "  Void walk()",                                                       //  7
      "  {",                                                                 //  8
      "    kids.each |kid|",                                                 //  9
      "    {",                                                               // 10
      "      kid.list.eachWhile |x, i->Obj?|",                               // 11
      "      {",                                                             // 12
      "        if (x.isEmpty) return echo(\"{\")",                           // 13
      "        return x.map |s| { s.upper }",                                // 14
      "      }",                                                             // 15
      "    }",                                                               // 16
      "  }",                                                                 // 17
      "",                                                                    // 18
      "  @Gen abstract Void onFoo(|Str->Void| cb)",                          // 19
      "",                                                                    // 20
      "  @Gen virtual Int count { get {get(\"count\")} set {set(\"count\", it)} }",  // 21
      "}",                                                                   // 22
      ].join("\n")

    file := scan(src)
    verifyEq(file.types.size, 1)

    t := file.types[0]
    verifyAType(t, "Alpha", 0..22)

    // walk with nested closures is untagged; count after it proves
    // brace matching tracked thru closure blocks and brace in str
    verifyEq(t.slots.size, 4)
    verifyASlot(t.slots[0], "name",  3..3)
    verifyASlot(t.slots[1], "tags",  5..5)
    verifyASlot(t.slots[2], "onFoo", 19..19, "abstract")
    verifyASlot(t.slots[3], "count", 21..21)
  }

  Void testMeta()
  {
    src := [
      Str<|@Gen { meta = "foo:\"ph::Site\"" }|>,                             //  0
      "class Gamma",                                                         //  1
      "{",                                                                   //  2
      "}",                                                                   //  3
      "",                                                                    //  4
      "@Gen { meta = Str<|skip:\"a,b\"|> }",                                 //  5
      "class Delta",                                                         //  6
      "{",                                                                   //  7
      "  @Gen { meta = Str<|foo|> } virtual Str? name() { get(\"name\") }",  //  8
      "}",                                                                   //  9
      ].join("\n")

    file := scan(src)
    verifyEq(file.types.size, 2)
    verifyEq(file.types[0].gen.raw, Str<|foo:"ph::Site"|>)
    verifyEq(file.types[0].gen.meta->foo, "ph::Site")
    verifyEq(file.types[1].gen.raw, Str<|skip:"a,b"|>)
    verifyEq(file.types[1].gen.meta->skip, "a,b")
    verifyEq(file.types[1].slots[0].gen.raw, "foo")
    verifyEq(file.types[1].slots[0].gen.meta->foo, Marker.val)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Scan in-memory source string; the temp lib provides specs
  ** for the fixture type names used across the test methods
  private AFile scan(Str src)
  {
    c := GenCompiler { it.logger = XetoLog.makeOutStream(Buf().out) }
    lib := c.ns.compileTempLib(
      """Foo: Dict {}
         Alpha: Dict {}
         Beta: Dict {}
         Gamma: Dict {}
         Delta: Dict {}
         Color: Enum { red, green, blue }
         """)
    pod := APod([lib], "test", File(`test/`))
    return FileScanner(c, pod, File(`test/Test.fan`), src).scan
  }

  private Void verifyAType(AType t, Str name, Range lines, Str flags := "")
  {
    verifyEq(t.name, name)
    verifyEq(t.lines, lines)
    verifyEq(t.flags.toStr, flags)
  }

  private Void verifyASlot(ASlot s, Str name, Range lines, Str flags := "")
  {
    verifyEq(s.name, name)
    verifyEq(s.lines, lines)
    verifyEq(s.flags.toStr, flags)
  }
}

