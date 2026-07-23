//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Concatenates up to four strings. Null inputs are ignored
** and treated as empty strings.
**
@Gen
class StrConcat : HxComp
{
  ** Input A
  @Gen virtual StatusStr? inA() { get("inA") }

  ** Input B
  @Gen virtual StatusStr? inB() { get("inB") }

  ** Input C
  @Gen virtual StatusStr? inC() { get("inC") }

  ** Input D
  @Gen virtual StatusStr? inD() { get("inD") }

  ** The concatenation of (inA + inB + inC + inD)
  @Gen virtual StatusStr out() { get("out") }

  new make() { }

  private StrBuf buf := StrBuf()

  override Void onExecute()
  {
    buf.add(inA?.val ?: "")
    buf.add(inB?.val ?: "")
    buf.add(inC?.val ?: "")
    buf.add(inD?.val ?: "")
    set("out", StatusStr(buf.toStr))
    buf.clear
  }
}

**
** Checks if `inB` can be found within `inA`.
**
@Gen
class StrContains : HxComp
{
  ** Defines the Str to check for `inB`
  @Gen virtual StatusStr? inA() { get("inA") }

  ** The Str to look for in `inA`
  @Gen virtual StatusStr? inB() { get("inB") }

  ** True if `inA` contains `inB`
  @Gen virtual StatusBool out() { get("out") }

  ** The zero-based index to start checking for `inB` in `inA`.
  @Gen virtual Int fromIndex { get {get("fromIndex")} set {set("fromIndex", it)} }

  ** The index where `inB` was found, or -1 if it wasn't found
  @Gen virtual Int startIndex() { get("startIndex") }

  ** The index in `inA` immediately after where `inB` was found,
  ** or -1 if it wasn't found
  @Gen virtual Int afterIndex() { get("afterIndex") }

  override Void onExecute()
  {
    if (inA == null || inB == null) return

    a := inA.str
    b := inB.str
    i := a.index(b, fromIndex)

    set("startIndex", i ?: -1)
    set("afterIndex", i == null ? -1 : i+b.size)
    set("out", StatusBool(i != null))
  }
}

**
** Computes the length of the input Str.
**
@Gen
class StrLen : HxComp
{
  ** The input Str
  @Gen virtual StatusStr? in() { get("in") }

  ** The length of `in`
  @Gen virtual StatusNumber out() { get("out") }

  override Void onExecute()
  {
    set("out", StatusNumber(Number.makeInt(in?.str?.size ?: 0)))
  }
}

**
** Extracts a sub-string of the input.
**
@Gen
class StrSubstr : HxComp
{
  ** The input Str
  @Gen virtual StatusStr? in() { get("in") }

  ** The computed sub-string
  @Gen virtual StatusStr out() { get("out") }

  ** The index to start extracting the sub-string
  @Gen virtual Int startIndex { get {get("startIndex")} set {set("startIndex", it)} }

  ** The index to end extracting the sub-string. Use -1 to indicate
  ** the end of the string.
  @Gen virtual Int endIndex { get {get("endIndex")} set {set("endIndex", it)} }

  override Void onExecute()
  {
    if (in == null) return

    str := in.str
    s := startIndex
    e := endIndex
    Str? sub
    try
    {
      // this uses java semantics for substring while still allowing for
      // negative indexing
      if (s < 0 || s >= str.size) s = str.size
      if (e < 0) e = str.size + (e + 1)
      sub = str[s..<e]
    }
    catch (IndexErr err)
    {
      sub = ""
    }
    set("out", StatusStr(sub))
  }
}

**
** Removes whitespace from the beginning and end of a Str
**
@Gen
class StrTrim : HxComp
{
  ** The input Str
  @Gen virtual StatusStr? in() { get("in") }

  ** The input Str with leading and trailing whitespace removed
  @Gen virtual StatusStr out() { get("out") }

  override Void onExecute()
  {
    set("out", StatusStr(in?.str?.trim ?: ""))
  }
}

**
** Tests two strings based on the selected test type. All tests are computed
** in terms of `a <test> b`
**
@Gen
class StrTest : HxComp
{
  ** Input A
  @Gen virtual StatusStr? inA() { get("inA") }

  ** Input B
  @Gen virtual StatusStr? inB() { get("inB") }

  ** Result of the test
  @Gen virtual StatusBool out() { get("out") }

  ** The test to perform on the inputs
  @Gen virtual StrTestType test { get {get("test")} set {set("test", it)} }

  override Void onExecute()
  {
    a := inA?.str
    b := inB?.str

    if (a == null || b == null) return

    result := false
    switch (test)
    {
      case StrTestType.eq: result = a.equals(b)
      case StrTestType.eqIgnoreCase: result = a.equalsIgnoreCase(b)
      case StrTestType.startsWith: result = a.startsWith(b)
      case StrTestType.endsWith: result = a.endsWith(b)
      case StrTestType.contains: result = a.contains(b)
    }
    set("out", StatusBool(result))
  }
}

**
** Tests available to the StrTest component.
**
@Gen
enum class StrTestType
{
  eq,

  eqIgnoreCase,

  startsWith,

  endsWith,

  contains
}

