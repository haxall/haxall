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
  Void testBasics()
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
// Verify
//////////////////////////////////////////////////////////////////////////

  ** Verify both compile time and fits time for spec called Foo in src
  Void verifyValidate(Str src, Str:Obj tags, Str[] expect)
  {
    instance := Etc.makeDict(tags)
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
    nsTest.fits(TestContext(), instance, spec, opts)
    verifyErrs("Fits Time", errs, expect)
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
      a := arec.msg
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
    createNamespace(["sys"])
  }

  ** Verbose debug flag
  Bool isDebug  := true
}

