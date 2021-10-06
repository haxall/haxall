<p align="center">
  <a href="https://haxall.io/" target="_blank" rel="noopener noreferrer">
    <img src="https://haxall.io/res/haxall-logo.svg" width="550" height="128">
  </a>
</p> 

# Haxall Overview
Haxall is an open source software framework for the Internet of Things. 
It includes an extensive toolkit for working with [Project Haystack](https://project-haystack.org/) 
data. Use it right out of the box as a flexible IoT data gateway which runs at 
the edge. Haxall is written in [Fantom](https://fantom.org/) with 
runtime support for both the Java VM and JavaScript environments.

See [https://haxall.io](https://haxall.io) for more more information.

# Build from Source 

### Install or Build Fantom
 
1. See [Fantom Setup](https://fantom.org/doc/docTools/Setup)

2. Make sure 'fan' or 'fan.exe' is your executable path

### Build Haystack-Defs 

1. Pull from the [Haystack-Defs GitHub](https://github.com/Project-Haystack/haystack-defs) repo

2. Setup empty "fan.props" in repo root directory

3. CD to your `{haystack-defs}` root directory and run `fan -version`; verify 
your Env Path is as follows: `haystack-defs (work), fantom (home)`
  
4. Run `{haystack-defs}/src/build.fan`; should build to `{haystack-defs}/lib/`

### Build Haxall  

1. Pull from [this repo](https://github.com/haxall/haxall)
 
2. Setup "fan.props" in repo root of Haxall with this line:

       path=/path-to/haystack-defs 
 
3. CD to your `{haxall}` root directory and run `fan -version`; verify your 
Env Path is as follows: `haxall (work), haystack-defs, fantom (home)` 

4. Set the environment variable `FAN_BUILD_JDKHOME` to point to your JDK install

5. Run `{haxall}/src/build.fan`; should build to `{haxall}/lib/`
 
# Getting Started

1. Run `hx version` to verify the install (use `fan hx` while current working dir 
is under Haxall repo)

2. Run `hx init <dir>` to initialize a project directory and follow prompts 
to enter superuser credentials and HTTP port to run on 

3. Run `hx run <dir>` to run the Haxall Daemon for the dir setup in previous step

4. Hit `http://localhost:8080/` using port and superuser credentials you setup in step 2

5. Try out some Axon expressions in the browser Shell UI 
 
# License
Haxall is released under the [Academic Free License 3.0](https://opensource.org/licenses/AFL-3.0). 
