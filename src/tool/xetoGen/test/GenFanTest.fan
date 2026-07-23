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
    lib := c.ns.lib("hx.comps")
    pod := APod([lib], "hxComps", File(`test/`))
    f := FileScanner(c, pod, File(`test/Test.fan`), src).scan
    f.types.each |t| { t.spec = lib.type(t.name) }
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

