//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xeto::Lib
using xetoEnv
using xetoc
using haystack
using haystack::Dict
using haystack::Ref

**
** ValidateTest
**
@Js
class ValidateTest : AbstractXetoTest
{

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
      "Slot 'c': String must be non-empty for 'temp::Foo.c'",
      "Slot 'd': String must be non-empty for 'temp::MyNonEmpty'",
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
         }
         |>

    // all ok
    ok := ["a":["1"], "b":["1"]]
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
      "Slot 'a': Conflicting choice 'ph::DuctSection': DischargeDuct, ReturnDuct",
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
         }

         Bar: Dict {}

         @to-foo-1: Foo {}
         @to-bar-1: Bar {}
         @to-bar-2: Bar {}
         @to-eq-1: AcElecMeter {}
         |>

    refFoo  := Ref("to-foo-1")
    refBar  := Ref("to-bar-1")
    refBar2 := Ref("to-bar-2")
    refBars := [refBar, refBar2]
    refEq1  := Ref("to-eq-1")
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

    // target type not found (only in fitter)
    verifyFitsTime(srcAddPragma(src), toInstance(ok.dup.set("equipRef", refEqX)), [
      "Slot 'equipRef': Ref target spec not found: 'bad.lib::BadSpec'",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Verify
//////////////////////////////////////////////////////////////////////////

  ** Verify both compile time and fits time for spec called Foo in src
  Void verifyValidate(Str src, Str:Obj tags, Str[] expect)
  {
    instance := toInstance(tags)
    src = srcAddPragma(src)
    verifyCompileTime(src, instance, expect)
    verifyFitsTime(src, instance, expect)
  }

  ** Verify the instance bundled in the library source at compile time
  Void verifyCompileTime(Str src, Dict instance, Str[] expect)
  {
    // rewrite source to include the instance
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
      lib = nsTest.compileLib(src, opts)
    catch (Err e)
      {}

    verifyErrs("Compile Time", errs, expect)
  }

  ** Verify the instance checked using fits after lib src is compiled
  Void verifyFitsTime(Str src, Dict instance, Str[] expect)
  {
    lib  := nsTest.compileLib(src)
    spec := lib.spec("Foo")
    errs := XetoLogRec[,]
    opts := logOpts("explain", errs)
    cx   := initContext(lib)
    fits := nsTest.fits(cx, instance, spec, opts)
    verifyErrs("Fits Time", errs, expect)
    verifyEq(fits, errs.isEmpty)
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
  Void verifyErrs(Str title, XetoLogRec[] actual, Str[] expect)
  {
    isCompileTime := title.startsWith("Compile")
    if (isDebug)
    {
      echo("\n-- $title [$actual.size]")
      echo(actual.join("\n"))
    }

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
    }
    verifyEq(actual.size, expect.size)
  }

  ** To instance with tags sorted alphabetically
  private Dict toInstance(Str:Obj tags)
  {
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
         depends: { {lib:"sys"}, {lib:"ph"} }
       >
       """ + src
  }

  ** Append @x instance to the soruce
  private Str srcAppendInstance(Str src, Dict instance)
  {
    ns := nsTest
    buf := StrBuf()
    buf.add(src).add("\n\n").add("@x: ")
    ns.writeData(buf.out, instance)
    return buf.toStr.replace("@x: Dict", "@x: Foo")
  }

  ** Namespace to use
  once LibNamespace nsTest()
  {
    createNamespace(["sys", "ph"])
  }

  ** Verbose debug flag
  Bool isDebug  := true

  ** TestContext recs for target resolution
  Ref:Dict recs := [:]

}

