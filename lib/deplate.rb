#!/usr/bin/env ruby
# deplate.rb -- Convert wiki-like plain text pseudo markup to something else
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     24-Feb-2004.
# @Last Change: 2009-11-09.

require 'profile' if ARGV[0] == '--profile'

require 'deplate/core'

require 'deplate/input'
require 'deplate/output'
require 'deplate/cache'
require 'deplate/common'
require 'deplate/variables'
require 'deplate/counters'
require 'deplate/etc'
require 'deplate/elements'
require 'deplate/regions'
require 'deplate/commands'
require 'deplate/macros'
require 'deplate/particles'
require 'deplate/define'
require 'deplate/template'
require 'deplate/skeletons'
require 'deplate/bib'
require 'deplate/external'
require 'deplate/metadata'

if __FILE__ == $0
    require 'deplate/builtin'
    Deplate::Core.deplate
end

