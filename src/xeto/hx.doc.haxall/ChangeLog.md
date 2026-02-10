<!--
title:      ChangeLog
author:     Brian Frank
created:    4 Aug 2021
copyright:  Copyright (c) 2021, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

*Build 4.0.5 (working)*

*Build 4.0.4 (7 Dec 2025)*
- Xeto new globals design
- Xeto new mixin design
- New hx.xeto func specx for merging mixins
- New hx.xeto funcs to reflect members and globals
- New companion lib dict design
- Use new `rt` tag for managed runtime recs
- New Settings|Sys view to replace Host settings
- Axonsh working again with standard lib management funcs
- Rename LibNamespace -> Namespace
- Rename SpecSlots -> SpecMap
- Formalize dict set with null value to be remove #8749
- Rename ProjSpecs to ProjCompanion
- Fix HTTP API handling to set modBase/modRel before onService
- Fix regression for trap operator on null #8742
- Modbus connector supports multiple scaling operations

*Build 4.0.4 (working)*

*Build 4.0.3 (21 Aug 2025)*
- User, Sys, Proj, Context moved into hx
- Ext now backed by xeto lib
- Ext now keyed by xeto dotted lib name
- Ext settings now managed in {proj}/ns
- Funcs now managed in {proj}/ns
- Rename hx::HxLib -> Ext
- Rename hx::HxLibWeb -> ExtWeb (and associated methods)
- Rename hxFoo::FooLib -> FooExt (and associated methods)
- Exts now keyed by their xeto lib name "task" -> "hx.task"
- Haxall libs.get("task") => exts.get("hx.task")
- HxUser -> User
- Remove Haxall services axon and Fantom APIs
- Haxall API now uses /api/{proj}/{op} pattern like SkySpark
- Move axon::CoreLib -> AxonFuncs
- Move hx::HxCoreFuncs -> hxm::HxFuncs
- Move axon is() function from xeto -> hx
- Axon func/funcs uses qname instead of def/name/lib now
- Axon cannot combine dot with qnames such as "123.axon::toStr"
- Conn connDupRef and connPointsVia needs to be ext name
- Folio readById with trash will return null
- Remove Context.filterPather (deprecated)
- EnergyStar connector is now open source

*Build 4.0.2 (11 Jul 2025)*
- Add AxonContext.ns
- Add HxRuntime.ns
- Remove AxonContext.xeto (nodoc)
- Remove DefsNamespace.xeto (nodoc)
- Move haystack::DependErr -> xeto::DependErr (nodoc)
- Rename pod xetoEnv -> xetom
- HxRuntime.libs -> libsOld (remove lib in favor of libsOld.get)
- Axon rename xetoReload -> libReload
- Axon remove libAdd, libRemove, libStatus funcs
- Fully remove deprecated Bin file support
- Temp removal of axonsh

*Build 4.0.1 (7 Jul 2025)*
- Move haystack::Dict -> xeto::Dict
- Move haystack::Marker -> xeto::Marker
- Move haystack::Ref -> xeto::Ref
- Move haystack::UnknownNameErr -> xeto::UnknownNameErr
- Move haystack::UnknownLibErr -> xeto::UnknownLibErr
- Move haystack::UnknownSpecErr -> xeto::UnknownSpecErr
- Dict.dis simplified, add Row.disOf
- Dict.get default parameter removed
- Move LibRepo.cur -> XetoEnv.cur.repo
- Rename haystack::Namespace -> DefNamespace
- Rename haystack::Lib -> DefLib
- Rename axon::AxonContext.ns -> defs
- Rename hx::HxRuntime.ns -> defs
- Rename haystack::HaystackTest.ns -> defs
- Project Haystack defs 4.0.0
- Xeto libs now versioned as 5.0.0

*Build 3.1.12 (26 Jun 2025)*
- FolioFile API
- hxIO support for folio files
- Fantom build 1.0.82
- Xeto CLI main moved from xetoTools to xeto
- ActorContext base type for all context types
- Fix his collection for imcompatible units
- Task metrics renamed and added evalLastDur

*Build 3.1.11 (9 Dec 2024)*
- Filter comparison of Numbers now requires same unit
- Xeto fits/fitsExplain defaults to tags only, new graph option
- Xeto validation for refs and target types
- Xeto validation for choices
- Xeto validation for value using spec meta
- Axon remove support for Xeto spec definition within language
- Axon remove support for Xeto slot spec references
- Axon AST dict for calls renamed target to func
- Axon remove dot call support when first arg is filter #8099
- Axon support for interface based dispatch
- Axon support for interface static methods
- Axon support for interface constructors
- Axon move xetoReload to hx lib
- New Axon funcs: gridReplace, evalToFunc, isDuration, isHisGrid, quantile
- Updated elec phase tags - PH #1109
- New synthetic ontology - PH #1125
- Redesign Java reflection code to use double checked locking
- Add HTTP setting for maxThreads
- Support for escaped tag names with leading two underbars
- Tweak %RH conversion ratio to match %
- Tighten up Folio tag value storage checks
- Fix for using SHA384 and SHA512 for hmac
- Fix to prevent keys from getting added with an empty alias
- Support for adding EC Keys through the CLI
- Fix readById, readByIds to not return records with trash tag
- Mqtt: allow configuration of sessionExpiryInterval

*Build 3.1.10 (23 Apr 2024)*
- Xeto new LibRepo and LibNamespae APIs replace XetoEnv
- Dict.spec removed, must use LibNamespace.specOf
- Dict.map added
- Xeto Lib.top/tops renamed to spec/specs
- Xeto global slots
- Xeto ph-gen redesign
- Xeto enum types
- Xeto sys::TimeZone enum
- Xeto sys::Unit enum
- Axon func xetoEnvReload renamed to xetoReload
- Axon new funcs: choiceOf
- New Xeto lib lazily loading design
- Number and unit quantity validation
- Add option to stripUncommittable to keep mod tag
- Change setColMeta, addColMeta to silently ignore when column not found

*Build 3.1.9 (1 Dec 2023)*
- New ECMA class-based JavaScript design
- Actor queue overflow limits
- Xeto support for instance data
- Redesign how Xeto specs are mapped to Haystack dicts
- Allow tag names to start with underbar
- Rename Xeto function library from data to xeto
- Fix Trio to handle T and F for true/false
- Fix to use TLS 1.3 when supported
- New noSort flag to ioWriteTrio
- New funcs: nowUtc, ioCreate, ioReadXeto, ioWriteXeto

*Build 3.1.8 (9 Jun 2023)*
- Axon shell
- Integrate data and xeto APIs
- New data function library
- New hx funcs: isWatched
- Connector hook to learn without open
- Haxall new platform APIs
- Haxall rename of hxSerial to hxPlatformSerial
- New strReplace point conversion
- Support for batch hisRead/hisWrite HTTP ops
- Flush out more HTTP API examples (in both Zinc and JSON)

*Build 3.1.7 (17 Feb 2023)*
- Add point conversion: boolToNumber
- Haystack 3.9.13
- New funcs: firstOfMonth, lastOfMonth
- More axon code examples in function docs
- Add session setting for maxSessionsPerUser
- Conn framework closed connector is onPing raises exception
- Conn support for multiple connectors per point with connPointsVia
- Date format support for quarter pattern
- Ephemeral tasks now linger for debugging
- Axon Usage more examples
- MQTT several bug fixes
- Ensure actor pools are always stopped on exit
- Dict each iteration is now always non-nullable

*Build 3.1.6 (15 Nov 2022)*
- Maintenance build
- Add opts to toMatrix()

*Build 3.1.5 (5 Oct 2022)*
- Support for Haxall developer program licensing
- Cloning support for cloneSyncHis
- New funcs: addCols
- More Axon examples in core functions
- Rework Number.toLocale pos;neg pattern behavior

*Build 3.1.4 (4 May 2022)*
- New design for choice defs
- New axon funcs: filter, parseSearch, refProjName, reFindAll, clamp, connPoints
- Axon string support: each, eachWhile, any, all
- Move toSites, toEquips, toPoints, equipToPoints to point ext
- Move matchPointVal, toOccupied to point ext
- Modify toPoints function to not implicitly call equipToPoints
- Fix toOccupied to not match other equipment's points
- Add toSpaces, toDevices functions
- Fix boundary conditions to maintain conn watch state
- New maxSessions setting
- Grid sort, reorderCols methods/functions ignore unknown cols
- Add user field to obsHisWrites observations for auditing

*Build 3.1.3 (24-Feb-2022)*
- New hxConn connector framework
- New MQTT connector
- New Nest connector
- New Ecobee connector
- Open source Haystack connector
- Open source SQL connector
- Open source Modbus connector
- Open source oBIX connector
- Open source Sedona connector
- Redesigned hxSerial library replaces serialMod
- New connector documentation in docHaxall
- Refactor dateSpan, span coercion in Axon
- New hx stub command line tool
- New hx crypto command line tool
- New funcs: streamCol, isNull, isNonNull

*Build 3.1.2 (17-Dec-2021)*
- New hxCrypto lib for arcbeam integration
- New hxClone lib to provide clone server
- New hxPy lib for python docker integration
- New docker API
- New mqtt API

*Build 3.1.1 (8 Sep 2021)*
- Initial release
