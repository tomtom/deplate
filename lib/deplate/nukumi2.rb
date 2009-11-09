# encoding: ASCII
# nukumi2.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     31-Dez-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.37
#
# = Usage
# Add require 'deplate/nukumi2' to your nukumi2 config.rb.
# 
# = TODO
# - check inline latex etc. (set the directory for auxiliary files)

require 'deplate/deplate-string'

if Nukumi2::VERSION != '0.5'
    Deplate::Core.log('deplate support was created for Nukumi2 0.5 and is not guaranteed to work with other versions', :anyway)
end

Nukumi2::Entry::DEFAULT_ENCODING.replace 'DeplateString'

o = DeplateString.deplate_options
o.variables['levelshift']   = '4'
o.variables['headings']     = 'plain'
o.variables['auxiliaryDir'] = 'data'
o.variables['mandatoryID']  = true

class FileBackend
    class Parser
        def self.parse(io)
            entry = Nukumi2::Entry.new

            metadata = []

            while line = io.gets
                break if line.chomp.empty?
                metadata << line
            end

            meta = DeplateString.new(metadata.join)
            meta.to_html
        
            date = meta.deplate_converter.get_clip('date')
            entry.time = Time.parse(date.elt) if date

            subject = meta.deplate_converter.get_clip('title')
            entry.title = subject.elt if subject

            meta.deplate_variables.each do |field, value|
                if value
                    case field
                    when 'keywords'
                        entry.categories.concat Deplate::Core.split_list(value, ';', ',')
                    when 'encoding'
                    else
                        if entry.respond_to? field + "="
                            entry.send field + "=", value
                        else
                            entry.fields[field] = value
                        end
                    end
                end
            end

            entry.content = io.read

            entry
        end
    end
end

