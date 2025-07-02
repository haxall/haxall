//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jun 2010  Brian Frank  Creation
//

using xeto

**
** Read Haystack data in [Trio]`docHaystack::Trio` format.
**
@Js
class TrioReader : GridReader
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap input stream
  new make(InStream in)
  {
    this.in = in
  }

//////////////////////////////////////////////////////////////////////////
// GridWriter
//////////////////////////////////////////////////////////////////////////

  ** Return recs as simple grid (no grid or column level meta)
  override Grid readGrid() { Etc.makeDictsGrid(null, readAllDicts) }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  **
  ** Read all dicts from the stream and close it.
  **
  Dict[] readAllDicts()
  {
    acc := Dict[,]
    eachDict |rec| { acc.add(rec) }
    return acc
  }

  **
  ** Iterate through the entire stream reading dicts.
  ** The stream is guaranteed to be closed when done.
  **
  Void eachDict(|Dict| f)
  {
    try
    {
      while (true)
      {
        rec := readDict(false)
        if (rec == null) break
        f(rec)
      }
    }
    finally in.close
  }

  **
  ** Read next dict from the stream.  If end of stream is detected
  ** then reutrn null or raise exception based on checked flag.
  **
  Dict? readDict(Bool checked := true)
  {
    tags := Str:Obj[:]
    tags.ordered = true

    r := readTag
    while (r == 0) r = readTag
    if (r == -1)
    {
      if (checked) throw Err("Expected dict not end of stream")
      return null
    }
    recLineNum = lineNum
    tags[name] = val

    while (true)
    {
      r = readTag
      if (r != 1) break
      if (tags[name] != null) throw err("Duplicate tag: $name")
      tags[name] = val
    }
    if (tags.isEmpty)
    {
      if (checked) throw Err("Expected dict not end of stream")
      return null
    }
    return Etc.makeDict(tags)
  }

//////////////////////////////////////////////////////////////////////////
// Support
//////////////////////////////////////////////////////////////////////////

  ** Return -1=end of file, 0=end of rec, 1=read ok
  private Int readTag()
  {
    // read until we get data line
    line := readLine
    while (true)
    {
      // if end of file
      if (line == null) return -1

      // if end of record
      if (line.startsWith("-")) return 0

      // if empty line or comment line
      if (line.isEmpty || line.startsWith("//") || (line[0].isSpace && line.trim.isEmpty))
      {
        line = readLine
        continue
      }

      // found data line
      break
    }

    // split into name: val
    lineNum := this.lineNum
    colon := line.index(":")
    this.name = line
    this.val  = Marker.val
    if (colon != null)
    {
      this.name = line[0..<colon].trim
      valStr := line[colon+1..-1].trim
      try
      {
        if (valStr.isEmpty)
        {
          if (name == "src") srcLineNum = lineNum+1
          this.val = readIndentedText
        }
        else
        {
          if (name == "src") srcLineNum = lineNum
          this.val = parseScalar(valStr)
        }
      }
      catch (Err e) throw err("Invalid tag value for $name.toCode: $valStr", lineNum, e)
    }

    if (!Etc.isTagName(name)) throw err("Invalid name: $name", lineNum)
    name = factory.makeId(name)
    return 1
  }

  private Obj parseScalar(Str s)
  {
    ch := s[0]
    if (ch.isDigit || ch == '-')
    {
      // old RecId syntax
      if (s.size == 17 && s[8] == '-') throw Err("Unsupported Ref format: $s")

      // date
      if (s.size == 10 && s[4] == '-') return factory.makeDate(s) ?: s

      // date time
      if (s.size > 20 && s[4] == '-')
      {
        if (s.endsWith("Z"))
          return factory.makeDateTime("$s UTC") ?: s
        else
          return factory.makeDateTime(s) ?: s
      }

      // time (allow a bit of fudge)
      if (s.size > 3 && (s[1] == ':' || s[2] == ':'))
      {
        sx := s
        if (sx[1] == ':') sx = "0$sx"
        if (sx.size == 5) sx = "$sx:00"
        time := factory.makeTime(sx)
        return time != null ? time : s
      }

      // try as number
      if (!s.contains(" ")) return readAsZinc(s)
    }
    else if (ch == '"' || ch== '`')
    {
      if (s[-1] != s[0]) throw err("Invalid quoted literal: $s")
      return readAsZinc(s)
    }
    else if (ch == '@' || ch == '^')
    {
      return readAsZinc(s)
    }
    else if (ch == '{' || s[-1] == ')')
    {
      return readAsZinc(s)
    }
    else if (ch == '[')
    {
      if (s == "[")  // bracket on opening line is indented list
        return readIndentedList
      else
        return readAsZinc(s)
    }
    else
    {
      if (s == "true")  return true
      if (s == "false") return false
      if (s == "T")     return true
      if (s == "F")     return false
      if (s == "NA")    return NA.val
      if (s == "NaN")   return Number.nan
      if (s == "INF")   return Number.posInf
      if (s == "R")     return Remove.val
      if (s == "Zinc:") return readAsZinc(readIndentedText)
      if (s == "Trio:") return readAsTrio(readIndentedText)
      if (s.endsWith(":")) throw Err("Unsupported indention format: $s")
    }
    return s
  }

  private Obj? readAsZinc(Str s)
  {
    tokenizer := HaystackTokenizer(s.in)
    tokenizer.factory = this.factory
    return ZincReader(tokenizer).readVal
  }

  private Obj? readAsTrio(Str s)
  {
    r := TrioReader(s.in)
    r.factory = factory
    return r.readDict
  }

  private Str readIndentedText()
  {
    minIndent := Int.maxVal
    lines := Str[,]
    while (true)
    {
      line := readLine
      if (line == null) break
      if (line.size > 1 && !line[0].isSpace) { pushback = line; break }
      lines.add(line.trimEnd)
      for (i:=0; i<line.size; ++i)
        if (!line[i].isSpace) { if (i < minIndent) minIndent = i; break }
    }

    s := StrBuf()
    lines.each |line, i|
    {
      strip := (line.size <= minIndent) ? "" : line[minIndent..-1]
      s.join(strip, "\n")
    }
    return s.toStr
  }

  private Obj readIndentedList()
  {
    lines :=  readIndentedText.in.readAllLines
    lines = lines.findAll |line| { !line.trim.startsWith("//") }
    s := StrBuf().add("[")
    lines.each |line| { s.add(line).addChar(' ') }
    return ZincReader(s.toStr.in).readVal
  }

  private Str? readLine()
  {
    if (pushback != null) { s := pushback; pushback = null; return s }
    ++lineNum
    return in.readLine(null)
  }

  private ParseErr err(Str msg, Int lineNum := this.lineNum, Err? cause := null)
  {
    ParseErr(msg + " [Line $lineNum]", cause)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Line number for current record
  @NoDoc Int recLineNum { private set }

  ** Line for source line tag
  @NoDoc Int srcLineNum := 0  { private set }

  ** Factory for value creation and interning
  @NoDoc HaystackFactory factory := HaystackFactory()

  private InStream in
  private Int lineNum
  private Str? pushback
  private Str? name
  private Obj? val
}

