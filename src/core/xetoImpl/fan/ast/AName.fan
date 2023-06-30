//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Feb 2023  Brian Frank  Creation
//

**
** AST relative or qualified name
**
@Js
internal const class AName
{
  ** Construct name which might or might not be qualified
  new make(Str s)
  {
    colon := s.index("::")
    if (colon == null)
    {
      lib = null
      name = s
    }
    else
    {
      lib = s[0..<colon]
      name = s[colon+2..-1]
    }
    this.toStr = s
  }

  ** Construct qualified name
  new makeQualified(Str? lib, Str name)
  {
    this.lib = lib
    this.name = name
    this.toStr = lib == null ? name : StrBuf(lib.size+2+name.size).add(lib).add("::").add(name).toStr
  }

  ** Library name if qualified
  const Str? lib

  ** Simple name if unqualified
  const Str name

  ** Is this a qualified name
  Bool isQualified() { lib != null }

  ** Simple or qualified name
  const override Str toStr
}