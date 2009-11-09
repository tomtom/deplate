# encoding: ASCII
# anyword.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Sep-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.99

class Deplate::Core
    def module_initialize_anyword
        list = @variables["anyword_list"]
        acc  = list ? Deplate::Core.split_list(list, ',', ';') : []

        cat  = @variables["anyword_catalog"]
        if cat
            acc += File.open(cat) do |io|
                io.readlines.collect {|l| l.chomp}
            end
        end

        suffix  = @variables["anyword_suffix"] || ""

        pattern = @variables["anyword_pattern"]
        if pattern
            acc += Dir[pattern].collect {|f| File.basename(f, suffix)}
        end

        unless list or cat or pattern
            files = @options.files.collect do |src|
                Dir[File.join(File.dirname(src), "*" + suffix)]
            end
            acc += files.flatten.collect {|f| File.basename(f, suffix)}
        end
        
        rx  = acc.collect {|n| "(?i:\\b%s\\b)" % Regexp.escape(n)}.join("|")
        body = <<-EOR
            set_rx(/^#{rx}/)
            def setup_element
                @inter   = nil
                @literal = nil
                @anchor  = ""
                @dest    = @match[0]
                @name    = @dest
                idx      = [@deplate.add_index(self, @name)]
                @idx     = indexing(idx)
            end
            def process
                @name = @deplate.formatter.plain_text(Deplate::Core.remove_backslashes(@name))
                @elt = [@name, @dest, @anchor]
                super
            end
        EOR
        cls = Deplate::Cache.particle(deplate, body, :register => true)
    end
end

