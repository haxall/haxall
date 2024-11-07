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
    verifyValidate(src, ["num":"bad", "str":n(123)], [
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
    fits := nsTest.fits(TestContext(), instance, spec, opts)
    verifyErrs("Fits Time", errs, expect)
    verifyEq(fits, errs.isEmpty)
  }

  ** Create opts with log to use for both compiler and fits
  Dict logOpts(Str key, XetoLogRec[] acc)
  {
    logger := |XetoLogRec rec| { acc.add(rec) }
    return Etc.dict1(key, Unsafe(logger))
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
}

