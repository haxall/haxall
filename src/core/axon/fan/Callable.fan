//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Nov 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** Callable is a function value that may be called: a top-level
** func or a closure of a lambda evaluated in a scope.
**
@Js
mixin Callable
{
  ** Function name; closures are named '{top}.{closure}'
  abstract Str name()

  ** Function parameters
  abstract FnParam[] params()

  ** Number of parameters
  abstract Int arity()

  ** Is this a lazy function that accepts un-evaluated arguments
  abstract Bool isLazy()

  ** Invoke with the given arguments and location of the call site
  ** used for errors and traces; lazy funcs receive the unevaluated
  ** argument exprs.  Note: the `args` parameter must be mutable and
  ** may be modified
  abstract Obj? call(AxonContext cx, Obj?[] args, FileLoc callLoc := FileLoc.unknown)

  ** Return a const version of this func that may be stored in dicts,
  ** lists, and grids.  Closures return a copy with a snapshot of the
  ** variables in their scope.  Raise NotImmutableErr if not supported.
  abstract Callable toConst()
}

**************************************************************************
** FantomCallable
**************************************************************************

**
** FantomCallable wraps a Fantom function as an Axon callable
**
@NoDoc
class FantomCallable : Callable
{
  ** Constructor
  new make(Func f) { this.f = f }

  ** Return "fan"
  override Str name() { "fantom" }

  ** Parameters of the Fantom function
  override once FnParam[] params() { FnParam.makeFantomList(f) }

  ** Number of parameters
  override Int arity() { params.size }

  ** Return false
  override Bool isLazy() { false }

  ** Call the Fantom function with the given args
  override Obj? call(AxonContext cx, Obj?[] args, FileLoc callLoc := FileLoc.unknown)
  {
    f.callList(args)
  }

  ** Fantom funcs cannot be const
  override Callable toConst() { throw NotImmutableErr("Fantom func cannot be const") }

  private Func f
}

**************************************************************************
** FilterCallable
**************************************************************************

**
** FilterCallable matches a dict argument against a filter
**
@Js
internal const class FilterCallable : Callable
{
  ** Constructor
  new make(Filter filter) { this.filter = filter }

  ** Filter to match
  const Filter filter

  ** Return "filterToFunc"
  override Str name() { "filterToFunc" }

  ** Single dict parameter
  override FnParam[] params() { paramsRef }

  ** Number of parameters
  override Int arity() { params.size }

  ** Return false
  override Bool isLazy() { false }

  ** Return if the dict argument matches the filter
  override Obj? call(AxonContext cx, Obj?[] args, FileLoc callLoc := FileLoc.unknown)
  {
    dict := args.first as Dict
    if (dict == null) throw EvalErr("Invalid arg, expected (Dict) not (${args.first?.typeof})", cx, callLoc)
    return filter.matches(dict, cx)
  }

  ** Return this
  override Callable toConst() { this }

  private static const FnParam[] paramsRef := [FnParam("dict")]
}

