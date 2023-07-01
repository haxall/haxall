//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

using util
using xeto

**
** Assign a SpecFactory to each AType in the AST
**
@Js
internal class AssignFactories : Step
{
  override Void run()
  {
    // check if we need to install a new factor loader
    typeName := pragma.meta.slot("factoryLoader")?.val?.str
    if (typeName != null) env.factories.install(typeName)

    // build up list of type names
    specNames := Str[,]
    lib.slots.each |spec|
    {
      if (spec.isType) specNames.add(spec.name)
    }

    // check factory loaders for factories to use for this lib
    factories := env.factories.load(lib.qname, specNames)

    // now assign factories to all type level types
    lib.slots.each |spec|
    {
      if (spec.isType) assignFactory(spec, factories)
    }
  }

  private Void assignFactory(AType type, Str:SpecFactory factories)
  {
    // lookup custom registered factory
    type.factoryRef = factories[type.name]

    // install default dict/scalar factory
    if (type.factoryRef == null)
    {
      if (type.flags.and(MSpecFlags.scalar) != 0)
        type.factoryRef = env.factories.scalar
      else
        type.factoryRef = env.factories.dict
    }
  }

}