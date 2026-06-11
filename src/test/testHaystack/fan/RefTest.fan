//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Sep 2016  Brian Frank  Creation
//

using xeto
using haystack

**
** RefTest
**
@Js
class RefTest : HaystackTest
{
  Void testSegs()
  {
    verifyEq(RefSeg("a", "b"), RefSeg("a", "b"))
    verifyNotEq(RefSeg("a", "b"), RefSeg("a", "!"))
    verifyNotEq(RefSeg("a", "b"), RefSeg("!", "b"))

    verifySegs("x", [RefSeg("", "x")])
    verifySegs("foo", [RefSeg("", "foo")])
    verifySegs("x:y", [RefSeg("x", "y")])
    verifySegs(":y", [RefSeg("", "y")])
    verifySegs("x:", [RefSeg("x", "")])
    verifySegs(":", [RefSeg("", "")])
    verifySegs("x:y:a:b", [RefSeg("x", "y"), RefSeg("a", "b")])
    verifySegs("x:y:a", [RefSeg("x", "y"), RefSeg("", "a")])
    verifySegs("x:y:a:b:c:d", [RefSeg("x", "y"), RefSeg("a", "b"), RefSeg("c", "d")])
    verifySegs("x:y:a:b:c", [RefSeg("x", "y"), RefSeg("a", "b"), RefSeg("", "c")])
    verifySegs("p:demo", [RefSeg("p", "demo")])
    verifySegs("p:demo:", [RefSeg("p", "demo"), RefSeg("", "")])
    verifySegs("p:demo:r:f6d583b-5a5a04e7", [RefSeg("p", "demo"), RefSeg("r", "f6d583b-5a5a04e7")])
    verifySegs("p:demo:r:f6d583b:x:5a5a04e7", [RefSeg("p", "demo"), RefSeg("r", "f6d583b"), RefSeg("x", "5a5a04e7")])

    x := Ref.gen
    verifyEq(x.segs.size, 1)
    verifyEq(x.segs[0].scheme, "")
    verifyEq(x.segs[0].body, x.toStr)

    x = Ref.makeHandle(x.handle)
    verifyEq(x.segs.size, 1)
    verifyEq(x.segs[0].scheme, "")
    verifyEq(x.segs[0].body, x.toStr)
  }

  Void verifySegs(Str id, RefSeg[] segs)
  {
    ref := Ref(id)
    verifyEq(ref.segs, segs)
  }

  Void testIsRel()
  {
    verifyEq(Ref("x").isRel, true)
    verifyEq(Ref("foo").isRel, true)
    verifyEq(Ref("1f729e3b-0b21ed12").isRel, true)

    verifyEq(Ref("x:y").isRel, false)
    verifyEq(Ref("x:").isRel, false)
    verifyEq(Ref("p:demo").isRel, false)
    verifyEq(Ref("p:demo:r").isRel, false)
    verifyEq(Ref("p:demo:r:").isRel, false)
    verifyEq(Ref("p:demo:r:foo").isRel, false)
  }

  Void testToRel()
  {
    verifyToRel("x", "x:", null)
    verifyToRel("x:", "x:", null)
    verifyToRel("x:y", "x:", "y")
    verifyToRel("p:demo", "p:", "demo")
    verifyToRel("px:demo", "p:", null)
    verifyToRel("p:demo:r:foo-bar", "p:demo:r:", "foo-bar")
  }

  Void verifyToRel(Str refStr, Str prefix, Str? expected)
  {
    ref := Ref(refStr, "dis")
    // echo("-- $ref " + ref.toRel(prefix) + " ?= " + expected)
    if (expected == null)
      verifySame(ref.toRel(prefix), ref)
    else
      verifyValEq(ref.toRel(prefix), Ref(expected, "dis"))
  }

  Void testToProjRel()
  {
    verifyToProjRel("p:demo:r:x", "x")
    verifyToProjRel("p:demo:r:foo", "foo")
    verifyToProjRel("r:x", null)
    verifyToProjRel("proj:demo:r:x", null)
    verifyToProjRel("u:matthew", null)
    verifyToProjRel("foo:bar:r:x", null)
  }

  private Void verifyToProjRel(Str refStr, Str? expected)
  {
    ref := Ref(refStr, "dis")
    if (expected == null)
    {
      verifySame(ref.toProjRel, ref)
    }
    else
    {
      x := ref.toProjRel
      verifyNotSame(x, ref)
      verifyValEq(x, Ref(expected, "dis"))
      verifyEq(x.segs.size, 1)
      verifyEq(x.segs[0].scheme, "")
      verifyEq(x.segs[0].body, expected)
    }
  }

  Void testToAbs()
  {
    verifyValEq(Ref("foo").toAbs("p:"), Ref("p:foo"))
    verifyValEq(Ref("foo", "dis").toAbs("p:"), Ref("p:foo", "dis"))
    verifyErr(ArgErr#) { Ref("foo").toAbs("p") }
    verifyErr(ArgErr#) { Ref("foo").toAbs("x y") }
  }

  Void testUri()
  {
    // not a uri ref
    verifyEq(Ref("foo").isUri, false)
    verifyEq(Ref("foo").toUri(false), null)
    verifyEq(Ref("p:demo:r:abc").isUri, false)
    verifyEq(Ref("p:demo:r:abc").toUri(false), null)
    verifyErr(UnsupportedErr#) { Ref("foo").toUri }
    verifyErr(UnsupportedErr#) { Ref("foo").toUri(true) }

    // simple URIs
    verifyUri(`http://example.com`)
    verifyUri(`http://example.com/`)
    verifyUri(`http://example.com/foo`)
    verifyUri(`http://example.com/foo/bar`)
    verifyUri(`https://example.com/path?q=hello`)
    verifyUri(`https://example.com/path?q=hello&x=1`)
    verifyUri(`https://example.com/path#frag`)
    verifyUri(`https://example.com/path?q=1#frag`)
    verifyUri(`ftp://files.example.com/pub/docs`)

    // URIs with characters that need encoding
    verifyUri(`http://example.com/a@b`)
    verifyUri(`http://example.com/foo/bar?a=1&b=2`)
    verifyUri(`http://example.com/path with spaces`)
    verifyUri(`http://example.com/café`)
    verifyUri(`http://user:pass@host/path`)

    // tilde in URI
    verifyUri(`http://example.com/~user/home`)

    // edge cases
    verifyUri(`/relative/path`)
    verifyUri(`file.txt`)
    verifyUri(`mailto:user@host.com`)

    // verify the ref id is valid
    ref := Ref.makeUri(`http://example.com/foo?bar=baz`)
    verifyEq(Ref.isId(ref.id), true)
    verify(ref.id.startsWith("uri:"))

    // tildeEncode handles unicode
    verifyTilde("\u00e9", "~e9")                   // e-acute (Latin1)
    verifyTilde("\u00e9sum\u00e9", "~e9sum~e9")    // accented with ASCII
    verifyTilde("\u4e2d", "~u4e2d")                // CJK (BMP)
    verifyTilde("\u65e5\u672c", "~u65e5~u672c")    // multi-char CJK
    verifyTilde("\u{01f600}", "~ud83d~ude00")      // emoji (surrogate pair)
  }

  Void verifyUri(Uri uri)
  {
    ref := Ref.makeUri(uri)
    // echo("-- $uri | $ref")
    verifyEq(ref.isUri, true)
    verifyEq(Ref.isId(ref.id), true)
    verifyEq(ref.toUri, uri)
  }

  Void verifyTilde(Str orig, Str expectedEncoded)
  {
    encoded := Ref.tildeEncode(StrBuf(), orig).toStr
    verifyEq(encoded, expectedEncoded)
    verifyEq(Ref.isId(encoded), true)
    decoded := Ref.tildeDecode(encoded)
    verifyEq(decoded, orig)
  }
}

