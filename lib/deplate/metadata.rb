# encoding: ASCII
# metadata.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     15-Aug-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.9
#
# = Description
# = Usage
# = TODO
# = CHANGES

# require ''

# Metadata: 
class Deplate::Metadata
    attr_accessor :metadata
    
    def initialize(deplate, output=nil)
        @deplate  = deplate
        @output   = output
        @metadata = {}
    end
    
    def merge_metadata(metadata)
        if @deplate.options.metadata_model
            for e in metadata
                push_metadata(e)
            end
        end
    end

    def push_metadata(data)
        if @deplate.options.metadata_model
            type = data["type"]
            @metadata[type] ||= []
            @metadata[type] << data
        end
    end

    def metadata_available?
        !@metadata.empty?
    end
    
    def destination(destination=nil)
        if destination
            destination
        elsif @output
            @output.destination
        else
            # <+TBD+>
            ''
        end
    end
    
    def metadata_destination(master_file=nil)
        dest = destination(master_file)
        Deplate::Core.canonic_file_name(dest, @deplate.options.metadata_suffix)
    end

    def format_metadata(metadata=@metadata)
        unless metadata.nil? or metadata.empty?
            for type, value in metadata
                if value
                    for e in value
                        e['file'] = destination.dup
                    end
                end
            end
            metadata['creator'] = 'deplate'
            metadata['creator_version'] = Deplate::Core.version
            @deplate.dump_metadata(metadata)
        end
    end
end

