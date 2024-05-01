//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Sep 2009  Brian Frank  Creation
//

using concurrent
using haystack

**
** Stream based parser for Axon scripts.
**
@Js @NoDoc
class Parser
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Loc startLoc, InStream in)
  {
    this.startLoc = startLoc
    tokenizer = Tokenizer(startLoc, in)
    cur = peek = peekPeek = Token.eof
    consume
    consume
    consume
  }

//////////////////////////////////////////////////////////////////////////
// Parse expression
//////////////////////////////////////////////////////////////////////////

  Expr parse()
  {
    r := cur === Token.defcompKeyword ? defcomp("top", Etc.emptyDict) : expr
    if (cur !== Token.eof) throw err("Expecting end of file, not $cur ($curVal)")
    return r
  }

  TopFn parseTop(Str name, Dict meta := Etc.emptyDict)
  {
    loc := curLoc
    curName = name
    Fn? fn := null

    if (cur === Token.defcompKeyword)
    {
      fn = defcomp(name, meta)
    }
    else
    {
      if (cur !== Token.lparen) throw err("Expecting '(...) =>' top-level function")
      consume(Token.lparen)
      params := params()
      if (cur !== Token.fnEq) throw err("Expecting '(...) =>' top-level function")
      fn = lamdbaBody(loc, params, meta)
    }

    if (cur !== Token.eof) throw err("Expecting end of file, not $cur ($curVal)")
    return fn
  }

  protected Expr namedExpr(Str name)
  {
    curName = name
    e := expr
    curName = null
    return e
  }

  protected Expr expr()
  {
    if (cur === Token.id)
    {
      if (peek === Token.colon) return def
      if (peek === Token.fnEq) return lambda1
    }
    if (cur === Token.doKeyword)     return doBlock
    if (cur === Token.ifKeyword)     return ifExpr
    if (cur === Token.lbracket)      return termExpr(list)
    if (cur === Token.lbrace)        return termExpr(dict)
    if (cur === Token.returnKeyword) return returnExpr
    if (cur === Token.throwKeyword)  return throwExpr
    if (cur === Token.tryKeyword)    return tryCatchExpr
    return assignExpr
  }

  private Expr doBlock()
  {
    consume(Token.doKeyword)
    exprs := [expr]
    while (true)
    {
      if (cur === Token.endKeyword) { consume; break }
      if (cur === Token.elseKeyword) break  // can omit end for else
      if (cur === Token.catchKeyword) break // can omit end for catch
      if (cur === Token.eof) throw err("Expecting 'end', not end of file")
      eos
      if (cur === Token.endKeyword) { consume; break }
      if (cur === Token.elseKeyword) break  // can omit end for else
      if (cur === Token.catchKeyword) break // can omit end for catch
      if (cur === Token.eof) throw err("Expecting 'end', not end of file")
      exprs.add(expr)
    }
    return Block(exprs)
  }

  protected Bool isEos()
  {
    cur === Token.semicolon || nl
  }

  protected Void eos()
  {
    if (cur === Token.semicolon) { consume; return }
    if (nl) return
    throw err("Expecting newline or semicolon, not $curToStr")
  }

//////////////////////////////////////////////////////////////////////////
// CompDef
//////////////////////////////////////////////////////////////////////////

  private Fn defcomp(Str name, Dict meta)
  {
    // defcomp keyword
    compLoc := curLoc
    consume(Token.defcompKeyword)
    compRef := AtomicRef()

    // cells as "name: {meta}"
    cells := MCellDef[,]
    cellsMap := Str:MCellDef[:]
    while (cur !== Token.doKeyword && cur !== Token.endKeyword)
    {
      cellLoc := curLoc
      c := cell(compRef, cells.size)
      if (cellsMap[c.name] != null) throw err("Duplicate cell names: $c.name", cellLoc)
      cells.add(c)
      cellsMap.add(c.name, c)
    }

    // optional do/end bodhy
    Expr body := Literal.nullVal
    if (cur === Token.doKeyword) body = doBlock

    // end keyword
    consume(Token.endKeyword)

    // create CompDef implementation
    def := MCompDef(compLoc, name, meta, body, cells, cellsMap)
    compRef.val = def

    // update inner closures with reference to outer scope
    bindInnersToOuter(def)

    return def
  }

  private CellDef cell(AtomicRef compRef, Int index)
  {
    name := consumeIdOrKeyword("Expecting cell name")
    consume(Token.colon)
    meta := constDict
    if (meta.has("name")) throw err("Comp cell meta cannot define 'name' tag")
    eos
    return MCellDef(compRef, index, name, meta)
  }

//////////////////////////////////////////////////////////////////////////
// Def
//////////////////////////////////////////////////////////////////////////

  **
  ** Name definition:
  **   <def> :=  <id> ":" <expr>
  **
  private DefineVar def()
  {
    loc := curLoc
    name := consumeId("variable name")
    consume(Token.colon)
    return DefineVar(loc, name, namedExpr(name))
  }

//////////////////////////////////////////////////////////////////////////
// If Expression
//////////////////////////////////////////////////////////////////////////

  **
  ** If/then/else:
  **   <if>  :=  "if" "(" <expr> ")" <expr> ["else" <expr>]
  **
  private Obj ifExpr()
  {
    loc := curLoc
    consume
    consume(Token.lparen)
    cond := expr
    consume(Token.rparen)
    trueVal  := expr
    Expr falseVal := Literal.nullVal
    if (cur === Token.elseKeyword)
    {
      consume
      falseVal = expr
    }
    return If(cond, trueVal, falseVal)
  }

//////////////////////////////////////////////////////////////////////////
// Return Expression
//////////////////////////////////////////////////////////////////////////

  **
  ** Throw
  **   <throw>  :=  "throw" <expr>
  **
  private Obj returnExpr()
  {
    consume(Token.returnKeyword)
    if (nl) throw err("return must be followed by expr on same line")
    return Return(expr)
  }

//////////////////////////////////////////////////////////////////////////
// Throw Expression
//////////////////////////////////////////////////////////////////////////

  **
  ** Return:
  **   <return>  :=  "return" <expr>
  **
  private Obj throwExpr()
  {
    consume(Token.throwKeyword)
    if (nl) throw err("throw must be followed by expr on same line")
    return Throw(expr)
  }

//////////////////////////////////////////////////////////////////////////
// Try/Catch Expression
//////////////////////////////////////////////////////////////////////////

  **
  ** Try/catch:
  **   <tryCatch>  :=  "try" <expr> "catch" ["(" <id> ")"] <expr>
  **
  private Obj tryCatchExpr()
  {
    consume(Token.tryKeyword)
    body := expr
    consume(Token.catchKeyword)
    Str? errVarName := null
    if (cur === Token.lparen && peek == Token.id && peekPeek === Token.rparen)
    {
      consume
      errVarName = consumeId("exception variable name")
      consume
    }
    catcher := expr
    return TryCatch(body, errVarName, catcher)
  }

//////////////////////////////////////////////////////////////////////////
// Collections
//////////////////////////////////////////////////////////////////////////

  **
  ** List
  **   <list>      := "[" <listItems> "]"
  **   <listItems> := [ <expr> ("," <expr>)* [","] ]
  **
  private Expr list()
  {
    consume(Token.lbracket)
    if (cur === Token.rbracket) { consume; return ListExpr.empty }
    acc := Expr[,]
    allValsConst := true
    while (true)
    {
      val := expr
      acc.add(val)
      if (!val.isConst) allValsConst = false
      if (cur !== Token.comma) break
      consume
      if (cur === Token.rbracket) break
    }
    consume(Token.rbracket)
    return ListExpr(acc, allValsConst)
  }

  **
  ** Dict
  **   <dict>          := "{" <dictItems> "}"
  **   <dictItems>     := [ <dictItem> ("," <dictItem>)* [","] ]
  **   <dictItem>      := <dictVal> | <dictMarker> | <dictRemove>
  **   <dictVal>       := <id> ":" <expr>
  **   <dictMarker>    := <id>
  **   <dictRemove>    := "-" <id>
  **
  private DictExpr dict()
  {
    open := Token.lbrace
    close := Token.rbrace

    consume(open)
    if (cur === close) { consume; return DictExpr.empty }
    loc := curLoc
    names := Str[,]
    vals  := Expr[,]
    allValsConst := true
    while (true)
    {
      Expr val := Literal.markerVal
      if (cur === Token.minus)
      {
        consume
        val = Literal.removeVal
      }

      Str? name
      if (cur === Token.val && curVal is Str) { name = curVal; consume }
      else name = consumeIdOrKeyword("dict tag name")

      names.add(name)
      if (cur === Token.colon)
      {
        if (val === Literal.removeVal) throw err("Cannot have both - and val in dict: $name")
        consume
        val = expr
      }
      if (!val.isConst) allValsConst = false
      vals.add(val)
      if (cur !== Token.comma)
      {
        if (cur !== close) throw err("Expecting colon and value after $name.toCode dict literal")
        break
      }
      consume
      if (cur === close) break
    }
    consume(close)

    return DictExpr(loc, names, vals, allValsConst)
  }

  ** Parse dict literal
  protected Dict constDict()
  {
    expr := dict
    if (expr.constVal == null) throw err("Dict cannot use expressions", expr.loc)
    return expr.constVal
  }

//////////////////////////////////////////////////////////////////////////
// Operator Expressions
//////////////////////////////////////////////////////////////////////////

  **
  ** Assignment expression:
  **    <assignExpr> :=  <condOrExpr> ("=" <assignExpr>)
  **
  private Expr assignExpr()
  {
    // this is tree if built to the right (others to the left)
    expr := condOrExpr
    if (cur !== Token.assign) return expr
    consume
    return Assign(expr, this.expr())
  }

  **
  ** Conditional or expression:
  **   <condOrExpr>   :=  <condAndExpr> ("or" <condAndExpr>)*
  **
  private Expr condOrExpr()
  {
    expr := condAndExpr
    if (cur !== Token.orKeyword) return expr
    consume
    return Or(expr, condOrExpr)
  }

  **
  ** Conditional and expression:
  **   <condAndExpr>  :=  <compareExpr> ("and" <compareExpr>)*
  **
  private Expr condAndExpr()
  {
    expr := compareExpr
    if (cur !== Token.andKeyword) return expr
    consume
    return And(expr, condAndExpr)
  }

  **
  ** Comparison expression:
  **   <compareExpr>  :=  <addExpr> (("==" | "!=" | "<" | "<=" | ">=" | ">") <addExpr>)*
  **
  private Expr compareExpr()
  {
    expr := rangeExpr
    if (inSpec > 0) return expr // don't parse ">" as Gt if inside spec meta
    switch (cur)
    {
      case Token.eq:    consume; return Eq(expr, rangeExpr)
      case Token.notEq: consume; return Ne(expr, rangeExpr)
      case Token.lt:    consume; return Lt(expr, rangeExpr)
      case Token.ltEq:  consume; return Le(expr, rangeExpr)
      case Token.gtEq:  consume; return Ge(expr, rangeExpr)
      case Token.gt:    consume; return Gt(expr, rangeExpr)
      case Token.cmp:   consume; return Cmp(expr, rangeExpr)
    }
    return expr
  }

  **
  ** Additive expression:
  **   <rangeExpr>  :=  <addExpr> ".." <addExpr>
  **
  private Expr rangeExpr()
  {
    expr := addExpr
    if (cur === Token.dotDot)
    {
      consume
      expr = RangeExpr(expr, addExpr)
    }
    return expr
  }

  **
  ** Additive expression:
  **   <addExpr>  :=  <multExpr> (("+" | "-") <multExpr>)*
  **
  private Expr addExpr()
  {
    expr := multExpr
    while (true)
    {
      if (cur === Token.plus)  { consume; expr = Add(expr, multExpr); continue }
      if (cur === Token.minus) { consume; expr = Sub(expr, multExpr); continue }
      break
    }
    return expr
  }

  **
  ** Multiplicative expression:
  **   <multExpr>  :=  <unaryExpr> (("*" | "/") <unaryExpr>)*
  **
  private Expr multExpr()
  {
    expr := unaryExpr
    while (true)
    {
      if (cur === Token.star)  { consume; expr = Mul(expr, unaryExpr); continue }
      if (cur === Token.slash) { consume; expr = Div(expr, unaryExpr); continue }
      break
    }
    return expr
  }

  **
  ** Unary expression:
  **   <unaryExpr> :=  ("-" | "not") <termExpr>
  private Expr unaryExpr()
  {
    if (cur === Token.minus)      { consume; return Neg(termExpr).foldConst }
    if (cur === Token.notKeyword) { consume; return Not(termExpr).foldConst }
    return termExpr
  }

  **
  ** Term expression:
  **   <termExpr>   :=  <termBase> <termChain>*
  **   <termChain>  :=  <call> | <methodCall> | <index> | <tag-get>
  **
  private Expr termExpr(Expr? start := null)
  {
    expr := start ?: termBase
    while (true)
    {
      if (cur === Token.lparen && !nl)   { expr = call(expr, false); continue }
      if (cur === Token.lbracket && !nl) { expr = index(expr); continue }
      if (cur === Token.dot)      { expr = call(expr, true); continue }
      if (cur === Token.arrow)    { expr = dictGet(expr); continue }
      break
    }
    return expr
  }

  **
  ** Term base expression:
  **   <termBase> :=  <var> | <groupedExpr> | <literal>
  **
  private Expr termBase()
  {
    if (cur === Token.lparen) return parenExpr
    if (cur === Token.val)    return Literal(consumeVal)
    if (cur === Token.id)     return termId
    if (cur === Token.typename) return typeRef(null)
    if (cur === Token.trueKeyword)  { consume; return Literal.trueVal }
    if (cur === Token.falseKeyword) { consume; return Literal.falseVal }
    if (cur === Token.nullKeyword)  { consume; return Literal.nullVal }
    throw err("Unexpected token $cur")
  }

  **
  ** Variable or spec qname:
  **   <var>          :=  <qname>
  **   <typeRef>      :=  [<typeLibName> "::"] <typename>
  **   <typeLibName>  :=  <id> ("." <id>)*
  **
  private Expr termId()
  {
    loc := curLoc
    name := consumeId("name")

    if (cur !== Token.doubleColon) return Var(loc, name)
    consume

    if (cur === Token.typename)
      return typeRef(name)
    else
      return Var(loc, name + "::" + consumeIdOrKeyword("func qname"))
  }

  **
  ** Function application:
  **   <call>         :=  "(" [<callArg> ("," <callArg>)*] [<lambda>]
  **   <callArg>      :=  <expr> | "_"
  **   <dotCall>      :=  "." [<nl>] <qname> [<call> | <lamdba-1>]
  **
  private Expr call(Expr target, Bool isMethod)
  {
    args := isMethod ? Expr?[target] : Expr?[,]

    methodName := "?"
    if (isMethod)
    {
      consume(Token.dot)

      methodName = consumeIdOrKeyword("func name")

      if (cur === Token.doubleColon)
      {
        consume
        if (cur === Token.typename)
          return specFromDottedPath(target, methodName)
        else
          methodName = methodName + "::" + consumeIdOrKeyword("func qname")
      }

      if (cur !== Token.lparen)
      {
        if (cur === Token.id && peek === Token.fnEq)
          args.add(lambda1)
        return toDotCall(methodName, args)
      }
    }

    numPartials := 0
    if (nl) throw err("opening call '(' paren cannot be on new line")
    consume(Token.lparen)
    if (cur !== Token.rparen)
    {
      while (true)
      {
        if (cur === Token.underbar)
        {
          ++numPartials
          args.add(null)
          consume
        }
        else
        {
          args.add(expr)
        }
        if (cur === Token.rparen) break
        consume(Token.comma)
      }
    }
    consume(Token.rparen)

    // trailing lamdba
    if (!isEos && (cur === Token.id || cur === Token.lparen))
      args.add(lamdba)

    call := isMethod ? toDotCall(methodName, args) : Call(target, args)
    if (numPartials > 0)
      return PartialCall(call.target, call.args, numPartials)
    else
      return call
  }

  ** Create DotCall vs StaticCall based on first arg
  private Call toDotCall(Str methodName, Expr[] args)
  {
    if (args.first.type === ExprType.typeRef)
      return StaticCall(args[0], methodName, args[1..-1])
    else
      return DotCall(methodName, args)
  }

  **
  ** Indexing operation:
  **   <index>  := "[" <expr> "]"
  ** Convenience for "get" methodCall
  **
  private Expr index(Expr target)
  {
    consume(Token.lbracket)
    arg := expr
    consume(Token.rbracket)
    return DotCall("get", [target, arg])
  }

  **
  ** Indexing operation:
  **   <trapCall> := "->" <id>
  ** Convenience for "trap" methodCall
  **
  private Expr dictGet(Expr target)
  {
    consume(Token.arrow)
    name := consumeId("dict tag name")
    return TrapCall(target, name)
  }

//////////////////////////////////////////////////////////////////////////
// Lambda Expression
//////////////////////////////////////////////////////////////////////////

  **
  ** Lamdba
  **   <lambda>    :=  <lambda-1> | <lambda-n>
  **   <lambda-1>  :=  <id> "=>" <expr>
  **   <lambda-n>  :=  "(" <params> ")" "=>" <expr>
  **
  private Fn lamdba()
  {
    loc := curLoc
    if (cur === Token.id) return lambda1
    if (cur === Token.lparen)
    {
      expr := parenExpr
      if (expr is Fn) return expr
    }
    throw err("Expecting lamdba expr", loc)
  }

  **
  ** Single parameter lamdba:
  **   <lamdba-1>  :=  <id> "=>" <expr>
  **
  private Fn lambda1()
  {
    loc := curLoc
    params := [FnParam(consumeId("func parameter name"))]
    return lamdbaBody(loc, params)
  }

  **
  ** Expression grouped by parens which could be either:
  **   <groupedExpr> :=  "(" <expr> ")"
  **   <lamdba-n>    :=  "(" <params> ")" "=>" <expr>
  **
  private Expr parenExpr()
  {
    loc := curLoc
    consume(Token.lparen)

    // lamdba "()=>" ...
    if (cur === Token.rparen && peek === Token.fnEq)
    {
      consume
      return lamdbaBody(loc, noParams)
    }

    // lamdba "(id)=>..."
    if (cur === Token.id && peek === Token.rparen && peekPeek == Token.fnEq)
    {
      id := consumeId("func parameter name")
      consume
      return lamdbaBody(loc, [FnParam(id)])
    }

    // lamdba "(id,...)=>..." or "(id:...)=>..."
    if (cur === Token.id && (peek === Token.comma || peek === Token.colon))
    {
      params := params()
      return lamdbaBody(loc, params)
    }

    // "(expr)" just normal expr grouped by parens
    expr := expr()
    consume(Token.rparen)
    return expr
  }

  **
  ** Parse lamdba parameters, the lead '(' must already be consumed
  **
  private FnParam[] params()
  {
    acc := FnParam[,]
    if (cur !== Token.rparen)
    {
      acc.add(param)
      while (cur === Token.comma)
      {
        consume
        acc.add(param)
      }
    }
    consume(Token.rparen)
    return acc
  }

  private FnParam param()
  {
    name := consumeId("func parameter name")
    if (cur !== Token.colon) return FnParam(name)
    consume
    return FnParam(name, expr)
  }

//////////////////////////////////////////////////////////////////////////
// Types
//////////////////////////////////////////////////////////////////////////

  **
  ** <typeRef>     :=  [<typeLibName> "::"] <typename>
  ** <typeLibName> :=  <id> ("." <id>)*
  **
  private TypeRef typeRef(Str? lib)
  {
    loc := curLoc

    // lib qname
    if (lib == null && (cur === Token.id || cur.keyword))
    {
      lib = consumeIdOrKeyword("spec lib name")
      while (cur === Token.dot)
      {
        consume
        lib = lib + "." + consumeIdOrKeyword("spec lib name")
      }
      if (cur !== Token.doubleColon) throw err("Expecting :: for spec qname")
      consume
    }

    if (cur !== Token.typename) throw err("Expecting spec typename")

    typename := curVal
    consume
    return TypeRef(loc, lib, typename)
  }

  **
  ** Convert dotted calls followed by "::" Typename back into a qualified
  ** spec reference.  This method is called when we encounter a "::Foo"
  ** capitalized type name after a string of dotted calls such as "a.b.c::Foo".
  ** We have to unroll the series of DotCall with a root Var into a library
  ** qname.
  **
  private Expr specFromDottedPath(Expr base, Str lastName)
  {
    // build up list of names from end back to start
    names := Str[,]
    names.add(lastName)
    while (true)
    {
      if (base.type === ExprType.var)
      {
        // var will be the first name in the lib path
        var := (Var)base
        names.add(var.name)
        return typeRef(names.reverse.join("."))
      }
      if (base.type ===  ExprType.dotCall)
      {
        // dotted call such as "foo.bar.baz"
        dot := (DotCall)base
        if (dot.args.size == 1)
        {
          names.add(dot.funcName)
          base = dot.args[0]
          continue
        }
      }
      throw err("Invalid spec qname: $base", base.loc)
    }
    throw err("illegal state")
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  **
  ** Handle a lamdba with current token on '=>'.
  ** This is a single point where we handle naming
  ** and lexically scoping all our functions.
  **
  private Fn lamdbaBody(Loc loc, FnParam[] params, Dict? topMeta := null)
  {
    // create new scope of inner functions
    oldInners := inners
    inners = Fn[,]

    // figure out func name
    oldFuncName := curFuncName
    if (curName != null) { curFuncName = curName; curName = null }
    else curFuncName = "anon-${++anonNum}"
    if (oldFuncName != null) curFuncName = oldFuncName + "." + curFuncName

    // parse body
    consume(Token.fnEq)
    body := expr

    // optimize out return if only or last expr
    body = optimizeLastReturn(body)

    // create fn
    fn := topMeta != null ?
          TopFn(loc, curFuncName, topMeta, params, body) :
          Fn(loc, curFuncName, params, body)

    // update any closures with a reference to outer scope
    bindInnersToOuter(fn)
    inners = oldInners.add(fn)
    curFuncName = oldFuncName
    return fn
  }

  private Expr optimizeLastReturn(Expr expr)
  {
    if (expr.type === ExprType.returnExpr) return ((Return)expr).expr
    if (expr.type === ExprType.block)
    {
      block := (Block)expr
      if (block.exprs.last.type == ExprType.returnExpr)
        return Block(block.exprs.dup.set(-1, optimizeLastReturn(block.exprs.last)))
    }
    return expr
  }


  private Void bindInnersToOuter(Fn fn)
  {
    inners.each |inner| { inner.outerRef.val = fn }
  }

  protected SyntaxErr err(Str msg, Loc loc := curLoc) { SyntaxErr(msg, loc) }

  protected Loc curLoc() { Loc(startLoc.file, startLoc.line + curLine) }

//////////////////////////////////////////////////////////////////////////
// Char Reads
//////////////////////////////////////////////////////////////////////////

  protected Str consumeId(Str expected)
  {
    if (cur != Token.id) throw err("Expected $expected, not $curToStr")
    id := curVal
    consume
    return id
  }

  protected Str consumeIdOrKeyword(Str expected)
  {
    if (cur.keyword)
    {
      id := cur.symbol
      consume
      return id
    }
    return consumeId(expected)
  }

  protected Obj? consumeVal()
  {
    verify(Token.val)
    val := curVal
    consume
    return val
  }

  protected Void verify(Token expected)
  {
    if (cur != expected) throw err("Expected $expected, not $curToStr")
  }

  private Str curToStr()
  {
    if (cur === Token.id) return "identifier '$curVal'"
    if (cur === Token.val) return "value " + Etc.toAxon(curVal)
    return cur.toStr
  }

  protected Void consume(Token? expected := null)
  {
    if (expected != null) verify(expected)

    nl             = curLine != peekLine

    cur            = peek
    curVal         = peekVal
    curLine        = peekLine

    peek           = peekPeek
    peekVal        = peekPeekVal
    peekLine       = peekPeekLine

    peekPeek       = tokenizer.next
    peekPeekVal    = tokenizer.val
    peekPeekLine   = tokenizer.line
 }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const static Expr[] noArgs  := Expr#.emptyList
  private const static FnParam[] noParams := FnParam#.emptyList

  private Loc startLoc         // location immediately before first line
  private Tokenizer tokenizer  // stream tokenizer

  Token cur  { private set }   // current token
  Obj? curVal { private set }  // current token value
  private Int curIndent        // current token indentation
  private Bool nl := true      // if current first token on new line
  private Int curLine          // current token line number

  Token peek { private set }   // next token
  Obj? peekVal { private set } // next token value
  private Int peekLine         // next token line number

  private Token peekPeek       // next, next token
  private Obj? peekPeekVal     // next, next token value
  private Int peekPeekLine     // next, next token line

  private Str? curName         // if parsing define value
  private Str? curFuncName     // current name of base func
  private Int anonNum          // number of anonymous funcs
  private Fn[] inners := [,]   // current number of funcs inside current
  private Int inSpec           // if inside spec production
}

