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
** GenFanTest verifies end-to-end generation of comp get/set slots
** using in-memory source against installed hx.comps specs.
**
class GenFanTest : Test
{

  ** Stale doc and signature are regenerated in place
  Void testUpdate()
  {
    src := [
      "using xeto",
      "",
      "** stale type doc",
      "@Gen",
      "abstract class Logic : HxComp",
      "{",
      "  ** stale slot doc",
      "  @Gen virtual Str? out() { get(\"wrong\") }",
      "}",
      ]
    expect := [
      "using xeto",
      "",
      "**",
      "** The base spec for all logic components",
      "**",
      "@Gen",
      "abstract class Logic : HxComp",
      "{",
      "  ** The computed value",
      "  @Gen virtual StatusBool? out() { get(\"out\") }",
      "}",
      ]
    verifyGen(src, expect)
  }

  ** Missing spec slots are inserted after the last slot
  Void testInsert()
  {
    src := [
      "@Gen",
      "class SineWave : HxComp",
      "{",
      "  ** The computed sine wave",
      "  @Gen virtual StatusNumber out() { get(\"out\") }",
      "",
      "  new make() {}",
      "}",
      ]
    expect := [
      "**",
      "** The output of this component generates a sine wave.",
      "**",
      "@Gen",
      "class SineWave : HxComp",
      "{",
      "  ** The computed sine wave",
      "  @Gen virtual StatusNumber out() { get(\"out\") }",
      "",
      "  ** The amount of time it takes to output one complete cycle",
      "  @Gen virtual Duration period { get {get(\"period\")} set {set(\"period\", it)} }",
      "",
      "  ** The height of the sine wave from its lowest to highest point",
      "  @Gen virtual Float amplitude { get {get(\"amplitude\")} set {set(\"amplitude\", it)} }",
      "",
      "  ** The distance from zero that the sine wave's amplitude is shifted",
      "  @Gen virtual Float offset { get {get(\"offset\")} set {set(\"offset\", it)} }",
      "",
      "  ** How frequently to compute the sine wave",
      "  @Gen virtual Duration freq { get {get(\"freq\")} set {set(\"freq\", it)} }",
      "",
      "  new make() {}",
      "}",
      ]
    verifyGen(src, expect)
  }

  ** Slots no longer declared by the spec are removed with
  ** one adjacent blank line swallowed
  Void testDelete()
  {
    // trailing slot removed with its preceding blank line
    src := [
      "**",
      "** Computes the logical negation of its input",
      "**",
      "@Gen",
      "class Not : Logic",
      "{",
      "  @Gen virtual StatusBool? in() { get(\"in\") }",
      "",
      "  @Gen virtual Str? bogus() { get(\"bogus\") }",
      "}",
      ]
    expect := [
      "**",
      "** Computes the logical negation of its input",
      "**",
      "@Gen",
      "class Not : Logic",
      "{",
      "  @Gen virtual StatusBool? in() { get(\"in\") }",
      "}",
      ]
    verifyGen(src, expect)

    // first slot removed with its following blank line
    src = [
      "**",
      "** Computes the logical negation of its input",
      "**",
      "@Gen",
      "class Not : Logic",
      "{",
      "  @Gen virtual Str? bogus() { get(\"bogus\") }",
      "",
      "  @Gen virtual StatusBool? in() { get(\"in\") }",
      "}",
      ]
    expect = [
      "**",
      "** Computes the logical negation of its input",
      "**",
      "@Gen",
      "class Not : Logic",
      "{",
      "  @Gen virtual StatusBool? in() { get(\"in\") }",
      "}",
      ]
    verifyGen(src, expect)
  }

  ** Middle slot removed leaves single blank between neighbors
  Void testDeleteMiddle()
  {
    src := [
      "**",
      "** The output of this component generates a sine wave.",
      "**",
      "@Gen",
      "class SineWave : HxComp",
      "{",
      "  ** The computed sine wave",
      "  @Gen virtual StatusNumber out() { get(\"out\") }",
      "",
      "  ** bogus doc",
      "  @Gen virtual Str? bogus() { get(\"bogus\") }",
      "",
      "  ** The amount of time it takes to output one complete cycle",
      "  @Gen virtual Duration period { get {get(\"period\")} set {set(\"period\", it)} }",
      "",
      "  ** The height of the sine wave from its lowest to highest point",
      "  @Gen virtual Float amplitude { get {get(\"amplitude\")} set {set(\"amplitude\", it)} }",
      "",
      "  ** The distance from zero that the sine wave's amplitude is shifted",
      "  @Gen virtual Float offset { get {get(\"offset\")} set {set(\"offset\", it)} }",
      "",
      "  ** How frequently to compute the sine wave",
      "  @Gen virtual Duration freq { get {get(\"freq\")} set {set(\"freq\", it)} }",
      "}",
      ]
    expect := src.dup
    expect.removeRange(8..10)
    verifyGen(src, expect)
  }

  ** Dict specs generate abstract getters via temp lib
  Void testDict()
  {
    xeto := [
      "// Group config for testing",
      "TestGroup: Dict {",
      "  // Display name",
      "  dis: Str",
      "",
      "  // Optional icon",
      "  icon: Str?",
      "",
      "  // List of tags",
      "  tags: List? <of: Str>",
      "}",
      "",
      "// Settings config for testing",
      "TestWrap: Dict {",
      "  // Display name",
      "  dis: Str",
      "}",
      ].join("\n")
    src := [
      "@Gen",
      "const mixin TestGroup : Dict",
      "{",
      "  @Gen virtual Str dis() { get(\"dis\") }",
      "}",
      "",
      "@Gen",
      "const class TestWrap : WrapDict",
      "{",
      "}",
      ].join("\n")
    expect := [
      "**",
      "** Group config for testing",
      "**",
      "@Gen",
      "const mixin TestGroup : Dict",
      "{",
      "  ** Display name",
      "  @Gen virtual Str dis() { get(\"dis\") }",
      "",
      "  ** Optional icon",
      "  @Gen abstract Str? icon()",
      "",
      "  ** List of tags",
      "  @Gen abstract Str[]? tags()",
      "}",
      "",
      "**",
      "** Settings config for testing",
      "**",
      "@Gen",
      "const class TestWrap : WrapDict",
      "{",
      "  ** Display name",
      "  @Gen virtual Str dis() { get(\"dis\") }",
      "}",
      ].join("\n")
    verifyEq(genTemp(xeto, src), expect)
  }

  ** Funcs mode aligns @Api methods: docs synced, params verified
  Void testFuncs()
  {
    xeto := [
      "+Funcs {",
      "  // Add two numbers together",
      "  add: Func { a: Number, b: Number, returns: Number }",
      "",
      "  // Say hello to somebody",
      "  hello: Func <admin> { name: Str?, returns: Str }",
      "}",
      ].join("\n")
    src := [
      "@Gen",
      "const class TempFuncs",
      "{",
      "  ** stale doc",
      "  @Api @Axon",
      "  static Number add(Number a, Number b)",
      "  {",
      "    a + b",
      "  }",
      "",
      "  @Api @Axon { admin = true }",
      "  static Str hello(Str? name := null)",
      "  {",
      "    \"hello \" + (name ?: \"world\")",
      "  }",
      "}",
      ].join("\n")
    expect := [
      "@Gen",
      "const class TempFuncs",
      "{",
      "  ** Add two numbers together",
      "  @Api @Axon",
      "  static Number add(Number a, Number b)",
      "  {",
      "    a + b",
      "  }",
      "",
      "  ** Say hello to somebody",
      "  @Api @Axon { admin = true }",
      "  static Str hello(Str? name := null)",
      "  {",
      "    \"hello \" + (name ?: \"world\")",
      "  }",
      "}",
      ].join("\n")
    verifyEq(genTemp(xeto, src), expect)
  }

  ** Funcs mode with omitDocs strips Fantom docs
  Void testFuncsOmitDocs()
  {
    xeto := [
      "+Funcs {",
      "  // Add two numbers together",
      "  add: Func { a: Number, b: Number, returns: Number }",
      "}",
      ].join("\n")
    src := [
      "@Gen { meta = Str<|omitDocs|> }",
      "const class TempFuncs",
      "{",
      "  ** stale doc",
      "  @Api @Axon",
      "  static Number add(Number a, Number b) { a + b }",
      "}",
      ].join("\n")
    expect := [
      "@Gen { meta = Str<|omitDocs|> }",
      "const class TempFuncs",
      "{",
      "  @Api @Axon",
      "  static Number add(Number a, Number b) { a + b }",
      "}",
      ].join("\n")
    verifyEq(genTemp(xeto, src), expect)
  }

  ** Funcs mode errors on param count and missing/extra funcs
  Void testFuncsErrs()
  {
    xeto := [
      "+Funcs {",
      "  add: Func { a: Number, b: Number, returns: Number }",
      "  sub: Func { a: Number, b: Number, returns: Number }",
      "}",
      ].join("\n")

    // param count mismatch and missing sub and extra mult
    src := [
      "@Gen",
      "const class TempFuncs",
      "{",
      "  @Api @Axon",
      "  static Number add(Number a) { a }",
      "",
      "  @Api @Axon",
      "  static Number mult(Number a, Number b) { a * b }",
      "}",
      ].join("\n")
    verifyErr(XetoCompilerErr#) { genTemp(xeto, src) }
  }

  ** Enum items regenerate from spec preserving ctor args by name
  Void testEnumItems()
  {
    src := [
      "**",
      "** Tests available to the StrTest component.",
      "**",
      "@Gen",
      "enum class StrTestType",
      "{",
      "  eq(\"=\"),",
      "",
      "  bogus,",
      "",
      "  contains(null)",
      "",
      "  private new make(Str? op) { this.op = op }",
      "",
      "  const Str? op",
      "}",
      ]
    expect := [
      "**",
      "** Tests available to the StrTest component.",
      "**",
      "@Gen",
      "enum class StrTestType",
      "{",
      "  eq(\"=\"),",
      "",
      "  eqIgnoreCase,",
      "",
      "  startsWith,",
      "",
      "  endsWith,",
      "",
      "  contains(null)",
      "",
      "  private new make(Str? op) { this.op = op }",
      "",
      "  const Str? op",
      "}",
      ]
    verifyGen(src, expect)
  }

  ** Slots in the @Gen meta skip list are not generated
  Void testSkip()
  {
    src := [
      "**",
      "** The output of this component generates a sine wave.",
      "**",
      "@Gen { meta = Str<|skip:\"period,freq\"|> }",
      "class SineWave : HxComp",
      "{",
      "  ** The computed sine wave",
      "  @Gen virtual StatusNumber out() { get(\"out\") }",
      "",
      "  ** The height of the sine wave from its lowest to highest point",
      "  @Gen virtual Float amplitude { get {get(\"amplitude\")} set {set(\"amplitude\", it)} }",
      "",
      "  ** The distance from zero that the sine wave's amplitude is shifted",
      "  @Gen virtual Float offset { get {get(\"offset\")} set {set(\"offset\", it)} }",
      "}",
      ]
    verifyGen(src, src)
  }

  ** Generated output run thru the pipeline again is unchanged
  Void testIdempotent()
  {
    src := [
      "using xeto",
      "",
      "@Gen",
      "abstract class Logic : HxComp",
      "{",
      "  @Gen virtual Str? out() { get(\"out\") }",
      "}",
      ]
    first := gen(src.join("\n"))
    verifyEq(gen(first), first)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Run scan/gen/merge pipeline on source; return generated source
  private Str gen(Str src)
  {
    c := GenCompiler { it.logger = XetoLog.makeOutStream(Buf().out) }
    return genWith(c, c.ns.lib("hx.comps"), src)
  }

  ** Run pipeline against a temp lib compiled from xeto source
  ** Compile temp lib and gen; the "TempFuncs" placeholder class
  ** name is mapped to the actual temp lib funcs class name
  private Str genTemp(Str xetoSrc, Str src)
  {
    c := GenCompiler { it.logger = XetoLog.makeOutStream(Buf().out) }
    lib := c.ns.compileTempLib(xetoSrc)
    name := XetoUtil.fantomFuncsBaseName(lib) + "Funcs"
    out := genWith(c, lib, src.replace("TempFuncs", name))
    return out.replace(name, "TempFuncs")
  }

  private Str genWith(GenCompiler c, Lib lib, Str src)
  {
    pod := APod([lib], "test", File(`test/`))
    f := FileScanner(c, pod, File(`test/Test.fan`), src).scan
    pod.files.add(f)
    c.ast = Ast([pod])
    c.run([GenEdits()])
    return f.genLines.join("\n")
  }

  private Void verifyGen(Str[] src, Str[] expect)
  {
    actual := gen(src.join("\n"))
    verifyEq(actual, expect.join("\n"))
  }
}

