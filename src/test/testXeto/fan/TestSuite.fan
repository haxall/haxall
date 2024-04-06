//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Dec 2022  Brian Frank  Creation
//

using util
using yaml
using xeto
using xeto::Dict
using xeto::Lib
using haystack
using haystack::Ref

**
** TestSuite runs all the declartive tests captured in YAML files.
**
class TestSuite : Test
{
  Void test() { run(Str[,]) }

  Void run(Str[] args)
  {
    testsDir := `src/test/testXeto/tests/`
    testsFile := testsDir + `sys.yaml`
    base := Env.cur.path.find { it.plus(testsFile).exists }
    if (base == null) throw Err("Test dir not found")
    r := DataTestRunner(this, args).runDir(base.plus(testsDir))
    if (r.numFails > 0) fail("TestSuite $r.numFails failures: $r.failed")
  }
}

** Main to run test suite straight from command line
class Main { Void main(Str[] args) { TestSuite().run(args) } }

**************************************************************************
** DataTestRunner
**************************************************************************

class DataTestRunner
{
  new make(Test test, Str[] args)
  {
    this.test     = test
    this.args     = args
    this.runAll   = args.isEmpty || args.contains("-all")
    this.verbose  = args.contains("-v")
  }

  This runDir(File dir)
  {
    dir.list.each |file|
    {
      if (file.ext != "yaml") return
      try
        runFile(file)
      catch (Err e)
        fail("Cannot parse file [$file.osPath]", e)
    }
    return this
  }

  This runFile(File file)
  {
    echo("   Run [$file.osPath] ...")
    YamlReader(file).parse.each |doc|
    {
      def := doc.decode
      if (def == null) return
      runTest(doc.loc, def)
    }
    return this
  }

  This runTest(FileLoc loc, Str:Obj? def)
  {
    name := def["name"] ?: "unknown"
    testName := loc.file.toUri.basename + "." + name

    if (skip(testName)) return this

    echo("   - $testName [Line $loc.line]")

    try
    {
      DataTestCase(this, testName, def).run
    }
    catch (Err e)
    {
      fail(testName, e)
    }
    return this
  }

  Bool skip(Str testName)
  {
    if (runAll) return false
    return !args.any { testName.contains(it) }
  }

  Void fail(Str testName, Err? e)
  {
    numFails++
    echo
    echo("TEST FAILED: $testName")
    e?.trace
    echo
    failed.add(testName)
  }

  XetoEnv env := XetoEnv.cur
  Str[] args
  Bool runAll
  Bool verbose
  Test test
  Int numFails
  Str[] failed := [,]
}

**************************************************************************
** DataTestCase
**************************************************************************

class DataTestCase
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(DataTestRunner runner, Str testName, Str:Obj? def)
  {
    this.runner   = runner
    this.test     = runner.test
    this.env      = runner.env
    this.testName = testName
    this.def      = def
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  Void run()
  {
    def.each |v, n|
    {
      if (n == "name") return
      runStep(n, v)
    }
    if (numVerifies == 0) echo("     WARN: no verifies")
  }

  Void runStep(Str name, Obj? val)
  {
    m := typeof.method(name)
    m.callOn(this, [val])
  }

  Bool hasStep(Str name)
  {
    def.containsKey(name)
  }

//////////////////////////////////////////////////////////////////////////
// Steps
//////////////////////////////////////////////////////////////////////////

  Void loadLib(Str qname)
  {
    this.libRef = env.lib(qname)
  }

  Void compileLib(Str src)
  {
    this.libRef = compile |opts| { env.compileLib(src, opts) }
    if (runner.verbose && libRef != null) env.print(env.genAst(libRef), Env.cur.out, Etc.dict1("json", Marker.val))
    //env.print(libRef)
  }

  Void compileData(Str src)
  {
     this.dataRef = compile |opts| { env.compileData(src, opts) }
  }

  private Obj? compile(|Dict opts->Obj| f)
  {
    errs = XetoLogRec[,]
    logger := |XetoLogRec rec| { errs.add(rec) }
    opts := Etc.dict1("log", Unsafe(logger))

    try
      return f(opts)
    catch (Err e)
      {}

    if (runner.verbose) errs.each |err| { echo(err) }

    /// if we are not checking errors, then report them and fail
    if (hasStep("verifyErrs")) return null
    errs.each |err| { echo(err) }
    throw Err("Compile failed [$errs.size errors]")
  }

  Void verifyType(Str:Obj? expect)
  {
    verifySpec(lib.type(expect.getChecked("name")), expect)
  }

  Void verifyTypes(Str:Obj? expect)
  {
    expect.each |e, n| { verifySpec(lib.type(n), e) }
  }

  Void verifyData(Obj expect)
  {
    verifyVal(data, expect)
  }

  Void verifySpecIs(LibNamespace ns, [Str:Obj][] list)
  {
    list.each |map|
    {
      a := spec(map.getChecked("a"))
      b := spec(map.getChecked("b"))
      expect := (Bool)map.getChecked("expect")
      //echo("~~ verifySpecIs $a fits $b ?= $expect")

      verifyEq(a.isa(b), expect, "$a is $b")

      // specIs(a, b) true requires spedFits(a, b) to be true also
      if (expect) verifyEq(ns.specFits(a, b), expect, "$a fits $b")

      // check for isFoo flags
      // TODO
      // m := a.typeof.method("is${b.name}", false)
      // if (m != null) verifyEq(m.callOn(a, [b]), expect, m.qname)
    }
  }

  Void verifySpecFits(LibNamespace ns, [Str:Obj][] list)
  {
    list.each |map|
    {
      a := spec(map.getChecked("a"))
      b := spec(map.getChecked("b"))
      expect := (Bool)map.getChecked("expect")
      //echo("~~ verifySpecFits $a fits $b ?= $expect")
      verifyEq(ns.specFits(a, b), expect, "$a fits $b")
    }
  }

  Void verifyJsonAst(Str expect)
  {
    s := StrBuf()
    env.print(env.genAst(lib), s.out, Etc.dict1("json", Marker.val))
    actual := s.toStr

    // echo(actual)

    // verify its actually Json
    JsonInStream(actual.in).readJson

    verifyStr(actual, expect)
  }

  Void verifyErrs(Str expectLinesStr)
  {
    expectLines := expectLinesStr.splitLines.mapNotNull |line| { line.trimToNull }

    errs.each |err, i|
    {
      expect := expectLines.getSafe(i)
      actual := normQName(err.msg)

      if (expect == null) return // check sizes below

      if (runner.verbose)
      {
        echo("     ~ $expect")
        echo("       $actual")
      }
      verifyEq(actual, expect)
    }

    verifyEq(errs.size, expectLines.size, "Actual errors $errs.size != $expectLines.size expected")
  }

//////////////////////////////////////////////////////////////////////////
// Spec Verifies
//////////////////////////////////////////////////////////////////////////

  Void verifySpec(Spec spec, Str:Obj? expect)
  {
    if (spec.isType)
    {
      verifyEq(spec.qname, spec.lib.name + "::" + spec.name)
      verifySame(spec.type, spec)
      verifyQName(spec.base, expect["base"])
    }
    else
    {
      verifyQName(spec.type, expect.getChecked("type"))
    }
    verifyMeta(spec, expect["meta"])
    verifySlots(spec, expect["slots"])
  }

  Void verifyMeta(Spec spec, [Str:Obj?]? expect)
  {
    if (expect == null)
    {
      verifyEq(spec.metaOwn.isEmpty, true, spec.qname)
      return
    }

    expect.each |e, n| { verifyMetaPair(spec, n, e) }
    spec.meta.each |v, n| { verify(expect.containsKey(n), "$spec $n missing") }
    spec.metaOwn.each |v, n| { verify(expect.containsKey(n), n) }
  }

  Void verifyMetaPair(Spec spec, Str name, Obj expect)
  {
    if (expect is Str && expect.toStr.startsWith("inherit"))
      verifyMetaInherit(spec, name)
    else
      verifyMetaOwn(spec, name, expect)
  }

  Void verifyMetaInherit(Spec spec, Str expect)
  {
    name := expect
    sp := expect.index(" ")
    inheritFrom := spec.base
    if (sp != null)
    {
      throw Err("not done")
    }

    verifyEq(spec.metaOwn.has(name), false, name)
    verifyEq(spec.metaOwn.missing(name), true)
    verifyEq(spec.metaOwn[name], null)
    verifyErr(UnresolvedErr#) { spec.metaOwn.trap(name) } // should be UnknownNameErr depend problem

    verifyEq(spec.has(name), true, name)
    verifyEq(spec.missing(name), false)
    verifySame(spec.get(name), inheritFrom.get(name))
  }

  Void verifyMetaOwn(Spec spec, Str name, Obj expect)
  {
    verifyEq(spec.metaOwn.has(name), true, name)
    verifyEq(spec.metaOwn.missing(name), false)
    verifyVal(spec.metaOwn[name], expect)

    verifyEq(spec.has(name), true, name)
    verifyEq(spec.missing(name), false)
    verifySame(spec.get(name), spec.metaOwn.get(name))

    verifyVal(spec.get(name), expect)
  }

  Void verifySlots(Spec spec, [Str:Obj?]? expect)
  {
    if (expect == null)
    {
      verifyEq(spec.slotsOwn.isEmpty, true)
      verifyEq(spec.slots.isEmpty, true)
      return
    }
    expect.each |e, n| { verifySlot(spec, n, e) }
    spec.slots.each |v| { verify(expect.containsKey(v.name)) }
    spec.slotsOwn.each |v| { verify(expect.containsKey(v.name)) }
    verifyEq(spec.slots.names.sort, Str[,].addAll(expect.keys.sort))
  }

  Void verifySlot(Spec spec, Str name, Obj expect)
  {
    verifyEq(spec.slots.has(name), true)
    verifyEq(spec.slots.missing(name), false)
    if (expect is Str && expect.toStr.startsWith("inherit"))
    {
      verifySlotInherit(spec, name, expect)
    }
    else if (spec.slot(name, false) !== spec.slotOwn(name, false))
    {
      verifySlotOverride(spec, name, expect)
    }
    else
    {
      verifySlotOwn(spec, name, expect)
    }
  }

  Void verifySlotOwn(Spec spec, Str name, Obj expect)
  {
    slot := spec.slot(name)
    verifySame(spec.slotOwn(name), slot)
    verifySame(spec.slots.get(name), slot)
    verifySame(spec.slotsOwn.get(name), slot)
    verifySpec(slot, expect)
  }

  Void verifySlotInherit(Spec spec, Str name, Obj expect)
  {
    slot := spec.slot(name)
    verifySame(spec.slotOwn(name, false), null)
    verifySame(spec.slots.get(name), slot)
    verifySame(spec.slotsOwn.get(name, false), null)
  }

  Void verifySlotOverride(Spec spec, Str name, Obj expect)
  {
    slot := spec.slot(name)
    own := spec.slotOwn(name)
    verifyNotSame(slot, own)
    verifySame(spec.slots.get(name), slot)
    verifySame(spec.slotsOwn.get(name), own)
    verifySpec(slot, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Data Verifies
//////////////////////////////////////////////////////////////////////////

  Void verifyVal(Obj? val, Obj? expect)
  {
    if (expect == null) return
    type := env.specOf(val)
    if (type.isa(env.type("sys::Scalar")))
      verifyScalar(val, type, expect)
    else if (type.isa(env.type("sys::Dict")))
      verifyDict(val, expect)
    else
      throw Err("Unhandled type: $type")
  }

  Void verifyScalar(Obj val, Spec type, Str expect)
  {
    // scalar expect format is "<type> <val>"
    expectType := expect
    expectVal := null
    sp := expect.index(" ")
    if (sp != null)
    {
      expectType = expect[0..<sp]
      expectVal  = expect[sp+1..-1].trim
    }

    verifyQName(type, expectType)
    if (expectVal != null)
    {
      // this is really ugly
      if (type.qname == "sys::Duration" && expectVal == "0sec")
        verifyEq(val, 0ns)
      else
        verifyStr(scalarToStr(val), expectVal)
    }
  }

  private Str scalarToStr(Obj x)
  {
    if (x === Remove.val) return "none"
    return x.toStr
  }

  Void verifyDict(Dict dict, Str:Obj expect)
  {
    verifyDictSpec(dict, expect.getChecked("spec"))
    expect.each |e, n|
    {
      if (n == "spec") return
      verifyVal(dict[n], e)
    }
    dict.each |v, n| { verify(expect[n] != null) }
  }

  Void verifyDictSpec(Dict dict, Str expect)
  {
    verifyEq(env.specOf(dict).qname, expect)
    if (expect == "sys::Dict")
    {
      verifyEq(dict["spec"], null)
      verifyEq(dict.has("spec"), false)
    }
    else
    {
      verifyEq(dict["spec"], Ref(expect))
      verifyEq(dict.has("spec"), true)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Lib lib()
  {
    libRef ?: throw Err("Missing loadLib/compileLib")
  }

  Obj data()
  {
    dataRef ?: throw Err("Missing compileData")
  }

  Spec spec(Str qname)
  {
    dot := qname.indexr(".")
    Str? slot := null
    if (dot != null)
    {
      slot = qname[dot+1..-1]
      qname = qname[0..<dot]
    }

    Spec type := qname.startsWith("test::") ?
                     lib.type(qname[6..-1]) :
                     env.type(qname)

    return slot == null ?
           type :
           type.slot(slot)
  }

  Void verifyQName(Spec? actual, Str? expected)
  {
    if (expected == null) { verifyEq(actual, null); return }
    if (expected.startsWith("test::"))
      expected = lib.name + "::" + expected[expected.index(":")+2..-1]
    verifyEq(actual.qname, expected)
  }

  Str normQName(Str msg)
  {
    // normalize temp123::X to temp::X
    Int? tempi := 0
    while (true)
    {
      tempi = msg.index("temp", tempi+1)
      if (tempi == null) break
      colons := msg.index("::", tempi+1)
      msg = msg[0..<tempi+4] + msg[colons..-1]
    }
    return msg
  }

  Void verifyStr(Str actual, Str expected)
  {
    actual = actual.trim
    expected = expected.trim

    if (runner.verbose || actual != expected)
    {
      echo
      echo("--- Str [$testName] ---")
      dump(actual, expected)
    }
    verifyEq(actual, expected)
  }

  Void dump(Str a, Str b)
  {
    echo
    aLines := a.splitLines
    bLines := b.splitLines
    max := aLines.size.max(bLines.size)
    for (i := 0; i<max; ++i)
    {
      aLine := aLines.getSafe(i) ?: ""
      bLine := bLines.getSafe(i) ?: ""
      echo("$i:".padr(3) +  aLine)
      echo("   "         +  bLine)
      if (aLine != bLine)
      {
        s := StrBuf()
        aLine.each |ch, j|
        {
          match := bLine.getSafe(j) == ch
          s.add(match ? "_" : "^")
        }
        echo("   " + s)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Test Verifies
//////////////////////////////////////////////////////////////////////////

  Void verify(Bool cond, Str? msg := null)
  {
    numVerifies++
    test.verify(cond, msg)
  }

  Void verifyErr(Type? errType, |Test| c)
  {
    numVerifies++
    test.verifyErr(errType, c)
  }

  Void verifyEq(Obj? a, Obj? b, Str? msg := null)
  {
    // if (a != b) echo("  FAIL: $a [${a?.typeof}] ?= $b [${b?.typeof}] | $msg")
    numVerifies++
    test.verifyEq(a, b, msg)
  }

  Void verifySame(Obj? a, Obj? b, Str? msg := null)
  {
    numVerifies++
    test.verifySame(a, b, msg)
  }

  Void verifyNotSame(Obj? a, Obj? b, Str? msg := null)
  {
    numVerifies++
    test.verifyNotSame(a, b, msg)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  DataTestRunner runner     // make
  XetoEnv env               // make
  Test test                 // make
  Str testName              // make
  Str:Obj? def              // make
  XetoLogRec[]? errs        // compileLib, compileData
  Lib? libRef               // compileLib, loadLib
  Obj? dataRef              // compileData
  Int numVerifies           // verifyX
}

