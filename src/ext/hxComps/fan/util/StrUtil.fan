//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Aug 2025  Matthew Giannini  Creation
//

using haystack

**
** Concatenates up to four strings. Null inputs are ignored
** and treated as empty strings.
**
class StrConcat : HxComp
{
  /* ionc-start */

  ** Input A
  virtual StatusStr? inA() { get("inA") }

  ** Input B
  virtual StatusStr? inB() { get("inB") }

  ** Input C
  virtual StatusStr? inC() { get("inC") }

  ** Input D
  virtual StatusStr? inD() { get("inD") }

  ** The concatenation of (inA + inB + inC + inD)
  virtual StatusStr out() { get("out") }

  /* ionc-end */

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
** Checks if 'inB' can be found within 'inA'.
**
class StrContains : HxComp
{
  /* ionc-start */

  ** Defines the Str to check for 'inB'
  virtual StatusStr? inA() { get("inA") }

  ** The Str to look for in 'inA'
  virtual StatusStr? inB() { get("inB") }

  ** True if 'inA' contains 'inB'
  virtual StatusBool out() { get("out") }

  ** The zero-based index to start checking for 'inB' in 'inA'.
  virtual Int fromIndex { get {get("fromIndex")} set {set("fromIndex", it)} }

  ** The index where 'inB' was found, or -1 if it wasn't found
  virtual Int startIndex() { get("startIndex") }

  ** The index in 'inA' immediately after where 'inB' was found,
  ** or -1 if it wasn't found
  virtual Int afterIndex() { get("afterIndex") }

  /* ionc-end */

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
class StrLen : HxComp
{
  /* ionc-start */

  ** The input Str
  virtual StatusStr? in() { get("in") }

  ** The length of 'in'
  virtual StatusNumber out() { get("out") }

  /* ionc-end */

  override Void onExecute()
  {
    set("out", StatusNumber(Number.makeInt(in?.str?.size ?: 0)))
  }
}

**
** Extracts a sub-string of the input.
**
class StrSubstr : HxComp
{
  /* ionc-start */

  ** The input Str
  virtual StatusStr? in() { get("in") }

  ** The computed sub-string
  virtual StatusStr out() { get("out") }

  ** The index to start extracting the sub-string
  virtual Int startIndex { get {get("startIndex")} set {set("startIndex", it)} }

  ** The index to end extracting the sub-string. Use -1 to indicate
  ** the end of the string.
  virtual Int endIndex { get {get("endIndex")} set {set("endIndex", it)} }

  /* ionc-end */

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
class StrTrim : HxComp
{
  /* ionc-start */

  ** The input Str
  virtual StatusStr? in() { get("in") }

  ** The input Str with leading and trailing whitespace removed
  virtual StatusStr out() { get("out") }

  /* ionc-end */

  override Void onExecute()
  {
    set("out", StatusStr(in?.str?.trim ?: ""))
  }
}

**
** Tests two strings based on the selected test type. All tests are computed
** in terms of 'a <test> b'
**
class StrTest : HxComp
{
  /* ionc-start */

  ** Input A
  virtual StatusStr? inA() { get("inA") }

  ** Input B
  virtual StatusStr? inB() { get("inB") }

  ** Result of the test
  virtual StatusBool out() { get("out") }

  ** The test to perform on the inputs
  virtual StrTestType test { get {get("test")} set {set("test", it)} }

  /* ionc-end */

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
enum class StrTestType
{
  /* ionc-start */

  eq,

  eqIgnoreCase,

  startsWith,

  endsWith,

  contains

  /* ionc-end */
}

