//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xetom
using xetoc
using haystack

**
** ValidateTest
**
@Js
class ValidateTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Scalars
//////////////////////////////////////////////////////////////////////////

  Void testScalars()
  {
    verifyScalarErr(Date.today, "sys::Date", null)
    verifyScalarErr("foo", "sys::Date", "Type 'sys::Str' does not fit 'sys::Date'")

    verifyScalarErr("123-89-4567", "hx.test.xeto::TestSsn", null)
    verifyScalarErr("123-xx-4567", "hx.test.xeto::TestSsn", "String encoding does not match pattern for 'hx.test.xeto::TestSsn'")
  }

  Void verifyScalarErr(Obj? val, Str qname, Str? expect)
  {
    r := nsTest.validate(val, nsTest.spec(qname))

    if (expect == null)
    {
      verifyEq(r.hasErrs, false)
      verifyEq(r.numErrs, 0)
      verifyEq(r.items.size, 0)
      return
    }

    verifyEq(r.numErrs, 1)
    verifyEq(r.hasErrs, true)

    item := r.items.first
    verifySame(item.level, ValidateLevel.err)
    verifySame(item.subject, Etc.dict0)
    verifyEq(item.slot, null)
    verifyEq(item.msg, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Types
//////////////////////////////////////////////////////////////////////////

  Void testTypes()
  {
    src :=
    Str<|Foo: Dict {
           num: Number
           str: Str
         }|>

    // all ok
    verifyValidate(src, ["num":n(123), "str":"hi"], [,])

    // invalid types
    verifyValidate(src, ["num":"bad", "str":n(123), "ref":n(123)], [
        "Invalid 'sys::Number' string value: \"bad\"
         Slot 'num': Slot type is 'sys::Number', value type is 'sys::Str'",
        "Slot 'str': Slot type is 'sys::Str', value type is 'sys::Number'",
      ])
  }

//////////////////////////////////////////////////////////////////////////
// Fixed
//////////////////////////////////////////////////////////////////////////

  Void testFixed()
  {
    src :=
    Str<|Foo: {
           n: Number <fixed> 123kW
           u: Unit <fixed> "%"
         }
         |>

    // all ok
    verifyValidate(src, ["n":n(123, "kW"), "u":Unit("%"), ], [,])

    // range errors
    verifyValidate(src, ["n":n(123, "W"), "u":Unit("A")], [
      "Slot 'n': Must have fixed value '123kW'",
      "Slot 'u': Must have fixed value '%'",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Numbers
//////////////////////////////////////////////////////////////////////////

  Void testNumbers()
  {
    src :=
    Str<|Foo: {
           a: Number <minVal:Number 10, maxVal:Number 20, quantity:"length">
           b: Number <quantity:"power">
           c: Number <unit:"kW", maxVal:100>
         }
         |>

    // all ok
    verifyValidate(src, ["a":n(10, "ft"), "b":n(2, "W"), "c":n(3, "kW")], [,])

    // range errors
    verifyValidate(src, ["a":n(21, "m"), "b":n(2, "W"), "c":n(100.4f, "kW")], [
      "Slot 'a': Number 21m > maxVal 20",
      "Slot 'c': Number 100.4kW > maxVal 100",
    ])

    // unit errors
    verifyValidate(src, ["a":n(20, "min"), "b":n(2, "kWh"), "c":n(3, "W")], [
      "Slot 'a': Number must be 'length' unit; 'min' has quantity of 'time'",
      "Slot 'b': Number must be 'power' unit; 'kWh' has quantity of 'energy'",
      "Slot 'c': Number 3W must have unit of 'kW'",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Strs
//////////////////////////////////////////////////////////////////////////

  Void testStrs()
  {
    src :=
    Str<|Foo: {
           a: Str <pattern:"\\d{4}-\\d{2}-\\d{2}">
           b: MyDate
           c: Str <nonEmpty>
           d: MyNonEmpty
           e: Str <minSize:2, maxSize:4>
           f: MySizeStr
         }

         MyDate: Scalar <pattern:"\\d{4}-\\d{2}-\\d{2}">

         MyNonEmpty: Scalar <nonEmpty>

         MySizeStr: Scalar <minSize:2, maxSize:4>
         |>

    // all ok
    ok := ["a":"2024-11-07", "b":"1234-56-78", "c":"!", "d":"!", "e":"ab", "f":"abce"]
    verifyValidate(src, ok, [,])

    // bad pattern
    verifyValidate(src, ok.dup.setAll(["a":"2024-11-7", "b":"1234_56_78"]), [
      "Slot 'a': String encoding does not match pattern for 'temp::Foo.a'",
      "Slot 'b': String encoding does not match pattern for 'temp::MyDate'",
    ])

    // empty
    verifyValidate(src, ok.dup.setAll(["c":"", "d":" "]), [
      "Slot 'c': String must be non-empty",
      "Slot 'd': String must be non-empty",
    ])

    // minSize
    verifyValidate(src, ok.dup.setAll(["e":"", "f":"1"]), [
      "Slot 'e': String size 0 < minSize 2",
      "Slot 'f': String size 1 < minSize 2",
    ])

    // maxSize
    verifyValidate(src, ok.dup.setAll(["e":"12345", "f":"123456"]), [
      "Slot 'e': String size 5 > maxSize 4",
      "Slot 'f': String size 6 > maxSize 4",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Lists
//////////////////////////////////////////////////////////////////////////

  Void testList()
  {
    src :=
    Str<|Foo: {
           a: List<of:Str, nonEmpty>
           b: List<of:Str, minSize:1, maxSize:3>
           c: List<of:Number>
           d: List?<of:Uri>
         }
         |>

    // all ok
    ok := ["a":["1"], "b":["1"], "c":[,]]
    verifyValidate(src, ok, [,])

    // empty
    verifyValidate(src, ok.dup.setAll(["a":Str[,]]), [
      "Slot 'a': List must be non-empty",
    ])

    // minSize
    verifyValidate(src, ok.dup.setAll(["b":Str[,]]), [
      "Slot 'b': List size 0 < minSize 1",
    ])

    // maxSize
    verifyValidate(src, ok.dup.setAll(["b":["1", "2", "3", "4"]]), [
      "Slot 'b': List size 4 > maxSize 3",
    ])

    // item types
    verifyValidate(src, ok.dup.set("c", [n(123), Etc.dict0, 123, `uri`]), [
      "Slot 'c': List item type is 'sys::Number', item type is 'sys::Dict'",
      "Slot 'c': List item type is 'sys::Number', item type is 'sys::Uri'",
    ])

    // item types using list subtype, for compile-time we require nominal
    // typing but for fits-time we allow structure typing
    verifyRunTime(src, ok.dup.set("d", [`uri1`, n(123), Etc.dict0, `uri2`]), [
      "Slot 'd': List item type is 'sys::Uri', item type is 'sys::Number'",
      "Slot 'd': List item type is 'sys::Uri', item type is 'sys::Dict'",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Enums
//////////////////////////////////////////////////////////////////////////

  Void testEnums()
  {
    src :=
    Str<|Foo: Dict {
           c: Color
           p: PrimaryFunction
           s: CurStatus
         }

         Color: Enum { red, blue }
         |>

    // all ok
    verifyValidate(src, ["s":"down", "p":"Bank Branch", "c":"red"], [,])

    // bad keys
    verifyValidate(src, ["c":"x", "p":"bankBranch", "s":"y"], [
      "Slot 'c': Invalid key 'x' for enum type 'temp::Color'",
      "Slot 'p': Invalid key 'bankBranch' for enum type 'ph::PrimaryFunction'",
      "Slot 's': Invalid key 'y' for enum type 'ph::CurStatus'",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Choices
//////////////////////////////////////////////////////////////////////////

  Void testChoices()
  {
    src :=
    Str<|Foo: Dict {
           a: DuctSection
           b: PipeSection?
           c: HeatingProcess <multiChoice>
         }
         |>

    // all ok
    verifyValidate(src, ["discharge":m, "hotWaterHeating":m, "natualGasHeating":m], [,])

    // missing required
    verifyValidate(src, [:], [
      "Slot 'a': Missing required choice 'ph::DuctSection'",
      "Slot 'c': Missing required choice 'ph::HeatingProcess'",
    ])

    // conflicting
    verifyValidate(src, ["discharge":m, "return":m, "elecHeating":m, "hotWaterHeating":m,], [
      "Slot 'a': Conflicting choice 'ph::DuctSection': DischargeDuctSection, ReturnDuctSection",
    ])
  }


//////////////////////////////////////////////////////////////////////////
// Refs
//////////////////////////////////////////////////////////////////////////

  Void testRefs()
  {
    src :=
    Str<|Foo: Dict {
           a: Ref
           b: Ref?
           c: Ref<of:Bar>
           d: MultiRef<of:Bar>
           e: MultiRef?<of:Bar>
           equipRef: Ref?<of:Equip>
           f: List?<of:Ref<of:Equip>>
         }

         Bar: Dict {}

         @to-foo-1: Foo {}
         @to-bar-1: Bar {}
         @to-bar-2: Bar {}
         @to-eq-1: AcElecMeter {}
         @to-eq-2: Ahu {}
         |>

    refFoo  := Ref("to-foo-1")
    refBar  := Ref("to-bar-1")
    refBar2 := Ref("to-bar-2")
    refBars := [refBar, refBar2]
    refEq1  := Ref("to-eq-1")
    refEq2  := Ref("to-eq-2")
    refEqX  := Ref("to-eq-x")
    refErr1 := Ref("to-err-1")
    refErr2 := Ref("to-err-2")
    refErr3 := Ref("to-err-3")
    refErr4 := Ref("to-err-4")
    refErr5 := Ref("to-err-5")

    recs[refFoo]  = Etc.makeDict(["id":refFoo,  "spec":Ref("temp::Foo")])
    recs[refBar]  = Etc.makeDict(["id":refBar,  "spec":Ref("temp::Bar")])
    recs[refBar2] = Etc.makeDict(["id":refBar2, "spec":Ref("temp::Bar")])
    recs[refEq1]  = Etc.makeDict(["id":refEq1,  "spec":Ref("ph::AcElecMeter")])
    recs[refEq2]  = Etc.makeDict(["id":refEq2,  "spec":Ref("ph::Ahu")])
    recs[refEqX]  = Etc.makeDict(["id":refEq1,  "spec":Ref("bad.lib::BadSpec")])

    // all ok
    ok := Str:Obj["a":refFoo, "c":refBar, "d":refBar]
    verifyValidate(src, ok, [,])
    verifyValidate(src, ok.dup.setAll(["d":refBars]), [,])

    // invalid multiref types
    verifyValidate(src, ok.dup.setAll(["d":n(123), "e":[n(123)], "u":refFoo]), [
      "Slot 'd': Slot type is 'sys::MultiRef', value type is 'sys::Number'",
      "Slot 'e': Slot type is 'sys::MultiRef', value type is 'sys::List'",
    ])

    // unresolved refs (in compiler this happens in Resolve step)
    verifyValidate(src, ["a":refErr1, "b":refErr2, "c":refErr3, "d":[refBar2, refErr4, refBar], "u":refErr5], [
      "Unresolved instance: to-err-1
       Slot 'a': Unresolved ref @to-err-1",

      "Unresolved instance: to-err-2
       Slot 'b': Unresolved ref @to-err-2",

      "Unresolved instance: to-err-3
       Slot 'c': Unresolved ref @to-err-3",

      "Unresolved instance: to-err-4
       Slot 'd': Unresolved ref @to-err-4",

      "Unresolved instance: to-err-5
       Slot 'u': Unresolved ref @to-err-5",
    ])

    // invalid target types
    verifyValidate(src, ["a":refFoo, "b":refFoo, "c":refFoo, "d":[refBar2, refFoo], "e":refFoo, "equipRef":refEq1], [
      "Slot 'c': Ref target must be 'temp::Bar', target is 'temp::Foo'",
      "Slot 'd': Ref target must be 'temp::Bar', target is 'temp::Foo'",
      "Slot 'e': Ref target must be 'temp::Bar', target is 'temp::Foo'",
    ])

    // invalid target types in lib
    verifyValidate(src, ["a":refFoo, "b":refFoo, "c":Ref("ph::op:about"), "d":[refBar2, Ref("ph::filetype:json")]], [
      "Slot 'c': Ref target must be 'temp::Bar', target is 'ph::Op'",
      "Slot 'd': Ref target must be 'temp::Bar', target is 'ph::Filetype'",
    ])

    // ref type is spec (only in fitter)
    verifyRunTime(src, ok.dup.set("equipRef", Ref("ph::Site")), [
      "Slot 'equipRef': Ref target must be 'ph::Equip', target is 'sys::Spec'",
    ])

    // target type not found (only in fitter)
    verifyRunTime(src, ok.dup.set("equipRef", refEqX).set("enum", Ref("ph::WeatherCondEnum")), [
      "Slot 'equipRef': Ref target spec not found: 'bad.lib::BadSpec'",
    ])

    // list of refs
    verifyRunTime(src, ok.dup.set("f", [refEq1, refEq2]), [,])
  }

//////////////////////////////////////////////////////////////////////////
// Globals
//////////////////////////////////////////////////////////////////////////

  Void testGlobals()
  {
    // test ph global
    src :=
    Str<|Foo: PhEntity {}
         |>

    // invalid target types in lib
    verifyValidate(src, ["id":Ref.gen, "area":n(13, "ft"), "site":Date.today], [
      "Slot 'area': Number must be 'area' unit; 'ft' has quantity of 'length'",
      "Slot 'site': Global type is 'sys::Marker', value type is 'sys::Date'",
      ])


    // global in lib AST
    src =
    Str<|Foo: Dict {
           *baz: Number <quantity:"length", minVal:0>
         }
         |>


    // invalid target types in lib
    verifyCompileTime(src, toInstance(["baz":Uri("file.txt")]), [
      "Slot 'baz': Global type is 'sys::Number', value type is 'sys::Uri'",
      ])

    // invalid target types in lib
    verifyCompileTime(src, toInstance(["baz":n(123, "°C")]), [
      "Slot 'baz': Number must be 'length' unit; '°C' has quantity of 'temperature'",
      ])
  }

//////////////////////////////////////////////////////////////////////////
// Protocol
//////////////////////////////////////////////////////////////////////////

  Void testProtocol()
  {
    ns := createNamespace(["ph.protocols"])

    // quick tests for protocol regex

    // bacnet
    re := Regex(ns.spec("ph.protocols::BacnetAddr.addr").meta["pattern"])
    verifyEq(re.matches("AO123"), true)
    verifyEq(re.matches("ao123"), false)
    verifyEq(re.matches("AO"), false)
    verifyEq(re.matches("123"), false)
    verifyEq(re.matches("ABCD9"), true)
    verifyEq(re.matches("LAV9X"), false)

    re = Regex(ns.spec("ph.protocols::ModbusAddr.addr").meta["pattern"])
    verifyEq(re.matches("40000"),  true)
    verifyEq(re.matches("41234"),  true)
    verifyEq(re.matches("41abcd"), false)
    verifyEq(re.matches("4123"),   false)
    verifyEq(re.matches("412345"), false)
    verifyEq(re.matches("51234"),  false)
  }

//////////////////////////////////////////////////////////////////////////
// Verify
//////////////////////////////////////////////////////////////////////////

  ** Verify both compile time and fits time for spec called Foo in src
  Void verifyValidate(Str src, Str:Obj tags, Str[] expect)
  {
    instance := toInstance(tags)
    verifyCompileTime(src, instance, expect)
    verifyRunTime(src, instance, expect)
  }

  ** Verify the instance bundled in the library source at compile time
  Void verifyCompileTime(Str src, Dict instance, Str[] expect)
  {
    // rewrite source to include the instance
    src = srcAddPragma(src)
    src = srcAppendInstance(src, instance)

    if (isDebug)
    {
      echo
      echo("####")
      echo(src)
    }

    // compile with logger
    errs := XetoLogRec[,]
    opts := logOpts("log", errs)
    Lib? lib
    try
      lib = nsTest.compileTempLib(src, opts)
    catch (Err e)
      {}


    verifyErrs("Compile Time", instance, null, errs, expect)
  }

  ** Verify the instance checked using fits/validate after lib src is compiled
  Void verifyRunTime(Str src, Obj instance, Str[] expect)
  {
    src = srcAddPragma(src)
    instance = toInstance(instance)
    lib  := nsTest.compileTempLib(src)
    spec := lib.spec("Foo")
    errs := XetoLogRec[,]
    opts := logOpts("explain", errs)
    initContext(lib).asCur |cx|
    {
      r := nsTest.validate(instance, spec, opts)

      fits := nsTest.fits(instance, spec, opts)
      verifyErrs("Fits Time", instance, r, errs, expect)
      verifyEq(fits, errs.isEmpty)
    }
  }

  ** Create opts with log to use for both compiler and fits
  Dict logOpts(Str key, XetoLogRec[] acc)
  {
    logger := |XetoLogRec rec| { acc.add(rec) }
    return Etc.dict1(key, Unsafe(logger))
  }

  ** Create opts with log to use for both compiler and fits
  TestContext initContext(Lib lib)
  {
    cx := TestContext()
    cx.recs = recs.map |d->Dict|
    {
      specRef := d->spec.toStr
      if (!specRef.contains("temp")) return d
      specName := XetoUtil.qnameToName(specRef)
      return Etc.dictSet(d, "spec", Ref("$lib.name::$specName"))
    }
    return cx
  }

  ** Verify actual errors from compiler/fits against expected results
  Void verifyErrs(Str title, Obj instance, ValidateReport? r, XetoLogRec[] actual, Str[] expect)
  {
    isCompileTime := title.startsWith("Compile")
    if (isDebug)
    {
      echo("\n-- $title [$actual.size]")
      echo(actual.join("\n"))
    }

    normExpect := Str[,]
    actual.each |arec, i|
    {
      a := normTempLibName(arec.msg)
      e := expect.getSafe(i) ?: "-"
      if (e.contains("\n")) e = e.splitLines[isCompileTime ? 0 : 1]
      if (a != e)
      {
        echo("FAIL: $a")
        echo("      $e")
      }
      verifyEq(a, e)
      normExpect.add(e)
    }

    verifyEq(actual.size, expect.size)

    if (r != null)
    {
      verifyEq(r.items.size, normExpect.size)
      r.items.each |item, i| { verifyItem(instance, item, normExpect[i]) }
    }
  }

  private Void verifyItem(Obj instance, ValidateItem actual, Str expect)
  {
    level := ValidateLevel.err
    msg   := expect
    slot  := null
    if (msg.startsWith("Slot '"))
    {
      end := msg.index("':")
      slot = msg[6..<end]
      msg  = msg[end+2..-1].trim
    }

    verifySame(actual.level, level)
    verifySame(actual.subject, instance as Dict ?: Etc.dict0)
    verifyEq(actual.slot, slot)
    verifyEq(normTempLibName(actual.msg), msg)
  }

  ** To instance with tags sorted alphabetically
  private Dict toInstance(Obj x)
  {
    if (x is Dict) return x
    tags := (Str:Obj)x
    names := tags.keys.sort
    acc := Str:Obj[:] { ordered = true }
    names.each |n| { acc[n] = tags[n] }
    return Etc.makeDict(acc)
  }

  ** Add pragma with depends
  private Str srcAddPragma(Str src)
  {
    """pragma: Lib <
         version: "0.0.0"
         depends: { {lib:"sys"}, {lib:"ph"}, {lib:"hx.test.xeto"} }
       >
       """ + src
  }

  ** Append @x instance to the soruce
  private Str srcAppendInstance(Str src, Dict instance)
  {
    ns := nsTest
    buf := StrBuf()
    buf.add(src).add("\n\n").add("@x: ")
    ns.writeData(buf.out, Etc.dictRemove(instance, "id"))
    return buf.toStr.replace("@x: {", "@x: Foo {")
  }

  ** Namespace to use
  once Namespace nsTest()
  {
    createNamespace(["sys", "ph", "hx.test.xeto"])
  }

  ** TestContext recs for target resolution
  Ref:Dict recs := [:]

  ** Verbose debug flag
  Bool isDebug  := false

}

