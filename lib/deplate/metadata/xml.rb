# encoding: ASCII
# xml.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     20-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.32
#
# = Description
# = Usage
# = TODO
# = CHANGES

require 'rexml/document'

class Deplate::Core
    def module_initialize_metadata_marshal
        @options.metadata_model  = "xml"
        @options.metadata_suffix = ".xml"
        @options.metadata_xml = REXML::Document.new <<EOXML
<deplate>
</deplate>
EOXML
        @options.metadata_xml << REXML::XMLDecl.new
    end

    def put_metadata(io, metadata)
        @options.metadata_xml.write(io, 2)
    end
    
    alias :push_metadata_re_metadata_xml :push_metadata
    def push_metadata(data, array=@metadata)
        if @options.metadata_model
            type = data["type"]
            d    = data.dup
            d.delete('type')
            @options.metadata_xml.root.add_element(type, d)
            push_metadata_re_metadata_xml(data, array)
        end
    end
end

