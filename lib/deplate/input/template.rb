# encoding: ASCII
# template.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     10-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.128

class Deplate::Input::Template < Deplate::Input
    self.myname = 'template'

    def initialize(deplate, args)
        args.update(Deplate::Template.deplate_options.dup)
        super
        @deplate.options.keep_whitespace = true
    end
end

class Deplate::Core
    def input_initialize_deplate
        @options.input_class = Deplate::Input::Template
    end
end

