//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Oct 2019  Brian Frank  Creation
//

using haystack
using axon

**
** OptimizeTest
**
@Js
class OptimizeTest : Test
{
  Void testReturn()
  {
    verifyNormalize("(x) => x", "(x) => x")

    verifyNormalize("(x) => return x", "(x) => x")

    verifyNormalize("do return 3; return 4 end",
      """do
           return 3;
           return 4;
         end
         """)

    verifyNormalize("() => do return 3; return 4 end",
      """() => do
           return 3;
           4;
         end
         """)

    // we don't optimize every case...

    verifyNormalize("""() => if (true) return 3 else return 4""",
      """() => if (true) return 3 else return 4""")

    verifyNormalize(
      """(x) => do
           if (x) return 3 else return 4
         end
         """,
      """(x) => do
           if (x) return 3 else return 4;
         end
         """)

     // torture case
    verifyNormalize(
      """(x) => do
           if (x) return 1
           else do
             return 2
           end
           f: () => return 3
           g: () => do
             h: () => return 4
             return 5
             return 6
           end
           return 7
           return 8
         end
         """,
      """(x) => do
           if (x) return 1 else do
             return 2;
           end
           f: () => 3;
           g: () => do
             h: () => 4;
             return 5;
             6;
           end
           return 7;
           8;
         end
         """)
  }

  Void verifyNormalize(Str src, Str expected)
  {
    actual := Parser(Loc.eval, src.in).parse.toStr
    // echo("\n------\n$actual")
    verifyEq(actual, expected)
  }
}