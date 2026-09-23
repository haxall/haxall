<!--
author:     Brian Frank
created:    17 Sep 2026
copyright:  Copyright (c) 2026, SkyFoundry LLC, All Rights Reserved
-->

# xetoc Design

The xetoc pod is the Xeto compiler: it parses Xeto source into an
AST, runs a pipeline of steps over it, and assembles the runtime
implementation types from xetom.  It also implements the file based
lib repo used to scan and load xetolibs from disk.

## Organization

- `fan/parser/`: tokenizer and parser producing the AST
- `fan/ast/`: AST node types (ALib, ASpec, AData, refs, depends)
- `fan/compiler/`: MXetoCompiler pipelines and their steps
- `fan/repo/`: FileRepo scan of lib path, FileEnv, FileLibVersion

## Pipelines

All pipelines are step lists run by MXetoCompiler:

- `compileLib`: compile a source directory to a Lib and xetolib zip
- `readData`: compile input to instance data dicts
- `readAst`: parse lib source into its Dict AST representation
- `parseLibMeta`: parse only lib.xeto into a LibVersion
- `parseLibSymbols`: parse top-level symbol names in a lib directory

Step lists:

    compileLib:      InitLib, ParseLib, Resolve, InheritBase,
                     InheritEnums, InheritSlots, LoadBindings,
                     MixinMeta, InferMeta, ReifyMeta, InheritMeta,
                     InferInstances, ReifyInstances, CheckErrors,
                     Assemble, Validate, ReuseThunks, OutputZip

    readData:        InitData, ParseData, Resolve, InferInstances,
                     ReifyInstances, CheckErrors, Validate

    readAst:         InitAst, ParseLib, Resolve, MixinMeta,
                     InferMeta, AstToDict

    parseLibMeta:    InitParseLibMeta, ParseLib

    parseLibSymbols: InitParseSymbols, ParseLib

## Steps

- `Init` (InitLib, InitData, InitAst, ...): validate inputs and
  setup compiler state per pipeline
- `Parse` (ParseLib, ParseData): parse source files into the AST
- `Resolve`: resolve depends and all refs to their specs/instances
- `InheritBase`: base, typeRef, and flags for top-level specs;
  cyclic inheritance checks; tops in inheritance order (mixins
  first, bases before subtypes)
- `InheritEnums`: enum types; item coercion, keys, implied sealed,
  default val, members
- `InheritSlots`: effective member maps; own slot overrides resolved
  against inherited members and mixin members in dependency scope;
  nested slot base/typeRef/flags
- `InheritFlags`: shared base class for the flags computation used
  by the inherit steps
- `LoadBindings`: assign a SpecBinding to each type
- `MixinMeta`: effective sys::Spec/sys::Lib meta slots including
  mixins; sets compiler.metas
- `InferMeta`/`InferInstances`: infer types/tags for spec meta and
  instance dicts
- `ReifyMeta`/`ReifyInstances`: reify AST data into concrete Fantom
  values; finalize metaOwn
- `InheritMeta`: effective meta for all specs
- `CheckErrors`: AST validation; includes sugar body rules (members
  must resolve to existing tags, no new structure) and a single
  nominal anchor via `MSugar.anchors`
- `Assemble`: assemble AST into xetom implementation instances
- `Validate`: run the xetom validation engine over reified instances
  and spec meta using rules from the depends closure; rules of the
  lib under compile never run at compile time
- `ReuseThunks`: reuse func thunks when recompiling the companion lib
- `AstToDict`: encode AST into dicts (readAst only)
- `OutputZip`: write the xetolib zip

## Invariants

- Step readiness: base/typeRef/flags valid after InheritBase (done
  marker is `flags >= 0`), members after InheritSlots (done marker is
  `members != null`); reading earlier throws NotReadyErr or "Flags
  not set yet"
- AST vs assembled: the own lib is ASpec/ALib, depend libs are
  assembled XetoLib; some Spec accessors throw on ASpec (membersOwn
  always, others until their step runs), so code touching both must
  branch on `isAst`
- Two scopes: compile semantics see only the depends, never the
  ambient namespace the compile runs inside - same source plus same
  resolved depends always yields the same output; the namespace-wide
  view is `Namespace.specx`.  Ref resolution uses the direct declared
  depends only; discovery checks (mixins, meta vocabulary, validate
  rules, choice subtypes) use the transitive closure.  ADepends owns
  the depends bookkeeping and always excludes the lib under compile;
  ANamespace is the compile's CNamespace layering the lib under
  compile over the closure
- Nothing effective persists: member maps are computed per compile
  and xetolibs recompile from source per environment; only declared
  state (slotsOwn, globalsOwn, meta) is stored or transported
- A top's base is declared (its type); a slot's base is an output of
  its parent's override resolution - which is why they finalize in
  different steps
- Testing: `fant testXeto`; yaml fixture suites in
  `testXeto/tests/`; `ns.compileTempLib` for quick source snippets;
  fixture libs in `hx.test.xeto`
