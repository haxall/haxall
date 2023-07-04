//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Aug 2022  Brian Frank  Creation
//    3 Jul 2023  Brian Frank  Redesign
//

using util
using xeto

**
** Parser for the Xeto data type language
**
@Js
internal class Parser
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Step step, FileLoc fileLoc, InStream in)
  {
    this.step = step
    this.compiler = step.compiler
    this.sys = step.sys
    this.marker = compiler.env.marker
    this.fileLoc = fileLoc
    this.tokenizer = Tokenizer(in) { it.keepComments = true }
    this.cur = this.peek = Token.eof
    consume
    consume
  }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Top level parse of data file - instances only.
  ** The input stream is guaranteed to be closed upon exit.
  AData parseDataFile()
  {
    try
    {
      data := cur === Token.ref ? parseNamedData : parseData
      verify(Token.eof)
      return data
    }
    catch (ParseErr e)
    {
      throw err(e.msg, curToLoc)
    }
    finally
    {
      tokenizer.close
    }
  }

  ** Top level parse of lib file - specs or instances
  ** The input stream is guaranteed to be closed upon exit.
  ALib parseLibFile(ALib lib)
  {
    try
    {
      while (true)
      {
        if (!parseLibObj(lib)) break
      }
      verify(Token.eof)
      return lib
    }
    catch (ParseErr e)
    {
      throw err(e.msg, curToLoc)
    }
    finally
    {
      tokenizer.close
    }
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  ** Parse top level lib object - spec or instance
  private Bool parseLibObj(ALib lib)
  {
    doc := parseLeadingDoc

    if (cur === Token.eof) return false

    if (cur === Token.id) return parseLibSpec(lib, doc)

    if (cur === Token.ref) return parseLibData(lib)

    throw err("Expecting instance data or spec, not $curToStr")
  }

  ** Parse top level spec and add it to lib
  private Bool parseLibSpec(ALib lib, Str? doc)
  {
    spec := parseNamedSpec(lib, null, doc)
    parseLibObjEnd("spec")

    // make sure name is unique
    name := spec.name
    if (lib.specs[name] != null) throw err("Duplicate spec name: name", spec.loc)
    lib.specs[name] = spec

    return true
  }

  ** Parse top level instance data and add it to lib
  private Bool parseLibData(ALib lib)
  {
    // parse named instance
    data := parseNamedData
    parseLibObjEnd("instance")

    // data id cannot be qualified
    if (data.id.isQualified) throw err("Cannot specify qualified id for instance id: $data.id", data.loc)

    // make sure id is unique
    id := data.id.toStr
    if (lib.instances[id] != null) throw err("Duplicate instance id: $id", data.loc)
    lib.instances[id] = data

    return true
  }

  ** Make sure top-level object ends with newline
  private Void parseLibObjEnd(Str obj)
  {
    if (cur === Token.eof) return
    if (cur !== Token.nl) throw err("Expecting newline after lib $obj, not $curToStr")
    skipNewlines
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  ** Parse named spec
  private ASpec parseNamedSpec(ALib lib, ASpec? parent, Str? doc)
  {
    loc := curToLoc
    name := consumeName("Expecting spec name")
    spec := ASpec(loc, lib, parent, name)

    if (cur !== Token.colon)
    {
      marker :=  impliedMarker(spec.loc)
      spec.typeRef = marker.typeRef
      spec.val = marker
    }
    else
    {
      consume  // colon
      parseSpecType(spec)
      parseSpecMeta(spec)
      parseSpecBody(spec)
    }

    doc = parseTrailingDoc(doc)
    setDocMeta(spec, doc)

    return spec
  }

  private Void parseSpecType(ASpec spec)
  {
    spec.typeRef = parseTypeRef
    if (spec.typeRef == null) return
    loc := spec.typeRef.loc

    if (cur === Token.question)
    {
      consume
      spec.initMeta.set("maybe", impliedMarker(loc))
      return
    }

    if (cur === Token.amp)  return parseCompoundType(spec, sys.and)
    if (cur === Token.pipe) return parseCompoundType(spec, sys.or)
  }

  private Void parseCompoundType(ASpec spec, ASpecRef compoundType)
  {
    first := spec.typeRef
    loc := first.loc
    list := ADict(loc, sys.list)
    list.set("_0", first)

    separator := cur
    while (cur === separator)
    {
      consume
      next := parseTypeRef ?: throw err("Expecting next type name in $compoundType.name")
      list.set("_" + list.map.size, next)
    }

    spec.typeRef = compoundType
    spec.initMeta.set("ofs", list)
  }

  private Void parseSpecMeta(ASpec spec)
  {
    if (cur === Token.lt) spec.initMeta(parseDict(null, Token.lt, Token.gt))
  }

  private Void parseSpecBody(ASpec spec)
  {
    if (cur === Token.scalar)
      spec.val = parseScalar(null)
    else if (cur === Token.lbrace)
      parseSpecSlots(spec)
  }

  private Void parseSpecSlots(ASpec parent)
  {
    acc := parent.initSlots

    consume(Token.lbrace)

    while (cur !== Token.rbrace)
    {
      doc := parseLeadingDoc
      slot := parseNamedSpec(parent.lib, parent, doc)
      parseCommaOrNewline("Expecting end of slots", Token.rbrace)

      acc.add(slot.name, slot)
    }

    // close "}"
    consume(Token.rbrace)
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Data
//////////////////////////////////////////////////////////////////////////

  ** Parse dict with id
  private ADict parseNamedData()
  {
    id := curVal
    consume(Token.ref)

    if (cur !== Token.colon) throw err("Expecting colon after instance id, not $curToStr")
    consume

    data := parseData
    dict := data as ADict
    if (dict == null) throw err("Can only name dict data", data.loc)
    dict.id = id
    return dict
  }

  ** Parse an optionally typed data value
  private AData parseData()
  {
    type := parseTypeRef
    if (cur === Token.scalar) return parseScalar(type)
    if (cur === Token.lbrace) return parseDict(type, Token.lbrace, Token.rbrace)
    if (type != null) return type
    throw err("Expecting scalar or dict data value, not $curToStr")
  }

  ** Parse a scalar data value
  private AScalar parseScalar(ASpecRef? type)
  {
    x := AScalar(curToLoc, type, curVal)
    consume
    return x
  }

  ** Parse a dict data value
  private ADict parseDict(ASpecRef? type, Token openToken, Token closeToken)
  {
    // open "{" or "<"
    x := ADict(curToLoc, type)
    consume(openToken)
    skipNewlines

    while (cur !== closeToken)
    {
      // parse tag name
      loc := curToLoc
      name := consumeName("Expecting dict tag name")

      // parse value or imply marker
      AData? val
      if (cur !== Token.colon)
      {
        val = impliedMarker(loc)
      }
      else
      {
        consume
        val = parseData
      }

      // add to map
      if (x.map[name] != null) throw err("Duplicate dict name: $name", loc)
      x.map.add(name, val)

      // check for comma or newline
      parseCommaOrNewline("Expecting end of dict tag", closeToken)
    }

    // close "}" or ">"
    consume(closeToken)
    return x
  }

  private Void setDocMeta(ASpec spec, Str? doc)
  {
    if (doc == null) return
    spec.initMeta.set("doc", impliedStr(spec.loc, doc))
  }


//////////////////////////////////////////////////////////////////////////
// Scalar Utils
//////////////////////////////////////////////////////////////////////////

  private AScalar impliedStr(FileLoc loc, Str str)
  {
    AScalar(loc, sys.str, str, str)
  }

  private AScalar impliedMarker(FileLoc loc)
  {
    AScalar(loc, sys.marker, marker.toStr, marker)
    //AScalar(loc, ASpecRef(loc, ASimpleName("sys", "Marker")), marker.toStr, marker)
  }

//////////////////////////////////////////////////////////////////////////
// TypeRef
//////////////////////////////////////////////////////////////////////////

  ** Parse a type signature
  private ASpecRef? parseTypeRef()
  {
    if (cur !== Token.id) return null

    loc := curToLoc
    name := parseTypeRefName
    return ASpecRef(loc, name)
  }

  ** Parsed qualified or unqualified dotted path name
  private AName parseTypeRefName()
  {
    // handle simple name as common case
    name := consumeName("Expecting type name")
    if (cur !== Token.dot && cur !== Token.doubleColon) return ASimpleName(null, name)

    // handle qualified and dotted names
    path := Str[,]
    path.add(name)
    while (cur === Token.dot)
    {
      consume
      path.add(consumeName("Expecting next name in dotted type name"))
    }

    // if no "::" then this is a unqualified dotted path
    if (cur !== Token.doubleColon) return APathName(null, path)
    consume

    // qualified name
    lib := path.join(".")
    if (cur !== Token.id) throw err("Expecting type name after double colon")
    name = consumeName("Expecting type name after double colon")
    if (cur !== Token.dot) return ASimpleName(lib, name)

    // qualified dotted path
    path.clear
    path.add(name)
    while (cur === Token.dot)
    {
      consume
      path.add(consumeName("Expecting next name in dotted type name"))
    }

    return APathName(lib, path)
  }

//////////////////////////////////////////////////////////////////////////
// Misc
//////////////////////////////////////////////////////////////////////////

  ** Parse end of dict tag or spec slot
  private Void parseCommaOrNewline(Str msg, Token close)
  {
    if (cur === Token.comma)
    {
      consume
      skipNewlines
      return
    }

    if (cur === Token.nl)
    {
      skipNewlines
      return
    }

    if (cur === close) return

    throw err("$msg: comma or newline, not $curToStr")
  }

  private Str? parseLeadingDoc()
  {
    Str? doc := null
    while (true)
    {
      // skip leading blank lines
      skipNewlines

      // if not a comment, then return null
      if (cur !== Token.comment) return null

      // parse one or more lines of comments
      s := StrBuf()
      while (cur === Token.comment)
      {
        s.join(curVal.toStr, "\n")
        consume
        consume(Token.nl)
      }

      // if there is a blank line after comments, then
      // this comment does not apply to next production
      if (cur === Token.nl) continue

      // use this comment as our doc
      doc = s.toStr.trimToNull
      break
    }
    return doc
  }

  private Str? parseTrailingDoc(Str? doc)
  {
    if (cur === Token.comment)
    {
      // leading trumps trailing
      if (doc == null) doc = curVal.toStr.trimToNull
      consume
    }
    return doc
  }

//////////////////////////////////////////////////////////////////////////
// Char Reads
//////////////////////////////////////////////////////////////////////////

  private Bool skipNewlines()
  {
    if (cur !== Token.nl) return false
    while (cur === Token.nl) consume
    return true
  }

  private Void verify(Token expected)
  {
    if (cur !== expected) throw err("Expected $expected not $curToStr")
  }

  private FileLoc curToLoc()
  {
    FileLoc(fileLoc.file, curLine, curCol)
  }

  private Str curToStr()
  {
    curVal != null ? "$cur $curVal.toStr.toCode" : cur.toStr
  }

  private Str consumeName(Str expecting)
  {
    if (cur !== Token.id) throw err("$expecting, not $curToStr")
    name := curVal.toStr
    consume
    return name
  }

  private Str consumeVal()
  {
    verify(Token.scalar)
    val := curVal
    consume
    return val
  }

  private Void consume(Token? expected := null)
  {
    if (expected != null) verify(expected)

    cur      = peek
    curVal   = peekVal
    curLine  = peekLine
    curCol   = peekCol

    peek     = tokenizer.next
    peekVal  = tokenizer.val
    peekLine = tokenizer.line
    peekCol  = tokenizer.col
  }

  private Err err(Str msg, FileLoc loc := curToLoc)
  {
    FileLocErr(msg, loc)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Step step
  private XetoCompiler compiler
  private ASys sys
  private const Obj marker
  private FileLoc fileLoc
  private Tokenizer tokenizer
  private Str[]? autoNames

  private Token cur      // current token
  private Obj? curVal    // current token value
  private Int curLine    // current token line number
  private Int curCol     // current token col number

  private Token peek     // next token
  private Obj? peekVal   // next token value
  private Int peekLine   // next token line number
  private Int peekCol    // next token col number
}
