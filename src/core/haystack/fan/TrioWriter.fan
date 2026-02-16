//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jun 2010  Brian Frank  Creation
//

using xeto

**
** Write Haystack data in [Trio]`ph.doc::Trio` format.
**
** Options:
**  - noSort: do not sort tag names
**
@Js
class TrioWriter : GridWriter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap output stream
  new make(OutStream out, Dict? opts := null)
  {
    this.out = out
    if (opts != null)
    {
      this.noSort = opts.has("noSort")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  **
  ** Convenience to write dict to a Trio string
  **
  @NoDoc static Str dictToStr(Dict val)
  {
    buf := StrBuf()
    TrioWriter(buf.out).writeDict(val)
    return buf.toStr
  }

  **
  ** Format a grid to a string in memory.
  **
  @NoDoc static Str gridToStr(Grid grid)
  {
    buf := StrBuf()
    TrioWriter(buf.out).writeGrid(grid)
    return buf.toStr
  }

  **
  ** Write the grid rows (no support for meta)
  **
  override This writeGrid(Grid grid)
  {
    grid.each |row| { writeDict(row) }
    return this
  }

  **
  ** Write separator and record.  Return this.
  **
  This writeDict(Dict dict)
  {
     if (needSep) out.printLine("---")
     else needSep = true

    // get names in nice order
    names := Etc.dictNames(dict)
    if (!noSort)
    {
      names.sort
      names.moveTo("dis",  0)
      names.moveTo("name", 0)
      names.moveTo("id",   0)
      names.moveTo("src", -1)
    }

    names.each |n|
    {
      v := dict[n]
      if (v == null) return
      if (v === Marker.val) { out.printLine(n); return }
      v = normVal(v)
      out.print(n).writeChar(':')
      kind := Kind.fromVal(v, false)
      if (kind == null)
      {
        out.printLine(XStr.encode(v).toStr)
        return
      }
      if (kind !== Kind.str)
      {
        if (kind.isCollection)
          writeCollection(v)
        else if (kind == Kind.bool)
          out.printLine(v)
        else
          out.printLine(kind.valToZinc(v))
        return
      }
      str := (Str)v
      if (!str.contains("\n"))
      {
        if (useQuotes(str))
          out.printLine(str.toCode)
        else
          out.printLine(str)
      }
      else
      {
        out.printLine
        str.splitLines.each |line| { out.print("  ").printLine(line) }
      }
    }
    out.flush
    return this
  }

  private Void writeCollection(Obj val)
  {
    // write anything with nested grids as indented zinc
    if (requiresNestedZinc(val)) return writeNestedZinc(val)

    // write out inline
    zinc := ZincWriter(out)
    zinc.writeVal(val)
    out.printLine
  }

  private Bool requiresNestedZinc(Obj? val)
  {
    // grids are multi-line so must nest
    if (val is Grid) return true

    // list requires checking each list value
    if (val is List)
      return ((List)val).any |v| { requiresNestedZinc(v) }

    // dict requires checking each value
    if (val is Dict)
    {
      r := ((Dict)val).eachWhile |v|
      {
        requiresNestedZinc(v) ? "req" : null
      }
      return r != null
    }

    return false
  }

  private Void writeNestedZinc(Obj val)
  {
    s := StrBuf()
    zinc := ZincWriter(s.out)
    if (val is Grid)
      zinc.writeGrid(val)
    else
      zinc.writeVal(val)
    out.printLine("Zinc:")
    s.toStr.splitLines.each |line, i|
    {
      out.print("  ").printLine(line)
    }
  }

  @NoDoc static Bool useQuotes(Str s)
  {
    if (s.isEmpty) return true
    if (s[0] > 127) return false
    if (!s[0].isAlpha) return true
    if (quotedKeyword[s] != null) return true
    for (i := 0; i<s.size; ++i)
      if (!requireQuoteChar(s[i])) return true
    return false
  }

  private static Bool requireQuoteChar(Int ch)
  {
    if (ch > 127) return false
    return quoteChars[ch]
  }

  **
  ** Write the list of dicts.  Return this.
  **
  This writeAllDicts(Dict[] dicts)
  {
    dicts.each |dict| { writeDict(dict) }
    return this
  }

  **
  ** Call sync on underlying output stream
  **
  @NoDoc This sync()
  {
    out.sync
    return this
  }

  **
  ** Close the underlying output stream
  **
  Bool close()
  {
    out.close
  }

  ** Hook to normalize value
  @NoDoc virtual Obj normVal(Obj val) { val }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str:Str quotedKeyword := Str:Str[:].addList([
    "true", "false", "T", "F", "INF", "NA", "NaN", "R", "Zinc"])

  private static const Bool[] quoteChars
  static
  {
    acc := Bool[,]
    acc.fill(false, 127)
    for (i:='a'; i<='z'; ++i) acc[i] = true
    for (i:='A'; i<='Z'; ++i) acc[i] = true
    for (i:='0'; i<='9'; ++i) acc[i] = true
    acc[' '] = true
    acc['-'] = true
    acc['_'] = true
    quoteChars = acc
  }


  private OutStream out
  private Bool needSep
  private Bool noSort
}

