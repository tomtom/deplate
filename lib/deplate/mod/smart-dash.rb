# encoding: ASCII
# smart-dash.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     15-Apr-2006.
# @Last Change: 2009-11-09.
# @Revision:    0.28

class Deplate::Particle::Symbol
    @@symbols_table.delete(['--'])
    @@symbols_table << ['`--', '--']
    @@symbols_table << ['-', lambda do
        chars = Deplate::HyperLink.chars
        text  = if @last =~ /\d$/ or
                    @rest =~ /^\d/ or
                    (@last =~ /[#{chars}]$/ and @rest =~ /^[#{chars}]/)
                    '-'
                else
                    format_particle(:format_symbol, self, '--')
                end
        text
    end
    ]

    reset_symbols
end

