//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Aug 2026  Brian Frank  Creation
//

using xeto

**
** PiTest
**
class PiTest : Test
{

//////////////////////////////////////////////////////////////////////////
// Text
//////////////////////////////////////////////////////////////////////////

  Void testTextBasics()
  {
    verifyText(Text.defVal,      "",      "")
    verifyText(Text.empty,       "",      "")
    verifyText(Text("foo"),      "foo",   "foo")
    verifyText(Text(""),         "",      "")
    verifyText(Text("  x  "),    "  x  ", "  x  ")

    verifySame(Text(""), Text.empty)
    verifySame(Text.defVal, Text.empty)
    verify(Text.empty.isBlank)
    verifyFalse(Text("foo").isBlank)
  }

  Void testTextEquality()
  {
    verifyEq(Text("foo"), Text("foo"))
    verifyEq(Text("foo").hash, Text("foo").hash)
    verifyNotEq(Text("foo"), Text("bar"))
    verifyNotEq(Text("foo"), "foo")
    verifyNotEq(Text("foo"), null)
  }

  Void testTextTrimToNull()
  {
    verifyEq(Text("foo").trimToNull, "foo")
    verifyEq(Text("  foo  ").trimToNull, "foo")
    verifyEq(Text("   ").trimToNull, null)
    verifyEq(Text.empty.trimToNull, null)
  }

  Void testTextMacro()
  {
    verifyMacro("", "")
    verifyMacro("a", "a")
    verifyMacro("Foo Bar", "Foo Bar")

    // bare key resolves against this pod's centralized manifest
    verifyMacro(Str<|$<byStateByCity>|>, "By State/City")

    // explicit pod
    verifyMacro(Str<|$<pi::byStateByCity>|>, "By State/City")

    // keys not found
    verifyMacro(Str<|$<fooBarBaz>|>, "fooBarBaz")
    verifyMacro(Str<|$<fooBar::baz>|>, "fooBar::baz")
    verifyMacro(Str<|$<pi::baz>|>, "pi::baz")

    // complex
    verifyMacro(Str<|_$<byStateByCity>|>, "_By State/City")
    verifyMacro(Str<|$<byStateByCity>_|>, "By State/City_")
    verifyMacro(Str<|_$<byStateByCity>!|>, "_By State/City!")

    // multiple locale keys
    verifyMacro(Str<|$<eval>$<eula>|>, "EvalEULA")
    verifyMacro(Str<|$<eval> $<eula>|>, "Eval EULA")
    verifyMacro(Str<|_$<eval>|$<eula>!|>, "_Eval|EULA!")
    verifyMacro(Str<|a_$<eval>|b$<eula>!c|>, "a_Eval|bEULA!c")

    // escaped
    verifyMacro(Str<|\$<byStateByCity>|>, Str<|\$<byStateByCity>|>)
    verifyMacro(Str<|\$<eval> \$<eula>|>, Str<|\$<eval> \$<eula>|>)
    verifyMacro(Str<|$<eval> \$<eula>|>, Str<|Eval \$<eula>|>)
    verifyMacro(Str<|\$<eval> $<eula>|>, Str<|\$<eval> EULA|>)

    // unclosed
    verifyMacro(Str<|$<byStateByCity|>, Str<|$<byStateByCity|>)
    verifyMacro(Str<|_$<byStateByCity|>, Str<|_$<byStateByCity|>)
    verifyMacro(Str<|$<eval> $<eula|>, Str<|Eval $<eula|>)
  }

  private Void verifyMacro(Str pattern, Str dis)
  {
    t := Text(pattern)
    verifyText(t, pattern, dis)
    verifyEq(Text(pattern), t)
    if (pattern.isEmpty) verifySame(t, Text.defVal)
  }

  Void testTextFromData()
  {
    // null and empty collapse to defVal
    verifySame(Text.fromData(null), Text.empty)
    verifySame(Text.fromData(""), Text.empty)

    // Str routes thru fromStr
    verifyText(Text.fromData("foo"), "foo", "foo")

    // Text returns itself
    t := Text("keep")
    verifySame(Text.fromData(t), t)

    // other values format via the XetoEnv valToDis hook
    verifyText(Text.fromData(42), "42", "42")
    verifyText(Text.fromData(true), "true", "true")
  }

  Void testMatchText()
  {
    t := MatchText(["", "fo", "obar"])
    verify(t.isMatch)
    verifyEq(t.matchSegments, ["", "fo", "obar"])
    verifyEq(t.pattern, "_fo_obar")
    verifyEq(t.dis, "_fo_obar")

    verifyEq(t, MatchText(["", "fo", "obar"]))
    verifyEq(t.hash, MatchText(["", "fo", "obar"]).hash)
    verifyNotEq(t, MatchText(["x"]))
    verifyNotEq(t, Text("_fo_obar"))

    // plain text is not a match and cannot yield segments
    verifyFalse(Text("foo").isMatch)
    verifyErr(UnsupportedErr#) { Text("foo").matchSegments }
  }

  private Void verifyText(Text t, Str pattern, Str dis)
  {
    verifyEq(t.pattern, pattern)
    verifyEq(t.dis, dis)
    verifyEq(t.toStr, pattern)
    verifyEq(t.isBlank, pattern.isEmpty)
  }

//////////////////////////////////////////////////////////////////////////
// Icon
//////////////////////////////////////////////////////////////////////////

  Void testIcon()
  {
    // lucide icon
    verifyIcon(Icon("house"), "house", houseTags)

    // aliases
    verifyIcon(Icon("proj"), "proj", Str[,])
    verifyEq(Icon("proj").svgBody, Icon("database").svgBody)

    // search
    verifyIconSearch("apple",           "apple")
    verifyIconSearch("camera",          "camera, camera-off", 2)
    verifyIconSearch("vent",            "air-vent, fan")
    verifyIconSearch("climate control", "air-vent")
    verifyIconSearch("pressure",        "gauge, wind-arrow-down, circle-gauge, heart-pulse")
  }

  Void testIconParse()
  {
    file := Pod.find("pi").file(`/res/icons.txt`)
    reg := IconRegistry.parseFile(file.readAllStr)
    verifyIcon(reg.get("house", true), "house", houseTags)
    verifyIcon(reg.get("equip", true), "equip", Str[,])
  }

  Str[] houseTags()
  {
    ["architecture", "building", "buildings", "home", "living", "navigation", "residence"]
  }

  Void verifyIcon(Icon x, Str name, Str[] tags)
  {
    // echo("~~> $x.name $x.tags $x.typeof")
    verifyEq(x.name, name)
    verifyEq(x.tags, tags)
    verifyEq(x.svgBody.startsWith("<"), true)
  }

  Void verifyIconSearch(Str q, Str expect, Int? max := null)
  {
    actual := Icon.search(q)
    // echo("\n~~~ $q > $actual")
    if (max != null) actual = actual[0..<max]
    verifyEq(actual.join(", "), expect)
  }

}

