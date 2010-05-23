deplate -- convert wiki-like markup to latex, docbook, html, and 
"html-slides"
Copyright (C) 2004 Tom Link

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  
USA


= Install

== The source distribution

Basically, you have the following four options:

Either (1) use setup.rb (long version):

    $ ruby setup.rb config
    $ ruby setup.rb setup
    # ruby setup.rb install             # this might require root privilege

Or (short):

    # ruby setup.rb                     # this might require root privilege

Or (2) if you have sh/bash (but this really is just a wrapper for the above):
  
    $ chmod u+x configure               # when using the git repository
    $ ./configure --help
    $ ./configure
    $ make
    # make install                      # this might require root privilege

Or (3) build a gem and install it:

    $ ruby bin/pre-setup.rb
    $ gem build deplate.gemspec
    # gem install deplate-VERSION.gem   # this might require root privilege

Or (4) add the bin directory to PATH:

    $ export PATH=DEPLATE_DIRECTORY/bin:$PATH

Download the latest source-code from the sourceforge project site:

    http://sourceforge.net/projects/deplate/

The files in the "debian" sub-directory were contributed by Maxim Komar. 
You might want to adjust some paths.


== The ruby gem distribution

The gem file can be installed by running

    $ gem install deplate-VERSION.gem       # might require root privilege

When installing from a gem file, it could be necessary to manually 
link/copy the deplate starter script in the GEMDIR/bin directory.


== The win-32 distribution

The win32 binary was created with exerb[1] and is supposed to work 
without ruby being installed. The binary is self-contained and doesn't 
rely on any extranous files. Just copy the binary into a directory in 
PATH.

The distribution directory contains some extra files in the rc 
directory, which you could copy to the respective sub-directories in 
~/.deplate/.

[1] http://exerb.sourceforge.jp/index.en.html


= Documentation

The documentation is distributed in a separate archive or can be 
downloaded from

    http://deplate.sf.net/deplate.html

The online manual usually corresponds to the latest testing/working 
version.


vim: ft=rd
