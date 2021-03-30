You can use the defc program in SkySpark to recompile Project Haystack 4 libs.
This lets you compile the HTML docs which are used in the project-haystack.dev
website yourself.  It will also perform validation to verify that proposed
changes to the standard libs are correct.

First off make sure you can run defc from the command line using SkySpark:

  bin/fan defc -?

This should print out something as follows:

  Usage:
    defc [options] <output>*
  Arguments:
    output    Output format: html, csv, zinc, trio, json, turtle, dist
  Options:
    -help, -?       Print usage help
    -version, -v    Print version info
    -dir <File>     Output directory (default file:/skyspark/doc-def/)
    -pods <Str>     List of additional comma separated pod names

To recompile the Project Haystack pods to html requires no command line
options and will put the resulting HTML files in your {home}/doc-def/
directory.  You can change the output location with the '-dir' option.

To make changes to the core Project Haystack libs (ph, phScience, phIot,
or phICT), you can pull the lastest source code from GitHub and recompile
as follows:

1. Make a backup of your skyspark '{home}/lib' directory so that you
   can fallback to the built-in Project Haystack pods when all done

2. Clone the GitHub repo to your SkySpark '{home}' directory:

  cd {home}
  git clone git@github.com:Project-Haystack/haystack-defs.git

  This will create a directory called '{home}/haystack-defs'

3. Edit the Trio files under '{home}/haystack-defs/src' to make changes
   you want to test out

4. Recompile the Trio files to Fantom pods:

  bin/fan haystack-defs/src/build.fan

  You should see new versions compiled to {home}/lib/fan/

5. Rebuild the HTML documentation:

  bin/fan defc

