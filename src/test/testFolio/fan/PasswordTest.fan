//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 10  Brian Frank  Creation
//

using concurrent
using haystack
using folio

class PasswordTest : Test
{
  Void test()
  {
    // verify empty startup
    file := tempDir + `passwords.props`
    config := FolioConfig
    {
      it.dir = tempDir
      it.log = Log.get("test")
    }
    log := Log.get("test")
    ps := PasswordStore.open(file, config)
    verifyEq(ps.get("bad"), null)

    // add, change, remove some passwords
    ps.set("a", "alpha")
    ps.set("b", "beta")
    ps.set("b", "beta2")
    ps.set("d", "delta")
    ps.set("d", "delta2")
    ps.set("e", "ernie")
    ps.set("f", "Δ°F m² °daysF inH₂O")
    ps.set("a=b", "works?")

    // verify added
    verifyEq(ps.get("bad"), null)
    verifyEq(ps.get("a"), "alpha")
    verifyEq(ps.get("b"), "beta2")
    verifyEq(ps.get("d"), "delta2")
    verifyEq(ps.get("e"), "ernie")
    verifyEq(ps.get("f"), "Δ°F m² °daysF inH₂O")
    verifyEq(ps.get("a=b"), "works?")
    verifyEq(ps.get("x"), null)

    // restart
    ps = PasswordStore.open(file, config)

    // verify reloaded ok
    verifyEq(ps.get("a"), "alpha")
    verifyEq(ps.get("b"), "beta2")
    verifyEq(ps.get("d"), "delta2")
    verifyEq(ps.get("e"), "ernie")
    verifyEq(ps.get("f"), "Δ°F m² °daysF inH₂O")

    // make some changes
    ps.set("a", "alpha2")
    ps.set("d", "delta3")
    ps.remove("e")
    ps.set("g", "<|hi there!|>")

    // restart
    ps = PasswordStore.open(file, config)

    // verify changes
    verifyEq(ps.get("a"), "alpha2")
    verifyEq(ps.get("b"), "beta2")
    verifyEq(ps.get("d"), "delta3")
    verifyEq(ps.get("e"), null)
    verifyEq(ps.get("f"), "Δ°F m² °daysF inH₂O")
    verifyEq(ps.get("g"), "<|hi there!|>")

    // rel vs abs ids
    ps.set("foo-bar", "secret!")
    ps.set("abs:baz", "boo!")
    verifyEq(ps.get("foo-bar"), "secret!")
    verifyEq(ps.get("p:site:r:foo-bar"), null)
    ps = PasswordStore.open(file, FolioConfig { it.dir = tempDir; it.idPrefix = "p:site:r:" })
    verifyEq(ps.get("foo-bar"), "secret!")
    verifyEq(ps.get("p:site:r:foo-bar"), "secret!")
    verifyEq(ps.get("p:site:r:"), null)
    verifyEq(ps.get("p:site:r:xfoo-bar"), null)
    verifyEq(ps.get("p:new-ns:r:foo-bar"), null)
    verifyEq(ps.get("abs:baz"), "boo!")
    ps = PasswordStore.open(file, FolioConfig { it.dir = tempDir; it.idPrefix = "p:new-ns:r:" })
    verifyEq(ps.get("foo-bar"), "secret!")
    verifyEq(ps.get("p:site:r:foo-bar"), null)
    verifyEq(ps.get("p:new-ns:r:foo-bar"), "secret!")
    verifyEq(ps.get("abs:baz"), "boo!")
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void testUtil()
  {
    verifyPassword("")
    verifyPassword("A")
    verifyPassword("#%")
    verifyPassword("123456789")
    verifyPassword("really bad")
    verifyPassword("ReallyGood!")
    verifyPassword("abce~!@#%^&*()098765431ABCXYZ")
    verifyPassword("< \u01ab \u0f32 \u3123 \u1234 !>")

    // 0x3fff is max
    verifyErr(IOErr#) { PasswordStore.encode("<| \u4000 |>") }
    verifyErr(IOErr#) { PasswordStore.encode("<| \u7a34 |>") }
  }

  Void verifyPassword(Str pass)
  {
    dups := Str:Str[:]
    5.times
    {
      x := PasswordStore.encode(pass)
      if (dups[x] != null) fail(x)
      dups[x] = x
      verifyEq(PasswordStore.decode(x), pass)
    }
  }

}

