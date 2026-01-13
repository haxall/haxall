//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Mar 2025  Matthew Giannini  Creation
//

using xeto
using haystack

// TODO: should this be defined in haxall somwhere, but then it can't sub-type HxCompObj
// unless we push that mixin lower in dependency

// This is an implementation of sys.comp::Var. We might need to define
// hx.rule::RuleVar or something so we have ownership of the root type in rule lib
class Var : HxComp
{
  virtual Obj? val { get {get("val")} set {set("val", it)} }

  override Void bindIn(Obj? val)
  {
    this.val = val
  }
}

class BoolVar : Var
{
  Bool? bool() { val }
}

class DateVar : Var
{
  Date? date() { val }
}

class DateTimeVar : Var
{
  DateTime? dateTime() { val }
}

class NumberVar : Var
{
  Number? num() { val }
}

class RefVar : Var
{
  Ref? ref() { val }
}

class StrVar : Var
{
  Str? str() { val }
}

class TimeVar : Var
{
  Time? time() { val }
}

class EntityVar : Var
{
  Dict? rec() { this.val }
}

class GridVar : Var
{
  Grid? grid() { this.val }
}

