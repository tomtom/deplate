# encoding: ASCII
# code-gvim.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     26-Feb-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.110
# 
# = Description
# This module provides a specialized syntax highlighter using gvim. Adds 
# Deplate::Regions::Code#gvim_to_html.
# 
# = Usage
# = TODO
# = CHANGES

require 'fileutils'
require 'tmpdir'

class Deplate::Regions::Code
    add_highlighter(nil, 'html',         :gvim_to_html)
    add_highlighter(nil, 'htmlslides',   :gvim_to_html)
    add_highlighter(nil, 'htmlsite',     :gvim_to_html)
    add_highlighter(nil, 'html-snippet', :gvim_to_html)
    add_highlighter(nil, 'xhtml10t',     :gvim_to_html)
    add_highlighter(nil, 'xhtml11m',     :gvim_to_html)
    add_highlighter(nil, 'php',          :gvim_to_html)
    add_highlighter(nil, 'phpsite',      :gvim_to_html)
    
    def gvim_to_html(syntax, style, text)
        unless @deplate.allow_external
            return
        end
        gvim = %{#{Deplate::External.get_app('gvim')} -f +"syn on" +"let use_xhtml = 1" +"set ft=#{syntax}" +"colorscheme #{style || "default"}" +"run! syntax/2html.vim" +"wq" +"q" deplateGvim}
        # p "DBG #{gvim}"
        @deplate.in_working_dir(Dir.tmpdir) do
            FileUtils.rm("deplateGvim.html") if File.exist?("deplateGvim.html")
            Deplate::External.write_file(self, "deplateGvim") {|io| io.puts(text)}
            IO.popen(gvim) {|io| puts io.gets until io.eof }
            if File.exist?("deplateGvim.html")
                rv = [%{<div class="code">}]
                File.open("deplateGvim.html") do |io|
                    until io.eof?
                        line = io.gets
                        line.chomp!
                        if line =~ /^<pre>$/ .. line =~ /^<\/pre\>$/
                            line.gsub!(/<font (\w+)="(.+?)">(.*?)<\/font>/,
                                       '<span style="\\1: \\2;">\\3</span>')
                            rv << line
                        end
                    end
                end
                rv << %{</div>}
                # return rv.join("\n")
                return rv
            else
                log("Error when running gvim", :error)
            end
        end
        return nil
    end
end

