//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using compiler

**
** FileScanner parses one Fantom source file into the AFile AST.
** We use the real Fantom tokenizer so strings, comments, and
** multi-line constructs are handled correctly, then apply a simple
** structural scan of the token stream for type and slot declarations.
** Only types tagged with the @Gen facet are kept.
**
internal class FileScanner
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(GenCompiler c, APod pod, File file, Str src)
  {
    this.c    = c
    this.pod  = pod
    this.file = file
    this.src  = src
  }

//////////////////////////////////////////////////////////////////////////
// Scan
//////////////////////////////////////////////////////////////////////////

  ** Scan source into AFile; its types are the @Gen tagged types
  AFile scan()
  {
    afile = AFile(pod, file, src.splitLines)
    toks  = Tokenizer(Compiler(CompilerInput()), Loc.makeFile(file), src, true).tokenize
    pos   = 0
    while (cur != null)
    {
      // grammar is <using>* <typeDef>* where each type def
      // starts with doc comment, facets, or modifier keywords
      if (curt === Token.usingKeyword)  { skipStatement; continue }
      if (curt === Token.docComment)    { doc = cur; advance; continue }
      if (curt === Token.at)            { facetDef; continue }
      typeDef
    }
    return afile
  }

//////////////////////////////////////////////////////////////////////////
// Type Defs
//////////////////////////////////////////////////////////////////////////

  ** Parse type declaration thru matching close brace of its body
  private Void typeDef()
  {
    headerLine := line
    isConst := false; isAbstract := false; isMixin := false; isEnum := false

    // modifiers
    while (cur != null)
    {
      if (curt === Token.constKeyword) { isConst = true; advance }
      else if (curt === Token.abstractKeyword) { isAbstract = true; advance }
      else if (curt === Token.publicKeyword || curt === Token.internalKeyword || curt === Token.finalKeyword) advance
      else if (curt === Token.identifier && cur.val == "enum")  { isEnum = true; advance }
      else if (curt === Token.identifier && cur.val == "facet") advance
      else break
    }

    // class/mixin keyword and type name; advance on
    // unexpected token to guarantee scan progress
    if (curt === Token.mixinKeyword) isMixin = true
    else if (curt !== Token.classKeyword) { clearPending; advance; return }
    advance
    if (curt !== Token.identifier) { clearPending; advance; return }
    typeName := (Str)cur.val
    advance

    // scan past base/mixin list to body open brace
    while (cur != null && curt !== Token.lbrace) advance
    if (cur == null) return
    open := line
    advance

    // capture pending doc/facets
    start    := pendingStart(headerLine)
    typeDoc  := docRange
    genFacet := facets.find |x| { x.name == "Gen" }
    clearPending

    // scan body members thru matching close brace
    acc := ASlot[,]
    this.items = null
    bodyClose := body(acc, isEnum)

    // only keep types opted in with @Gen
    if (genFacet == null) return

    typeFlags := AFlags
    {
      it.isConst    = isConst
      it.isAbstract = isAbstract
      it.isMixin    = isMixin
      it.isEnum     = isEnum
    }
    type := AType(afile, typeName, typeFlags, toGen(genFacet), typeDoc, start..bodyClose, open, this.items)
    type.slots = acc
    acc.each |slot| { slot.parent = type }
    afile.types.add(type)
  }

//////////////////////////////////////////////////////////////////////////
// Type Body
//////////////////////////////////////////////////////////////////////////

  ** Scan type body members; return line of type's close brace
  private Int body(ASlot[] slots, Bool isEnum)
  {
    if (isEnum) enumItems
    while (cur != null)
    {
      if (curt === Token.rbrace)     { close := line; advance; clearPending; return close }
      if (curt === Token.semicolon)  { advance; continue }
      if (curt === Token.docComment) { doc = cur; advance; continue }
      if (curt === Token.at)         { facetDef; continue }
      slotDef(slots)
    }
    return afile.lines.size - 1
  }

  ** Scan comma separated enum items which must be first in body.
  ** The whole item list is recorded as the items line range.
  private Void enumItems()
  {
    Int? first := null
    Int? last  := null
    while (cur != null)
    {
      if (curt === Token.docComment) { doc = cur; advance; continue }
      if (curt !== Token.identifier) break
      if (first == null) first = pendingStart(line)
      last = line
      advance
      if (curt === Token.lparen) last = skipMatched(Token.lparen, Token.rparen)
      clearPending
      if (curt !== Token.comma) break
      advance
    }
    if (first != null) items = first..last
  }

  ** Scan one slot declaration including body if present
  private Void slotDef(ASlot[] slots)
  {
    start := pendingStart(line)
    end   := line
    isAbstract := false; isOverride := false; isStatic := false; sawAssign := false
    depth := 0                  // paren/bracket depth
    Str? methodName := null     // identifier before ( at depth zero
    Str? lastId := null         // last identifier before assign
    TokenVal? prev := null

    while (cur != null)
    {
      // body block at paren depth zero ends the declaration
      if (curt === Token.lbrace && depth == 0)
      {
        end = skipMatched(Token.lbrace, Token.rbrace)
        break
      }

      // newline at paren depth zero ends bodyless declaration
      if (cur.newline && depth == 0 && prev != null && !isContinuation(prev))
      {
        end = prev.line - 1
        break
      }

      if (curt === Token.lparen   || curt === Token.lbracket) depth++
      if (curt === Token.rparen   || curt === Token.rbracket) depth--
      if (curt === Token.abstractKeyword) isAbstract = true
      if (curt === Token.overrideKeyword) isOverride = true
      if (curt === Token.staticKeyword)   isStatic = true
      if (curt === Token.defAssign || curt === Token.assign) sawAssign = true
      if (curt === Token.identifier && !sawAssign)
      {
        if (methodName == null && depth == 0 && peekt === Token.lparen) methodName = cur.val
        lastId = cur.val
      }
      prev = cur
      advance
    }

    // only keep slots tagged with @Gen
    slotName := methodName ?: lastId
    genFacet := facets.find |x| { x.name == "Gen" }
    if (slotName == null || genFacet == null) { clearPending; return }

    slotFlags := AFlags
    {
      it.isAbstract = isAbstract
      it.isOverride = isOverride
      it.isStatic   = isStatic
    }
    slots.add(ASlot(slotName, slotFlags, toGen(genFacet), docRange, start..end))
    clearPending
  }

  ** Does previous token indicate the statement continues on next line
  private Bool isContinuation(TokenVal prev)
  {
    prev.kind === Token.dot   || prev.kind === Token.comma ||
    prev.kind === Token.colon || prev.kind === Token.assign ||
    prev.kind === Token.defAssign
  }

//////////////////////////////////////////////////////////////////////////
// Facets
//////////////////////////////////////////////////////////////////////////

  ** Parse facet at current @ token into pending facets
  private Void facetDef()
  {
    facetLine := line
    advance                            // @
    if (curt !== Token.identifier) return
    name := (Str)cur.val
    advance

    // qualified name such as @xeto::Gen
    if (curt === Token.doubleColon)
    {
      advance
      if (curt !== Token.identifier) return
      name = (Str)cur.val
      advance
    }
    Str? meta := null
    if (curt === Token.lbrace)
    {
      // capture first string or DSL literal in block as the Gen meta
      depth := 0
      while (cur != null)
      {
        if (curt === Token.lbrace) depth++
        else if (curt === Token.rbrace) { depth--; if (depth == 0) { advance; break } }
        else if ((curt === Token.strLiteral || curt === Token.dsl) && meta == null) meta = cur.val
        advance
      }
    }
    facets.add(AFacet(name, meta, facetLine))
  }

  ** Map @Gen facet to AGen with its raw meta parsed as a xeto dict
  private AGen toGen(AFacet facet)
  {
    meta := Etc.dict0
    if (facet.meta != null)
    {
      try
        meta = c.ns.io.readXeto("{" + facet.meta + "}")
      catch (Err e)
        c.err("Cannot parse @Gen meta: $facet.meta.toCode", FileLoc(file.osPath, facet.line+1), e)
    }
    return AGen(facet.line, facet.meta, meta)
  }

//////////////////////////////////////////////////////////////////////////
// Pending Doc/Facets
//////////////////////////////////////////////////////////////////////////

  ** Start line including pending doc and facets
  private Int pendingStart(Int declLine)
  {
    start := declLine
    if (doc != null) start = start.min(doc.line - 1)
    facets.each |x| { start = start.min(x.line) }
    return start
  }

  ** Pending doc comment zero based line range or null
  private Range? docRange()
  {
    if (doc == null) return null
    start := doc.line - 1
    return start .. start + ((Str[])doc.val).size - 1
  }

  ** Clear pending doc and facets
  private Void clearPending()
  {
    doc = null
    facets.clear
  }

//////////////////////////////////////////////////////////////////////////
// Tokens
//////////////////////////////////////////////////////////////////////////

  ** Current token or null at end
  private TokenVal? cur() { toks.getSafe(pos) }

  ** Current token kind or eof
  private Token curt() { cur?.kind ?: Token.eof }

  ** Peek next token kind or eof
  private Token peekt() { toks.getSafe(pos+1)?.kind ?: Token.eof }

  ** Current token zero based line number
  private Int line() { cur.line - 1 }

  ** Advance to next token
  private Void advance() { pos++ }

  ** Skip tokens until next statement (token flagged with newline)
  private Void skipStatement()
  {
    advance
    while (cur != null && !cur.newline) advance
  }

  ** Skip matched open/close pair; current token must be open.
  ** Return zero based line of the close token.
  private Int skipMatched(Token open, Token close)
  {
    depth := 0
    while (cur != null)
    {
      if (curt === open) depth++
      else if (curt === close)
      {
        depth--
        if (depth == 0) { closeLine := line; advance; return closeLine }
      }
      advance
    }
    return afile.lines.size - 1
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private GenCompiler c        // compiler
  private APod pod             // parent pod
  private const File file      // source file
  private const Str src        // source contents
  private AFile? afile         // scan result
  private TokenVal[]? toks     // tokenized source
  private Int pos              // current token index
  private TokenVal? doc        // pending doc comment token
  private AFacet[] facets := [,]  // pending facets
  private Range? items         // enum item list lines of current type
}

**************************************************************************
** AFacet
**************************************************************************

** AFacet models one pending facet during a scan
internal class AFacet
{
  new make(Str name, Str? meta, Int line)
  {
    this.name = name
    this.meta = meta
    this.line = line
  }

  const Str name      // facet simple name
  const Str? meta     // first string literal in facet block
  const Int line      // zero based line number

  override Str toStr() { "@$name" }
}

