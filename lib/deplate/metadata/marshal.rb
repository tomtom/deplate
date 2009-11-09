# encoding: ASCII
# yaml.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     20-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.16
#
# = Description
# = Usage
# = TODO
# = CHANGES

class Deplate::Core
    def module_initialize_metadata_marshal
        @options.metadata_model  = "marshal"
        @options.metadata_suffix = ".dat"
    end

    def put_metadata(io, metadata)
        Marshal.dump(metadata, io)
    end
end

