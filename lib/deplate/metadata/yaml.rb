# encoding: ASCII
# yaml.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     20-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.13
#
# = Description
# = Usage
# = TODO
# = CHANGES

require 'yaml'

class Deplate::Core
    def module_initialize_metadata_yaml
        @options.metadata_model  = "yaml"
        @options.metadata_suffix = ".yml"
    end

    def dump_metadata(data)
        YAML.dump(data)
    end
end

