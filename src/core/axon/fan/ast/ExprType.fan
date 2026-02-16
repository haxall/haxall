//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Sep 2009  Brian Frank  Creation
//

**
** ExprType enum to type all Enum subclasses
**
@NoDoc
@Js
enum class ExprType
{
  // literals/collections
  literal,
  list,
  dict,
  range,
  filter,  // special for core::parseFilter

  // constructs
  def,
  var,
  func,
  call,
  dotCall,
  staticCall,
  trapCall,
  partialCall,
  block,
  ifExpr,
  returnExpr,
  throwExpr,
  tryExpr,
  topName,

  // assignment
  assign("="),

  // logical compares,
  not("not"),
  and("and"),
  or("or"),

  // binary compares
  eq("=="),
  ne("!="),
  lt("<"),
  le("<="),
  ge(">="),
  gt(">"),
  cmp("<=>"),

  // math
  neg("-"),
  add("+"),
  sub("-"),
  mul("*"),
  div("/")

  private new make(Str? op := null) { this.op = op }

  internal Str encode() { name.endsWith("Expr") ? name[0..-5] : name }

  const Str? op

}

