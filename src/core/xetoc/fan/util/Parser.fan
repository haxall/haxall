//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Aug 2022  Brian Frank  Creation
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
    this.env = step.env
    this.sys = step.sys
    this.marker = env.marker
    this.fileLoc = fileLoc
    this.tokenizer = Tokenizer(in) { it.keepComments = true }
    this.cur = this.peek = Token.eof
    consume
    consume
  }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  Void parse(AObj root)
  {
    try
    {
      parseObjs(root)
      verify(Token.eof)
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
// Parsing
//////////////////////////////////////////////////////////////////////////

  private Void parseObjs(AObj parent)
  {
    while (true)
    {
      if (!parseObj(parent)) break
      parseEndOfObj
    }
  }

  private Bool parseObj(AObj parent)
  {
    // leading comment
    doc := parseLeadingDoc

    // end of file or closing symbols
    if (cur === Token.eof) return false
    if (cur === Token.rbrace) return false
    if (cur === Token.gt) return false

    // this token is start of our object production
    loc := curToLoc
    Str? name := null
    AObj? obj := null

    // <named> | <markerOnly> | <unnamed>
    if (cur === Token.id && peek === Token.colon)
    {
      name = consumeName
      consume(Token.colon)
      obj = parent.makeChild(loc, name)
      parseBody(obj)
    }
    else if (cur === Token.id && curVal.toStr[0].isLower && peek !== Token.dot && peek !== Token.doubleColon)
    {
      name = consumeName
      obj = parent.makeChild(loc, name)
      obj.typeRef = sys.marker
      obj.val = AScalar(loc, marker.toStr, marker)
    }
    else
    {
      obj = parent.makeChild(loc, autoName(parent))
      parseBody(obj)
    }

    // trailing comment
    doc = parseTrailingDoc(doc)

    add(parent, obj, doc)
    return true
  }

  private AObj parseBody(AObj obj)
  {
    a := parseSpec(obj)
    b := parseChildrenOrVal(obj)
    if (!a && !b) throw err("Expecting object body not $curToStr")
    return obj
  }

  private Bool parseChildrenOrVal(AObj obj)
  {
    // skip newlines which preceed a "{" or value
    while (cur === Token.nl)
    {
      if (peek === Token.nl) { consume; continue }
      if (peek === Token.lbrace || peek === Token.val) { consume; break }
      return false
    }

    if (cur === Token.lbrace)
      return parseChildren(obj, Token.lbrace, Token.rbrace)

    if (cur === Token.val)
      return parseVal(obj)

    return false
  }

  private Bool parseChildren(AObj obj, Token open, Token close)
  {
    obj.initSlots
    consume(open)
    skipNewlines
    parseObjs(obj)
    if (cur !== close)
    {
      throw err("Unmatched closing '$close.symbol'")
    }
    consume(close)
    return true
  }

  private Bool parseVal(AObj obj)
  {
    obj.val = AScalar(curToLoc, curVal, null)
    consume
    return true
  }

  private Bool parseSpec(AObj obj)
  {
    obj.typeRef = parseType(obj)

    if (obj.typeRef == null)
    {
      // allow <meta> without type only for sys::Obj
      if (cur !== Token.lt) return false
      if (!compiler.isSys) throw err("Must specify type name before <meta>")
    }

    if (cur === Token.lt)
      parseMeta(obj)

    return true
  }

  private Void parseMeta(AObj obj)
  {
    parseChildren(obj.metaInit(sys), Token.lt, Token.gt)
  }

  ARef? parseType(AObj obj)
  {
    if (cur !== Token.id) return null

    type := parseTypeSimple("Expecting type name")
    if (cur === Token.question)  return parseTypeMaybe(obj, type)
    if (cur === Token.amp)       return parseTypeCompound("And", sys.and, obj, type)
    if (cur === Token.pipe)      return parseTypeCompound("Or", sys.or,  obj, type)
    return type
  }

  private ARef parseTypeCompound(Str dis, ARef compoundType, AObj obj, ARef first)
  {
    // add 'ofs' as list of type refs to the obj.meta
    ofs := AVal(first.loc, obj, "ofs")
    ofs.typeRef = sys.list
    ofs.initSlots
    ofs.asmToListOf = Spec#
    add(obj.metaInit(sys), ofs)

    // parse Type <sep> Type <sep> Type ...
    sepToken := cur
    addCompoundType(ofs, first)
    while (cur === sepToken)
    {
      consume
      skipNewlines
      addCompoundType(ofs, parseTypeSimple("Expecting next '$dis' type after $sepToken"))
    }
    return compoundType
  }

  private Void addCompoundType(AObj ofs, ARef type)
  {
    typeRef := AVal(type.loc, ofs, compiler.autoName(ofs.slots.size))
    typeRef.typeRef = type
    ofs.slots.add(typeRef)
  }

  private ARef parseTypeMaybe(AObj obj, ARef type)
  {
    consume(Token.question)

    // set type
    obj.typeRef = type

    // add maybe marker
    step.metaAddMarker(obj, "maybe")

    return type
  }

  private ARef parseTypeSimple(Str errMsg)
  {
    if (cur !== Token.id) throw err(errMsg)
    loc := curToLoc
    name := consumeQName
    return ARef(loc, name)
  }

  private Void parseEndOfObj()
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

    if (cur === Token.rbrace) return
    if (cur === Token.gt) return
    if (cur === Token.eof) return

    throw err("Expecting end of object: comma or newline, not $curToStr")
  }

//////////////////////////////////////////////////////////////////////////
// AST Manipulation
//////////////////////////////////////////////////////////////////////////

  private Void add(AObj parent, AObj child, Str? doc := null)
  {
    // add doc to object meta if its a spec
    addDoc(child, doc)

    // allocate slots if first add
    slots := parent.initSlots

    // check for duplicate or add
    name := child.name
    dup := slots.get(name)
    if (dup != null)
      compiler.err2("Duplicate name '$name'", dup.loc, child.loc)
    else
      slots.add(child)
  }

  private Str autoName(AObj parent)
  {
    parent.initSlots
    for (i := 0; i<1_000_000; ++i)
    {
      name := compiler.autoName(i)
      if (parent.slots.get(name) == null) return name
    }
    throw Err("Too many children")
  }

  private Void addDoc(AObj obj, Str? docStr)
  {
    // short circuit if null
    if (docStr == null) return

    // don't add docs to data values, specs only
    if (!obj.isSpec) return

    // if already present skip it
    meta := obj.metaInit(sys)
    if (meta.slot("doc") != null) return

    // add it to meta
    loc := obj.loc
    docObj := AVal(loc, meta, "doc")
    docObj.typeRef = sys.str
    docObj.val = AScalar(loc, docStr, docStr)
    meta.initSlots.add(docObj)
  }

//////////////////////////////////////////////////////////////////////////
// Doc
//////////////////////////////////////////////////////////////////////////

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

  private AName consumeQName()
  {
    Str? lib := null
    name := consumeName
    while (cur === Token.dot)
    {
      consume
      name += "." + consumeName
    }
    if (cur === Token.doubleColon)
    {
      consume
      lib = name
      name = consumeName
    }
    return AName(lib, name)
  }

  private Str consumeName()
  {
    verify(Token.id)
    name := curVal.toStr
    consume
    return name
  }

  private Str consumeVal()
  {
    verify(Token.val)
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
  private MEnv env
  private FileLoc fileLoc
  private Tokenizer tokenizer
  private const Obj marker
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

