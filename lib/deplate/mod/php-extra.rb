# encoding: ASCII
# php-extra.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     05-Mai-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.31
#
# = Description
# Provide some php specific elements/particles/macros ...

class Deplate::Formatter::HTML
    def initialize_page_comments(invoker)
        unless @deplate.options.page_comments
            file = 'page-comment.inc.php'
            fn   = @deplate.find_in_lib(file, :pwd => true)
            dir  = File.dirname(output_destination)
            dest = File.join(dir, file)
            unless File.exist?(dest)
                Deplate::Template.copy(@deplate, fn, dest, invoker) do |args|
                    unless @variables['commentLocale']
                        args['commentLocale'] = @deplate.options.messages.prop('lang', 'php')
                    end
                end
                # tpl = File.open(fn) {|io| io.read}
                # src = invoker ? invoker.source : nil
                # tpl = Deplate::Template.new(:template  => tpl,
                #                             :source => src,
                #                             :container => self)
                # args = {}
                # unless @variables['commentLocale']
                #     args['commentLocale'] = @deplate.options.messages.prop('lang', 'php')
                # end
                # Deplate::Define.let_variables(@deplate, args) do
                #     tpl = tpl.fill_in(@deplate, :source => src)
                # end
                # tpl = tpl.join("\n")
                # File.open(dest, 'w') {|io| io.puts(tpl)}
            end
            # @deplate.copy_file(fn, dest)
            @deplate.options.page_comments = true
        end
    end

    def_service('page_comment') do |args, text|
        initialize_page_comments(args[:invoker])
        pc = invoke_service('outputBasename', 'sfx' => '.*').inspect
        %{<?php require_once('page-comment.inc.php'); page_comment(#{pc}); ?>}
    end
end

class Deplate::Regions::Php < Deplate::Regions::Native
    register_as 'Php'
    def process
        @elt = ['<?php', @elt, '?>'].join("\n")
        self
    end
end

class Deplate::Command::PHP < Deplate::Command
    register_as 'PHP'
    def format_special
        ['<?php', @elt, '?>'].join(' ')
    end
end

class Deplate::Macro::Php < Deplate::Macro::Insert
    register_as 'php'

    def setup(text)
        super
        @text = ['<?php', @text, '?>'].join(' ')
    end
end

class Deplate::Macro::PhpValue < Deplate::Macro::Insert
    register_as '='

    def setup(text)
        super
        @text = ['<?php print_r (', @text, ' ); ?>'].join(' ')
    end
end

