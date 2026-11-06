//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Oct 2009  Brian Frank  Creation
//   1 Jan 2016  Brian Frank  Refactor into axon pod
//

using concurrent
using util
using xeto
using xetom
using haystack

**
** AxonContext manages the environment of an Axon evaluation
**
@Js
abstract class AxonContext : HaystackContext, CompContext
{

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  ** Current context for actor thread
  @NoDoc static AxonContext? curAxon(Bool checked := true)
  {
    curx(checked)
  }

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  @NoDoc new make() {}

//////////////////////////////////////////////////////////////////////////
// Overrides
//////////////////////////////////////////////////////////////////////////

  ** Xeto namespace
  abstract Namespace ns()

  ** Definition namespace - deprecated
  @NoDoc abstract DefNamespace defs()

  ** CompContext current time
  override once DateTime now() { DateTime.now(null) }

  ** Resolve dict by local or remote id
  @NoDoc virtual Dict? xqReadById(Ref ref, Bool checked := true) { throw UnsupportedErr() }

  ** Resolve toDateSpan default value
  @NoDoc virtual DateSpan toDateSpanDef() { DateSpan.today }

  ** Evaluate an expression or if a filter then readAll convenience
  @NoDoc virtual Obj? evalOrReadAll(Str src) { throw UnsupportedErr() }

  ** Foreign function interface plugin to map Axon to Fantom or other languages
  @NoDoc virtual AxonFFI? ffi() { null }

  ** Find top-level function by qname or name
  @NoDoc TopFn? resolveTopFn(Str name, Bool checked := true)
  {
    topName := TopName.parse(name, checked)
    if (topName == null) return null
    fn := resolveTop(topName, checked) as TopFn
    if (fn != null) return fn
    if (checked) throw UnknownFuncErr(name)
    return null
  }

  ** Resolve top level qualified/unqualifed name to type/func
  @NoDoc Obj? resolveTop(TopName x, Bool checked := true)
  {
    top := tops[x.qname]
    if (top != null) return top

    top = doResolveTop(x, checked)
    if (top != null) tops[x.qname] = top
    return top
  }

  ** Hook for custom implementations/overrides for top-level name resolution
  @NoDoc virtual Obj? doResolveTop(TopName x, Bool checked := true)
  {
    // qualified
    lib := x.lib == null ? null : ns.lib(x.lib, checked)
    if (x.lib != null && lib == null) return null

    // type or func
    if (x.isTopNameType)
    {
      return lib == null ?
             ns.unqualifiedType(x.name, checked) :
             lib.type(x.name, checked)
    }
    else
    {
      spec := lib == null ?
              resolveUnqualifiedFunc(x.name, x.loc, checked) :
              lib.funcs.get(x.name, checked)
      return spec != null ? spec.func.thunk : null
    }
  }

  ** Clear namespace derived caches such as resolved top-level names.
  ** Must be called when the namespace is modified while this context
  ** is still in use.
  @NoDoc Void nsCacheClear() { tops.clear }

  ** Resolve unqualified func name to its spec using Axon symbol
  ** resolution rules: op funcs lose to normal funcs, proj lib override
  @NoDoc Spec? resolveUnqualifiedFunc(Str name, FileLoc loc := FileLoc.eval, Bool checked := true)
  {
    // resolve func as list from namespace (cached in MNameespace)
    list := ns.funcs.getAll(name)
    if (list.size == 1) return list.first
    if (list.isEmpty)
    {
      if (checked) throw EvalErr("Unknown symbol '$name'", this, loc)
      return null
    }

    // funcs marked '<op>' define the HTTP wire semantics for a name; they
    // are never the Axon binding when a normal function shares the name
    nonOps := list.findAll |x| { x.meta.missing("op") }
    if (nonOps.size == 1) return nonOps.first

    // check if override from proj lib
    projIndex := -1
    allOverridable := true
    for (i := 0; i<list.size; ++i)
    {
      f := list[i]
      if (f.lib.name === XetoUtil.companionLibName)
        projIndex = i
      else if (f.meta.missing("overridable"))
        allOverridable = false
    }
    if (projIndex < 0) throw AmbiguousSpecErr(name)
    if (!allOverridable) throw InvalidOverrideErr("Func '$name' is not overridable: $list")
    return list[projIndex]
  }

/////////////////////////////////////////////////////////////////////////////
// Eval
//////////////////////////////////////////////////////////////////////////

  ** Parse Axon expression
  Expr parse(Str src, FileLoc loc := FileLoc.eval)
  {
    parser := Parser(src.in, loc)
    expr := parser.parse
    return expr
  }

  ** Lookup and call a function with the given arguments.  The arguments
  ** must be fully evaluated values such as Numbers, Dicts, Grids, etc.
  Obj? call(Str funcName, Obj?[] args)
  {
    evalToFunc(funcName).call(this, args)
  }

  ** Evaluate expression to a func: a top-level func or a closure
  Callable evalToFunc(Str src) { parse(src).evalToFunc(this) }

  ** Evaluate an Axon expression inside a new scope.
  ** Convenience for `evalExpr(parse(src, loc))`
  Obj? eval(Str src, FileLoc loc := FileLoc.eval)
  {
    evalExpr(parse(src, loc))
  }

  ** Evaluate an expression inside a given scope
  @NoDoc Obj? evalExpr(Expr expr, AxonScope? scope := null)
  {
    try
      return run(EvalFrame(scope ?: AxonScope(), expr))
    catch (ReturnErr e)
      return ReturnErr.take(this)
  }

//////////////////////////////////////////////////////////////////////////
// XetoContext
//////////////////////////////////////////////////////////////////////////

  ** Axon contexts can call function thunks
  @NoDoc override Bool xetoCanCallFuncs() { true }

  ** Return true if the given rec fits the given spec as defined by
  ** [xeto::Namespace.fits] which includes sugar specs.  This is used by
  ** haystack Filters with a spec name.  The spec name may be qualified
  ** or unqualified.
  @NoDoc override Bool xetoIsSpec(Str specName, xeto::Dict rec)
  {
    ns.fits(rec, ns.findType(specName))
  }

//////////////////////////////////////////////////////////////////////////
// HaystackContext
//////////////////////////////////////////////////////////////////////////

  ** Convert to Dict for use by [context()] Axon function
  @NoDoc override Dict toDict()
  {
    toDictExtra == null ? Etc.dict0 : Etc.makeDict(toDictExtra)
  }

  ** Add/remove a tag to use for [toDict] and [context()] Axon function
  @NoDoc Void toDictSet(Str name, Obj? val)
  {
    if (toDictExtra == null) toDictExtra = Str:Obj[:]
    if (val != null)
      toDictExtra.set(name, val)
    else
      toDictExtra.remove(name)
  }

  ** Call a func value with no args such as `today` passed as a span
  @NoDoc override Obj? callIfFunc(Obj? val)
  {
    fn := val as Callable
    return fn == null ? val : fn.call(this, Obj#.emptyList)
  }

//////////////////////////////////////////////////////////////////////////
// Heartbeat
//////////////////////////////////////////////////////////////////////////

  ** Get/set the timeout
  @NoDoc Duration? timeout
  {
    set
    {
      &timeout = it
      timeoutTicks = (it == null) ? Int.maxVal : Duration.nowTicks + it.ticks
    }
  }

  ** Default timeout to use across VM
  @NoDoc static const Duration timeoutDef := 1min

  ** Check background cancel/timeout state
  @NoDoc Void heartbeat(FileLoc loc)
  {
    // heartbeat callback for job cancel
    heartbeatFunc?.call

    // timeout
    if (Duration.nowFast.ticks > timeoutTicks && timeout != null)
      throw EvalTimeoutErr(timeout, this, loc)
  }

//////////////////////////////////////////////////////////////////////////
// Frame Stack
//////////////////////////////////////////////////////////////////////////

  ** Current top of the frame stack
  @NoDoc AxonFrame? curFrame(Bool checked := true)
  {
    f := stack.last
    if (f != null) return f
    if (checked) throw AxonEmptyStackErr("Axon empty frame stack")
    return null
  }

  ** Current function on top of call stack
  @NoDoc Fn? curFunc()
  {
    for (i := stack.size-1; i >= 0; --i)
    {
      f := stack[i] as CallFrame
      if (f != null && f.func.name != "curFunc")
        return f.func
    }
    return null
  }

  ** Push a new frame onto the stack, run it, and then pop it
  @NoDoc Obj? run(AxonFrame frame)
  {
    stack.push(frame)
    try
      return frame.run(this)
    finally
      stack.pop
  }

  ** Check security permissions to call given function
  @NoDoc virtual Void checkCall(Fn func) {}

//////////////////////////////////////////////////////////////////////////
// Scope Chain
//////////////////////////////////////////////////////////////////////////

  ** Current variable scope (must have at least one frame on the stack)
  @NoDoc AxonScope? curScope(Bool checked := true)
  {
    curFrame(checked)?.scope
  }

  ** Resolve a variable in current scope or raise exception if not bound
  internal Obj? resolve(Str name, FileLoc loc)
  {
    // lookup name from scope
    scope := curScope(false)
    if (scope != null)
    {
      val := scope.lookup(name)
      if (val !== AxonScope.notFound)
      {
        if (val === AxonScope.notConst) throw EvalErr("Var '$name' is not immutable and cannot be used in const func", this, loc)
        return val
      }
    }

    // resolve as unqualified top-level name
    return TopName(loc, null, name).eval(this)
  }

  ** Define a new variable in current scope
  internal Obj? define(Str name, Obj? val, FileLoc loc)
  {
    err := curScope(true).define(name, val)
    if (err != null) throw EvalErr(err, this, loc)
    return val
  }

  ** Assign to an existing variable
  internal Obj? assign(Str name, Obj? val, FileLoc loc)
  {
    err := curScope(true).assign(name, val)
    if (err != null) throw EvalErr(err, this, loc)
    return val
  }

  ** Get the variables in the current scope
  @NoDoc Str:Obj? varsInScope()
  {
    curScope(false)?.effective ?: Etc.emptyTags
  }

  ** Call func in a new frame using the given scope for its variables
  ** so the caller may read back the call's locals and params
  ** TODO
  @NoDoc Obj? callIn(Fn fn, Obj?[] args, FileLoc callLoc, AxonScope scope)
  {
    run(CallFrame(scope, fn, args, callLoc))
  }

//////////////////////////////////////////////////////////////////////////
// Trace
//////////////////////////////////////////////////////////////////////////

  ** Dump call stack trace to a string
  @NoDoc Str traceToStr(FileLoc errLoc, Dict? opts := null)
  {
    s := StrBuf()
    trace(errLoc, s.out, opts)
    return s.toStr
  }

  ** Dump call stack trace to a grid
  @NoDoc Grid traceToGrid(FileLoc errLoc, Dict? opts := null)
  {
    gb := GridBuilder().addCol("name").addCol("file").addCol("line").addCol("vars")
    traceWalk(errLoc, opts) |name, loc, vars|
    {
      gb.addRow([name, loc.file, Number(loc.line), vars])
    }
    return gb.toGrid
  }

  ** Dump call stack trace to output stream
  @NoDoc Void trace(FileLoc errLoc, OutStream out := Env.cur.out, Dict? opts := null)
  {
    traceVars := opts != null && opts.has("vars")
    traceWalk(errLoc, opts) |name, loc, vars|
    {
      if (loc === FileLoc.unknown)
        out.printLine("  $name")
      else
        out.printLine("  $name ($loc)")

      if (traceVars)
        vars.each |v, n| { out.print("    $n: ").print(Expr.summary(v)).printLine }
    }
  }

  ** Walk the trace call stack from top to bottom
  @NoDoc Void traceWalk(FileLoc errLoc, Dict? opts, |Str name, FileLoc loc, Dict vars| f)
  {
    // each frame is located where it is executing: the call site of
    // the frame above it or the error location for the top frame
    loc := errLoc
    for (i:= stack.size-1; i>=0; --i)
    {
      frame := stack.get(i) as CallFrame
      if (frame == null) continue
      f(frame.func.name, loc, Etc.dict0) // TODO: vars
      loc = frame.callLoc
    }
  }

//////////////////////////////////////////////////////////////////////////
// Caching
//////////////////////////////////////////////////////////////////////////

  ** Stash allows you to stash objects on the Context object
  ** during an Axon evaluation.  You should scope your string
  ** keys with your pod name to avoid naming collisions.
  Str:Obj? stash() { stashRef }
  private Str:Obj? stashRef := [:]

  ** Cache regular expression construction
  internal Regex toRegex(Obj s)
  {
    try
    {
      if (regex == null) regex = Str:Regex[:]
      r := regex[s]
      if (r == null) regex[s] = r = Regex.fromStr(s)
      return r
    }
    catch (CastErr e) throw CastErr("regex must be Str, not $s.typeof")
  }

//////////////////////////////////////////////////////////////////////////
// Private Fields
//////////////////////////////////////////////////////////////////////////

  @NoDoc Func? heartbeatFunc
  internal Obj? returnVal
  private Int timeoutTicks := Int.maxVal
  private AxonFrame[] stack := AxonFrame[,]
  private [Str:Obj] tops := [:]
  private [Str:Regex]? regex
  private [Str:Obj]? toDictExtra
}

