<!--
author:     Brian Frank
created:    6 Nov 2026
copyright:  Copyright (c) 2026, SkyFoundry LLC, All Rights Reserved
-->

# axon Design

The axon pod implements the Axon language: parser, AST, evaluation
context, and the core library of Axon funcs implemented in Fantom.

## Organization

- `fan/parser/`: tokenizer and parser producing the AST
- `fan/ast/`: AST nodes; every node is a const `Expr` with `eval`
- `fan/lib/`: Fantom funcs (`FantomFn`), thunks, FFI, RPC
- `fan/stream/`: lazy stream pipelines (`MStream`)
- `fan/xeto/`: xeto bindings and validation of axon source
- `AxonContext`: frame stack, variable resolution, top-level lookup
- `AxonFrame`: `EvalFrame` and `CallFrame`
- `AxonScope`: lexical variable scope
- `Callable`: function values

## Functions

`Fn` is the AST definition of a function.  `Callable` is the type of
a function value at runtime; Fantom funcs that take an Axon func use
`Callable`.

- `TopFn`: top-level func in the namespace; it is both an `Fn` and a
  `Callable`.  `FantomFn`, `LazyFantomFn`, and `CompFn` subclass it.
- `Lambda`: anonymous func expression.  It is never a value itself:
  evaluating it returns a `Closure` over the current scope.
- `Closure`: a lambda paired with the `AxonScope` it was evaluated
  in.  It is mutable because the scope is.
- `ConstClosure`: a lambda paired with an immutable snapshot of its
  scope, created by `toConst`.
- `FilterCallable`, `FantomCallable`: adapt a filter or Fantom func.

`Fn.callNested` is the only way a function body runs.  `TopFn.call`
checks security and calls it with no parent scope; closures call it
with their captured scope as parent.  `Fn` itself has no `call`, so a
lambda cannot run outside its closure.

## Scopes and Frames

`AxonContext` keeps a stack of frames for calls, traces, and
`curFunc`.  Each frame has an `AxonScope` for its variables:

- `EvalFrame`: root expression eval or a switch case body
- `CallFrame`: a func call; its constructor sets its params in its
  scope.  `Fn.callNested` is kept small since it is the hot path of
  every closure call and must stay inlined by the JIT

Variable scope is lexical, not dynamic: a scope's parent is the scope
the func was defined in, never the caller's.  A `TopFn` call has no
parent, so it cannot see the caller's locals.  `FantomFn` runs in the
caller's scope since natives have no locals of their own.

`AxonScope` is a single class.  Different kinds of scope are handled
with private markers in its vars map rather than subclasses, which
keeps every lookup a plain monomorphic call on the hot path:

- `nullVal`: stored for a null value so a lookup is one hash lookup
  that tells "bound to null" apart from "not bound"
- `notFound`: returned by `lookup` if the name is not in the chain
- `notConst`: stored by `toConstVars` for a captured value that could
  not be made immutable

The markers never escape `AxonScope` except `notFound` and `notConst`
returned from `lookup` to `AxonContext.resolve`.  `get`, `has`, and
`effective` treat a `notConst` var as undefined.  Fantom callers
create scopes with `AxonScope()` and fill them with `set`.
`AxonContext.callIn` runs a func with a caller supplied scope for
component calls that seed `this` and read back the call's variables.

## Actor Local Context

Fantom funcs find their context with `AxonContext.curAxon`, which
reads the actor local.  `AxonContext.run` installs the context as the
actor local when it pushes the outermost frame of an evaluation, and
restores the previous context when that frame pops.  So:

- a context's Axon code always runs with that context installed, so
  natives see the right context, user, and project
- switching to a different context is only allowed by a fresh entry
  (`eval`, `evalExpr`, `callIn`, or a closure called on an empty
  stack); nested evaluation of other contexts forms a strict stack
- `FantomFn.call` verifies the actor local is its calling context and
  raises `ContextMismatchErr` rather than patching it, since a native
  running under the wrong context could run as the wrong user.  This
  catches Fantom code that changes the actor local inside an
  evaluation without restoring it, or re-enters a context that is
  mid-eval while another is installed.  `FantomFn.checkCx` turns the
  check off once it has proven itself in the field (about 23ns per
  native call)

## Const Closures

Closures capture a live mutable scope, so they cannot be stored in
dicts, lists, or grids.  `Callable.toConst` returns a const func:
`TopFn` and other const callables return themselves; `Closure`
snapshots its scope chain with `AxonScope.toConstVars` into a
`ConstClosure`; `FantomCallable` raises `NotImmutableErr`.

The snapshot keeps immutable values, converts lists and maps with
`toImmutable`, and stores `notConst` for anything else, typically
other local lambdas.  It snapshots the whole chain rather than only
the names the lambda uses, so there is no free variable analysis.

Each `ConstClosure` call wraps the readonly snapshot map with
`AxonScope.makeConst` (no copy) as the parent of the call scope:

- reading a `notConst` var raises "is not immutable" from `resolve`
- assigning a captured var raises "cannot assign" since the map is
  readonly; the func may still define its own locals
- a skipped local that shadows a top-level func raises an error
  rather than silently calling the global

A dict literal that fails because a value is a closure, directly or
nested in a list, reports a hint to use `toConst`.

## Hosting Axon

A language that embeds Axon, such as sketch markup with `{expr}`
holes, shares Axon's tokenizer and parser rather than finding where
the Axon ends itself:

- the host subclasses `Tokenizer` and overrides `next`: in its own
  modes it reads chars with `cur`, `peek`, and `consume`, counts
  newlines in `line`, and returns `Token.foreign` with its token as
  `val`; inside Axon it calls super
- the host owns the switch between modes, such as counting braces to
  find the `}` that ends a hole, since the tokenizer must know which
  mode it is in before the parser's lookahead reads past the end
- the host subclasses `Parser` with `makeTokenizer`, passes its own
  tokens thru, and calls the protected productions such as `expr` and
  `casePattern` for the Axon in between
- one char stream and one line count serve both, so locations need no
  translation

## Errors

Scope methods never throw.  `define` and `assign` return null on
success or an error message, and `lookup` returns a marker.
`AxonContext.resolve`, `define`, and `assign` turn these into
`EvalErr` with the Axon location of the expression.
