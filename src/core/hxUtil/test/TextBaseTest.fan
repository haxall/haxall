//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    5 Aug 2025  Brian Frank  Creation
//

using xeto

**
** TextBaseTest
**
class TextBaseTest : Test
{

  Void test()
  {
    // init - empty
    dir := tempDir + `tb/`
    tb := TextBase(dir)
    d0 := tb.digest
    verifyList(tb, Str[,])

    // write a file
    tb.write("foo.txt", "foo val")
    d1 := tb.digest
    verifyList(tb, ["foo.txt"])
    verifyRead(tb, "foo.txt", "foo val")
    verifyNonexist(tb, "notthere.txt")

    // bad updates
    verifyErr(ArgErr#) { tb.write(".foo.txt", "bad") }
    verifyErr(ArgErr#) { tb.write("..foo.txt", "bad") }
    verifyErr(ArgErr#) { tb.write("/foo.txt", "bad") }
    verifyErr(ArgErr#) { tb.write("/foo/../bar.txt", "bad") }
    verifyErr(ArgErr#) { tb.rename("foo.txt", "/foo/../bar.txt") }
    verifyErr(ArgErr#) { tb.rename("foo.txt", ".bar") }
    verifyList(tb, ["foo.txt"])
    verifyRead(tb, "foo.txt", "foo val")
    verifyNonexist(tb, "notthere.txt")

    // create some files to ignore
    dir.plus(`.ignore`).out.print("ignore").close
    dir.plus(`sub/ignore.txt`).out.print("ignore").close
    verifyList(tb, ["foo.txt"])
    verifyBadName(tb, ".ignore.txt")
    verifyBadName(tb, "sub/ignore.txt")
    verifyBadName(tb, "sub")

    // write another
    tb.write("bar.txt", "bar val")
    d2 := tb.digest
    verifyList(tb, ["foo.txt", "bar.txt"])
    verifyRead(tb, "foo.txt", "foo val")
    verifyRead(tb, "bar.txt", "bar val")

    // now delete
    tb.delete("foo.txt")
    d3 := tb.digest
    verifyList(tb, ["bar.txt"])
    verifyNonexist(tb, "foo.txt")
    verifyRead(tb, "bar.txt", "bar val")

    // now rename bar.txt -> foo.txt
    tb.rename("bar.txt", "foo.txt")
    d4 := tb.digest

    // rewrite foo.txt
    tb.write("foo.txt", "foo val")
    d5 := tb.digest

    // recrete bar.txt
    tb.write("bar.txt", "bar val")
    d6 := tb.digest
    verifyList(tb, ["foo.txt", "bar.txt"])
    verifyRead(tb, "foo.txt", "foo val")
    verifyRead(tb, "bar.txt", "bar val")

    // verify digests
    verifyEq(d1, d5)
    verifyEq(d2, d6)
    restDigests := [d0, d1, d2, d3, d4]
    restDigests.each |di, i|
    {
      restDigests.each |dj, j|
      {
        if (i != j) verifyNotEq(di, dj)
      }
    }
  }

  Void verifyList(TextBase tb, Str[] expect)
  {
    verifyEq(tb.list.sort, expect.sort)
    tb.list.each |x| { verifyEq(tb.exists(x), true) }
  }

  Void verifyRead(TextBase tb, Str filename, Str expect)
  {
    verifyEq(tb.exists(filename), true)
    verifyEq(tb.read(filename), expect)
  }

  Void verifyNonexist(TextBase tb, Str filename)
  {
    verifyEq(tb.exists(filename), false)
    verifyEq(tb.read(filename, false), null)
    verifyErr(UnknownNameErr#) { tb.read(filename) }
    verifyErr(UnknownNameErr#) { tb.read(filename, true) }
  }

  Void verifyBadName(TextBase tb, Str filename)
  {
    verifyErr(ArgErr#) { tb.exists(filename) }
    verifyErr(ArgErr#) { tb.read(filename) }
    verifyErr(ArgErr#) { tb.read(filename, false) }
    verifyErr(ArgErr#) { tb.read(filename, true) }
    verifyErr(ArgErr#) { tb.write(filename, "xxx") }
    verifyErr(ArgErr#) { tb.delete(filename) }
  }


}

