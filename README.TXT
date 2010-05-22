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

Either:

    $ ruby setup.rb config
    $ ruby setup.rb setup
    # ruby setup.rb install                 # may require root privilege

Or (short):

    # ruby setup.rb                         # may require root privilege

Or if you have sh/bash (this really is just a wrapper for the above):
  
    $ ./configure --help
    $ ./configure
    $ make
    # make install                          # may require root privilege

Or build a gem and install it:

    $ gem build deplate.gemspec
    # gem install deplate-VERSION.gem       # may require root privilege

Download the latest source-code from the sourceforge project site:

    http://sourceforge.net/projects/deplate/

The files in the "debian" sub-directory were contributed by Maxim Komar. 
You might want to adjust some paths.


== The ruby gem distribution

The gem file can be installed by running

    $ gem install deplate-VERSION.gem

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
