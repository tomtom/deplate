# encoding: ASCII
# core.rb -- Convert wiki-like plain text pseudo markup to something else
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     24-Feb-2004.
# @Last Change: 2010-09-20.

require 'uri'
require 'optparse'
require 'ostruct'
require 'rbconfig'
# require 'ftools'
require 'fileutils'
require 'forwardable'
require 'pathname'

module Deplate; end

# Deplate::Core is responsible for managing the conversion process.
# Deplate::Core.deplate parses command line arguments, creates a 
# preconfigured instance of Deplate::Core and initiates the conversion 
# process.
#
# If you want to use deplate as a library, you should probably use the 
# Deplate::Converter convenience class.

class Deplate::Core
    extend Forwardable

    Version    = '0.8.5'
    # VersionSfx = 'a'
    VersionSfx = 'final'
    MicroRev   = '3177'

    if ENV['HOME']
        CfgDir = File.join(ENV['HOME'].gsub(/\\/, '/'), '.deplate')
    elsif ENV['USERPROFILE']
        CfgDir = File.join(ENV['USERPROFILE'].gsub(/\\/, '/'), 'deplate.rc')
    else
        if ENV['WINDIR']
            CfgDir = File.join(File.dirname(ENV['WINDIR'].gsub(/\\/, '/')) ,'deplate.rc')
        else
            CfgDir = '/etc/deplate.rc'
        end
        # CfgDir = File.join(Dir.pwd.gsub(/\\/, '/'), 'deplate.rc')
        puts <<MESSAGE
Cannot find your personal configuration directory. Neither HOME nor 
USERPROFILE is set. I will look for configuration files in:
    #{CfgDir}
MESSAGE
    end
    LibDir     = File.dirname(__FILE__)
    DataDir    = File.join(Config::CONFIG['datadir'], 'deplate')
    EtcDirs    = []
    # FileCache  = File.join(CfgDir, 'file_list.dat')
    FileCache  = nil

    # If true, don't load user configuration files.
    @vanilla  = false
    @@vanilla = false
    
    # see #log_valid_condition?
    @log_treshhold = 4
    # see #log_valid_condition?
    @log_events    = [:unknown_macro, :newbie]

    # shut up
    @@quiet        = false
    # color output
    @@colored_output = false

    # A hash of known modules and their ruby require filenames
    @@modules    = {}
    # A hash of known formatters and their ruby require filenames
    @@formatters = {}
    # A hash of known css files and their ruby file names
    @@css        = {}
    # A hash of known templates and their ruby file names

    @@templates  = {}
    # A hash of known encodings and the corresponding module
    @@symbols    = {}
    # A hash of known input definitions and their ruby require filenames
    @@input_defs = {}
    # A hash of known metadata formatters and their ruby require filenames
    @@metadata_formats = {}

    # This variable (array of strings) can contain some deplate markup that will 
    # be prepended to every file read
    @@deplate_template     = []

    # A hash of {lang => message class}.
    @@messages = {}
    # The class of the message catalog that was loaded last
    @@messages_last  = nil
    # An instance of Deplate::Messages that is used for translating 
    # messages.
    @@message_object = nil
    
    # The values for slot names are currently pre-defined in this hash. In the 
    # future they will be calculated dynamically as required.
    # <+TBD+>This will be subject of change.
    @@slot_names = {
        #pre matter
        :prematter_begin => 0,
        :doc_def         => 5,
        :doc_beg         => 8,
        :head_beg        => 10,
        :fmt_packages    => 13,
        :mod_packages    => 15,
        :user_packages   => 20,
        :head            => 30,
        :head_meta       => 31,
        :meta            => 31,
        :head_identifier => 32,
        :head_title      => 33,
        :head_extra      => 34,
        :user_head       => 35,
        :mod_head        => 40,
        :user_head       => 50,
        :htmlsite_prev   => 55,
        :htmlsite_up     => 56,
        :htmlsite_next   => 57,
        # Synonyms for the above 3
        :htmlslides_prev => 55,
        :htmlslides_up   => 56,
        :htmlslides_next => 57,
        :html_relations  => 58,
        :css             => 60,
        :styles          => 65,
        :javascript      => 70,
        :head_end        => 80,
        :body_beg        => 90,
        :header          => 95,
        :prematter_end   => 100,
        :body_pre        => 105,

        #body
        :inner_body_begin => 0,
        :navbar_js       => 4,
        :navbar_top      => 5,
        :body_title      => 20,
        :body            => 50,
        :footnotes       => 75,
        :navbar_bottom   => 95,
        :inner_body_end  => 100,
        
        #post matter
        :body_post           => 0,
        :postmatter_begin    => 1,
        :footer              => 5,
        :html_pageicons_beg  => 10,
        :html_pageicons      => 11,
        :html_pageicons_end  => 12,
        :pre_body_end    => 15,
        :body_end        => 20,
        :doc_end         => 50,
        :postmatter_end  => 100,
    }

    # A hash of formatter names and corresponding classes
    @@formatter_classes = {}

    @@bib_style         = {}

    # A hash of names of input formats and corresponding classes
    @@input_classes     = {}

    # The IO where to display messages.
    @@log_destination   = $stderr

    class << self
        # Do what has to be done. This is the method that gets called when 
        # invoking deplate from the command line. It checks the command line 
        # arguments, sets up a Deplate::Core object, and makes it convert the 
        # input files.
        def deplate(args=ARGV)
            log(['Configuration directory', CfgDir], :debug)
            if ENV['DeplateOptions']
                for keyval in Deplate::Core.split_list(ENV['DeplateOptions'], ';')
                    key, val = keyval.split(/\s*=\s*/)
                    case key
                    when 'vanilla'
                        @@vanilla = @vanilla = true
                    end
                end
            end
            modules, formatters, themes, csss, templates, input_defs, meta_fmts = collect_standard
            
            options = deplate_options
            opts    = OptionParser.new do |opts|
                opts.banner =  'Usage: deplate.rb [OPTIONS] FILE [OTHER FILES ...]'
                opts.separator ''
                opts.separator 'deplate is a free software with ABSOLUTELY NO WARRANTY under'
                opts.separator 'the terms of the GNU General Public License version 2.'
                opts.separator ''

                opts.separator 'General Options:'
                
                opts.on('-a', '--[no-]ask', 
                        'On certain actions, query user before overwriting files') do |bool|
                    log("options.ask_user = #{bool}")
                    options.ask_user = bool
                end

                opts.on('-A', '--allow ALLOW', 
                        'Allow certain things: l, r, t, w, W, x, X, $') do |string|
                    allow(options.allow, string, '[COMMAND LINE ARGUMENT]')
                    log("options.allow = #{string}")
                end
            
                opts.on('-c', '--config FILE', String, 
                        'Alternative user cfg file') do |file|
                    log("options.cfg = #{file}")
                    options.cfg = [file]
                end

                opts.on('--[no-]clean', 'Clean up temporary files') do |b|
                    log("options.clean = #{b}")
                    options.clean = b
                end

                opts.on('--color', 'Colored output') do |b|
                    log("options.color = #{b}")
                    enable_color(options)
                end

                opts.on('--css NAME', csss, 
                        'Copy NAME.css to the destination directory, if inexistent') do |file|
                    log("options.css = #{file}")
                    options.css << [file]
                end

                opts.on('--copy-css NAME', csss, 
                        'Copy NAME.css to the destination directory') do |file|
                    log("options.css = #{file}")
                    options.css << [file, true]
                end

                opts.on('-d', '--dir DIR', String, 'Output directory') do |dir|
                    log("options.dir = #{dir}")
                    ensure_dir_exists(dir, options)
                    options.dir = dir
                    # if dir.kind_of?(String) and File.directory?(dir)
                    #     options.dir = dir
                    # else
                    #     log(["Directory doesn't exist", dir], :error)
                    # end
                end

                opts.on('-D', '--define NAME=VALUE', String,
                        'Define a document option') do |text|
                    m = /^(\w+?)(=(.*))?$/.match(text)
                    if m
                        k = m[1]
                        v = m[3]
                        log(%{options.variables[#{k}] = "#{v}"})
                        canonic_args(options.variables, k, v)
                    else
                        log(["Malformed variable definition on command line", text], :error)
                    end
                end

                opts.on('-e', '--[no-]each', 'Handle each file separately') do |bool|
                    log("options.each = #{bool}")
                    options.each = bool
                end

                opts.on('--[no-]force', 'Force output') do |bool|
                    log("options.force = #{bool}")
                    options.force = bool
                end
                
                opts.on('-f', '--format FORMAT', String,
                        'Output format (default: html)') do |fmt|
                    log("options.fmt = #{fmt}")
                    if formatters.include?(fmt)
                        options.fmt = fmt
                    else
                        log(["Unknown formatter", fmt, formatters], :error)
                        exit 5
                    end
                end

                opts.on('--[no-]included', 'Output body only') do |bool|
                    log("options.included = #{bool}")
                    options.included = bool
                end

                opts.on('-i', '--input NAME', String, 'Input definition') do |str|
                    log("options.input_def = #{str}")
                    options.input_def = str
                end

                opts.on('--list FILE', String, 
                        'A file that contains a list of input files') do |file|
                    log("options.list = #{file}")
                    options.list = file
                end

                opts.on('--log FILE', String, 
                        'A file (or - for stdout) where to put the log') do |file|
                    case file
                    when '-'
                        file = $stdout
                    else
                        file = File.expand_path(file)
                    end
                    log("options.log = #{file}")
                    @@log_destination = file
                end

                opts.on('--[no-]loop', 'Read from stdin forever and ever') do |bool|
                    log("options.loop = #{bool}")
                    options.loop = bool
                end
                
                opts.on('--metadata [NAME]', meta_fmts, 
                        'Save metadata in this format (default: yaml)') do |str|
                    str ||= 'yaml'
                    log("options.metadata_model = #{str}")
                    unstopable_require(@@metadata_formats[str])
                end

                opts.on('-m', '--module MODULE', modules, 'Load a module') do |str|
                    log("options.modules << #{str}")
                    options.modules << str
                end

                opts.on('-o', '--out FILE', String, "Output to file or stdout ('-')") do |file|
                    log("options.out = #{file}")
                    d, f = File.split(file)
                    if d != '.'
                        options.dir = d
                    end
                    options.out         = f
                    options.explicitOut = true
                end
                
                opts.on('-p', '--pattern GLOBPATTERN', String, 'File name pattern') do |str|
                    log("options.file_pattern = #{remove_backslashes(str)}")
                    options.file_pattern = remove_backslashes(str)
                end
                
                opts.on('-P', '--exclude GLOBPATTERN', String, 
                        'Excluded file name pattern') do |str|
                    log("options.file_excl_pattern = #{remove_backslashes(str)}")
                    options.file_excl_pattern = remove_backslashes(str)
                end
                
                opts.on('-r', '--[no-]recurse', 'Recurse into directories') do |bool|
                    log("options.recurse = #{bool}")
                    options.recurse = bool
                end

                opts.on('--reset-filecache', 'Reset the file database') do |bool|
                    log("options.reset_filecache = #{bool}")
                    if File.exist?(FileCache)
                        File.delete(FileCache) 
                        log("Deleting file database. Files will be re-scanned on next run.", :anyway)
                    end
                    exit 0
                end

                opts.on('-R', '--[no-]Recurse', 'Recurse and rebuild hierarchy') do |bool|
                    log("options.recurse_hierarchy = #{bool}")
                    options.recurse = bool
                    options.recurse_hierarchy = bool
                end

                opts.on('-s', '--skeleton NAME', String, 'Make skeleton available') do |str|
                    log("options.skeletons << #{str}")
                    options.skeletons << str
                end
                
                opts.on('--[no-]simple-names', 'Disable simple wiki names') do |bool|
                    unless bool
                        options.disabled_particles << Deplate::HyperLink::Simple
                    end
                end
                
                opts.on('--split-level LEVEL', Integer, 'Heading level for splitting') do |i|
                    log("options.split_level = #{i}")
                    options.split_level = i
                end
                
                opts.on('--suffix SUFFIX', String, 'Suffix for output files') do |str|
                    log("options.suffix = #{str}")
                    options.suffix = str
                end
                
                opts.on('-t', '--template NAME', String, 'Template to use') do |str|
                    if @@templates.has_key?(str) or File.exist?(str)
                        log("options.template = #{@@templates[str]}")
                        options.template = str
                    else
                        log(['Template not found', str], :error)
                        exit 5
                    end
                end
               
                opts.on('--theme THEME', String, 'Theme to use') do |value|
                    set_theme(options, value)
                end

                opts.on('--[no-]vanilla', 'Ignore user configuration') do |bool|
                    log("options.vanilla = #{bool}")
                    @@vanilla = bool
                end

                opts.on('-x', '--allow-ruby [RUBY SAFE]', Integer,
                        'Allow the execution of ruby code') do |level|
                    if level
                        options.allow_ruby = level
                        allow(options.allow, level, '[COMMAND LINE ARGUMENT]')
                    else
                        options.allow_ruby = true
                        allow(options.allow, 'x')
                    end
                    log("options.allow_ruby = #{options.allow_ruby}")
                end
                
                opts.on('-X', '--[no-]allow-exec', '--[no-]external',
                        'Allow the execution of helper applications') do |bool|
                    options.allow_external = bool
                    allow(options.allow, 'X', '[COMMAND LINE ARGUMENT]')
                    log("options.allow_external = #{bool}")
                end
            
                opts.separator ' '
                opts.separator 'LaTeX Formatter:'

                opts.on('--[no-]pdf', 'Prepare for use with pdf(la)tex') do |bool|
                    log("options.pdftex = #{bool}")
                    options.pdftex = bool
                    options.variables['pdfOutput'] = true
                end

                opts.separator ' '
                opts.separator 'Available input defintions:'
                opts.separator input_defs.join(', ')
                
                opts.separator ' '
                opts.separator 'Available formatters:'
                opts.separator formatters.join(', ')
                
                opts.separator ' '
                opts.separator 'Available metadata formats:'
                opts.separator meta_fmts.join(', ')

                opts.separator ' '
                opts.separator 'Available modules:'
                opts.separator modules.join(', ')

                if themes
                    opts.separator ' '
                    opts.separator 'Available themes:'
                    opts.separator themes.join(', ')
                end

                opts.separator ' '
                opts.separator 'Available css files:'
                opts.separator csss.join(', ')

                opts.separator ' '
                opts.separator 'Available templates:'
                opts.separator templates.join(', ')

                opts.separator ' '
                opts.separator 'Other Options:'

                opts.on('--debug [LEVEL]', Integer, 'Show debug messages') do |v|
                    if v
                        @log_treshhold = v
                    end
                    $DEBUG = TRUE
                    $VERBOSE = TRUE
                end

                opts.on('--[no-]profile', 'Profile execution') do |b|
                    log("profile = #{b}")
                    # require "profile" if b
                end
                
                opts.on('--[no-]quiet', 'Be quiet') do |bool|
                    log("quiet = #{bool}")
                    @@quiet = bool
                end

                opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
                    log("verbose = #{v}")
                    $VERBOSE = v
                end

                opts.on_tail('-h', '--help', 'Show this message') do
                    puts opts
                    exit 1
                end

                opts.on_tail('--list-modules [REGEXP]', Regexp,
                             'List modules matching a pattern') do |rx|
                    m = rx.nil? ? modules : modules.find_all {|n| n =~ rx}
                    puts m.join("\n")
                    exit 1
                end

                opts.on_tail('--list-css [REGEXP]', Regexp,
                             'List css files matching a pattern') do |rx|
                    m = rx.nil? ? csss : csss.find_all {|n| n =~ rx}
                    puts m.join("\n")
                    exit 1
                end

                opts.on_tail('--version', 'Show version') do
                    puts version
                    exit 0
                end
                
                opts.on_tail('--microversion', 'Show version') do
                    puts microversion
                    exit 0
                end
            end
            options.opts = opts

            @@command_line_args = args.dup
            unless options.ini_command_line_arguments.empty?
                args += options.ini_command_line_arguments
                options.ini_command_line_arguments = []
            end
            options.files = opts.parse!(args)

            if options.list
                accum = []
                File.open(options.list) do |io|
                    io.each {|l| accum << l.chomp}
                end
                options.files = accum + options.files
            else
                if options.files.empty?
                    failhelp(opts, 'No input files given!')
                end
            end

            options.fmt ||= 'html'
            require_standard(options)

            formatter_class = @@formatter_classes[options.fmt]
            
            # if options.multi_file_output
            #     if !options.dir
            #         failhelp(opts, "Output to multiple files requires the --dir option!")
            #     elsif options.each
            #         failhelp(opts, "Cannot use --each and multi-file output at the same time!")
            #     end
            # end
            
            if formatter_class
                formatter_class.set_options_for_file(options, options.files[0])
                prc = Deplate::Core.new(options.fmt,
                                  :formatter => formatter_class, 
                                  :options => options, 
                                  :now => true)
            else
                log(["Unknown formatter", options.fmt], :error)
                exit 5
            end
        end

        # Load the formatter, all required modules, and the user configuration 
        # files.
        def require_standard(options)
            require_input(options)

            require_formatter(options)
            
            for m in options.modules
                require_module(options, m) if m
            end

            # require 'deplate/mod/en' if we haven't loaded any lang 
            # module yet.
            require_module(options, 'lang-en') unless @@messages_last

            # load general user config
            options.cfg ||= ['config.rb', CfgDir]
            unless @@vanilla
                user_config(options, *options.cfg)
                user_setup(options) if defined?(user_setup)
            end
        end

        # Set certain allow flags in array.
        def allow(arr, ids, source=nil)
            case ids
            when String
                ids = Deplate::Core.split_list(ids, ',', '; ', source)
                # ids = ids.scan(/[a-zA-Z.:]/)
            when Array
            else
                log(['Internal error', 'allow', ids], :error, source)
            end
            ids.each do |i|
                m = i[0..0]
                case m
                when '-'
                    arr.delete(i[1..-1])
                when '+'
                    arr << i[1..-1]
                else
                    arr << i
                end
            end
            arr
        end

        # Check whether a certain action is allowed
        def is_allowed?(options, ids, args={})
            arr = options.allow
            if arr.include?('all')
                return true
            end
            case ids
            when String
                ids = Deplate::Core.split_list(ids, ',', '; ')
            when Array
            else
                log(['Internal error', 'allow', ids], :error)
            end
            for i in ids
                if arr.include?(i)
                    return true
                end
            end
            logger = args[:logger]
            logger.log(['No permission', ids.join(', ')], :anyway) if logger
            return false
        end


        def set_theme(options, name)
            theme_dir = @@themes[name]
            if theme_dir
                EtcDirs.unshift(theme_dir)
                collect_theme(@@css, theme_dir, 'css', '.css')
                collect_theme(@@templates, theme_dir, 'templates', '')
                for resource in Dir[File.join(theme_dir, 'resources', '*')]
                    options.resources << [resource, false]
                end
                prelude = File.join(theme_dir, 'prelude.txt')
                if File.exist?(prelude)
                    options.prelude.concat(File.readlines(prelude).map {|l| l.chomp})
                end
                if is_allowed?(options, 's')
                    read_ini_file(options, File.join(theme_dir, 'theme.ini'))
                    unless options.ini_command_line_arguments.empty?
                        options.opts.parse!(options.ini_command_line_arguments)
                    end
                end
            else
                log(['Unknown theme', name], :error)
            end
        end

        
        # Read CfgDir/deplate.ini
        #
        # This file knows the following commands/entries
        # <tt>mod NAME</tt>::  Load module NAME
        # <tt>fmt NAME</tt>::  Set the default formatter
        # <tt>clip NAME=TEXT</tt>::  Set a clip
        # <tt>wiki NAME.SUFFIX BASEURL</tt>::  Define an interwiki
        # <tt>wikichars UPPER LOWER</tt>::  Define the set of allowed 
        #   character in wiki names
        # <tt>VAR=VALUE</tt>:: Set the variable VAR to VALUE
        # <tt>$ENV=VALUE</tt>:: Set the environment variable VAR to VALUE
        #
        # Lines beginning with one of ';#%' are considered comments.
        def read_ini(options)
            read_ini_file(options, File.join(CfgDir, 'deplate.ini'))
            read_ini_file(options, File.join(Dir.pwd, "deplate.rc", 'deplate.ini')) if is_allowed?(options, 'r')
        end

        def read_ini_file(options, inifile)
            if File.exist?(inifile)
                mode   = :normal
                acc    = []
                endm   = nil
                setter = nil
                File.open(inifile) do |io|
                    until io.eof?
                        line = io.gets
                        line.chomp!
                        case mode
                        when :normal
                            if line =~ /^\s*[;#%*]/
                                # comment
                                next
                            elsif line =~ /^(-\S+)(\s+(.*?)\s*)?$/
                                options.ini_command_line_arguments << $1
                                options.ini_command_line_arguments << $3 if $3
                            elsif line =~ /^\s*allow\s+(.+?)\s*$/
                                allow(options.allow, $1, Deplate::Source.new(inifile))
                            elsif line =~ /^\s*mod\s+(\S+)/
                                mod = $1
                                if mod[0..0] == '-'
                                    options.modules.delete(mod[1..-1])
                                else
                                    options.modules << $1
                                end
                            elsif line =~ /^\s*fmt\s+(\S+)/
                                options.fmt = $1
                            elsif line =~ /^\s*clip\s+([^\s=]+)\s*=\s*(.+)/
                                options.clips[$1] = $2
                            elsif line =~ /^\s*wiki ([A-Z]+)(\.\w+)?\s*=\s*(.+)/
                                Deplate::InterWiki.add($1, $3, $2)
                            elsif line =~ /^\s*wikichars\s*(\S+)\s*(\S+)/
                                Deplate::HyperLink.setup($1, $2)
                            elsif line =~ /^\s*encoding\s+(.+)/
                                options.variables['encoding'] = $1
                            elsif line =~ /^\s*app\s*([_\w]+)\s*=\s*(.+)/
                                Deplate::External.def_app $1, $2
                            elsif line =~ /^\s*(option\s+|:)([_\w]+)([!~]|\s*([?%])?=\s*(.+))/
                                case $3
                                when '!'
                                    val = true
                                when '~'
                                    val = false
                                else
                                    case $4
                                    when '?'
                                        case $5
                                        when 'true', 'yes', 'on'
                                            val = true
                                        when 'false', 'no', 'off'
                                            val = false
                                        else
                                            Deplate::Core.log(['Malformed configuration line', line], :error)
                                            next
                                        end
                                    when '%'
                                        val = $5.to_i
                                    else
                                        val = $5
                                    end
                                end
                            options.send("#$2=", val)
                            elsif line =~ /^\s*\$(\S+)\s*=\s*(.+)/
                                ENV[$1] = $2
                            elsif line =~ /^\s*(\S+)\s*=<<(.+)/
                                mode = :multiline
                                endm = $2
                                setter = lambda {|val| canonic_args(options.variables, $1, val)}
                            elsif line =~ /^\s*(\S+)\s*=\s*(.+)/
                                canonic_args(options.variables, $1, $2)
                            elsif !line.empty?
                                Deplate::Core.log(['Malformed configuration line', line], :error)
                            end
                        when :multiline
                            if line == endm
                                setter.call(acc)
                                acc  = []
                                mode = :normal
                            else
                                acc << line
                            end
                        else
                            raise "Invalid mode"
                        end
                    end
                end
            end
        end
       
        # Load the input definition if any.
        # options:: A OpenStruct as returned by Deplate::Core.deplate_options
        def require_input(options, input_name=nil)
            name = input_name || options.input_def
            rb   = @@input_defs[name]
            if rb
                require rb
            end
        end
        
        # Load the formatter named in options.fmt.
        # options:: A OpenStruct as returned by Deplate::Core.deplate_options
        def require_formatter(options, fmt=nil)
            fmt ||= options.fmt
            if @@formatter_classes[fmt]
                Deplate::Core.log(['Formatter already loaded', fmt])
            else
                Deplate::Core.log(['Require formatter', fmt])
                fmtf = @@formatters[fmt]
                require fmtf
            end
            for fmt in @@formatter_classes[fmt].formatter_family_members.reverse
                user_config(options, File.join('after', 'fmt', '%s.rb' % fmt), CfgDir)
                user_config(options, File.join('after', 'fmt', fmt), CfgDir)
            end
        end
            
        # Load a module.
        # options:: A OpenStruct as returned by Deplate::Core.deplate_options
        # module_name:: The name of the module to be loaded
        def require_module(options, module_name)
            Deplate::Core.log(['Require module', module_name])
            mf = @@modules[module_name]
            vsave, $VERBOSE = $VERBOSE, false
            begin
                require mf
                user_config(options, File.join('after', 'mod', '%s.rb' % module_name), CfgDir)
                user_config(options, File.join('after', 'mod', module_name), CfgDir)
                return true
            rescue Exception => e
                Deplate::Core.log(['Loading module failed', module_name, e], :error)
                Deplate::Core.log(['Known modules', @@modules], :debug)
                return false
            ensure
                $VERBOSE = vsave
            end
        end

        # require NAME but don't stop if an error occurs; takes an optional block as 
        # argument, which is called when the file was successfully loaded.
        # name:: A string passed on to +require+
        def unstopable_require(name)
            begin
                require name
                if block_given?
                    yield
                end
            rescue Exception => e
                log(["Require failed", name, e], :error)
            end
        end
        
        # Load the user configuration for a file/module.
        # options:: A OpenStruct as returned by Deplate::Core.deplate_options
        # file:: Either a file name or a directory; if it is a 
        #   directory, all ruby files in that directory will be loaded
        def user_config(options, file, dir=nil)
            unless @@vanilla
                if dir
                    dirs = [dir]
                    dirs << File.join(current_pwd, 'deplate.rc') if is_allowed?(options, 'r')
                    for f in dirs
                        load_user_config(options, File.join(f, file))
                    end
                else
                    load_user_config(options, file)
                end
            end
        end

        def load_user_config(options, file)
            if File.exist?(file)
                if File.stat(file).directory?
                    for f in Dir[File.join(file, '*.rb')]
                        user_config(options, f)
                    end
                else
                    Deplate::Core.log(["Loading", file])
                    load(file)
                end
            end
        end
       
        # Set up the standard options structure.
        # inherit:: A OpenStruct; if provided, reuse it
        def deplate_options(inherit=nil)
            options               = inherit || OpenStruct.new
            options.ini_command_line_arguments ||= []
            options.modules     ||= []
            options.headings    ||= []
            options.resources   ||= []
            options.prelude     ||= []
            options.clean       ||= true
            options.force       ||= true
            options.css         ||= []
            options.variables   ||= Deplate::Variables.new
            deplate_predefined_variables(options)
            options.clips       ||= {}
            options.ext         ||= ''
            # options.dir         ||= '.'
            options.allow       ||= []
            options.skeletons   ||= []
            options.split_level ||= 1
            options.disabled_particles ||= []
            options.autoindexed        ||= []
            options.abbrevs     ||= {}
            reset_listings_and_counters(options, true)
            read_ini(options) unless inherit
            return options
        end

        def deplate_predefined_variables(options)
            options.variables['env'] = ENV
        end

        def reset_listings_and_counters(options, conditionally=false)
            unless conditionally and options.counters
                c = options.counters = Deplate::Counters.new(self)
                c.def_counter('toc')
                c.def_counter('lot', :parent => 'toc:1')
                c.def_counter('lof', :parent => 'toc:1')
            end
            unless conditionally and options.listings
                l = options.listings = Deplate::Listings.new(self)
                l.def_listing('toc', nil,
                              'prefix' => 'hd',
                              'entity' => 'heading'
                             )
                l.def_listing('lot', nil,
                              'prefix'  => 'tab',
                              # 'counter' => :tables,
                              'entity'  => 'table'
                             )
                l.def_listing('lof', nil,
                              'prefix'  => 'fig',
                              # 'counter' => :figures,
                              'entity'  => 'figure'
                             )
            end
        end

        # Return the current version number as string.
        def version
            Deplate::Core::Version
        end

        # Return the current micorversion number as string.
        def microversion
            [
                Deplate::Core::Version, 
                Deplate::Core::VersionSfx,
                '-',
                Deplate::Core::MicroRev,
            ].join
        end

        # Enable colored log output
        # options:: A OpenStruct as returned by Deplate::Core.deplate_options
        def enable_color(options)
            unless @@colored_output
                unstopable_require('term/ansicolor') do
                    eval <<-EOR
                    class Deplate::Color
                        class << self
                            include Term::ANSIColor
                        end
                    end
                    EOR
                    @@colored_output = options.color = true
                end
            end
        end
        
        # Collect all available modules, formatters, css files, and templates.
        def collect_standard
            if FileCache and File.exist?(FileCache)
                File.open(FileCache) do |f|
                    data = Marshal.load(f)
                    if data['version'] == Deplate::Core.microversion
                        modules,    @@modules    = data['modules']
                        formatters, @@formatters = data['formatters']
                        themes,     @@themes     = data['themes']
                        csss,       @@css        = data['css']
                        templates,  @@templates  = data['templates']
                        input_defs, @@input_defs = data['input']
                        meta_fmts,  @@metadata_formats = data['metadata']
                        Deplate::Core.log(['Using file cache', FileCache])
                        return modules, formatters, csss, templates, input_defs, meta_fmts
                    else
                        Deplate::Core.log(['Old file cache', FileCache])
                    end
                end
            end
            modules,    @@modules    = collect_deplate_options('modules',   'mod')
            formatters, @@formatters = collect_deplate_options('formatters','fmt')
            input_defs, @@input_defs = collect_deplate_options('input',     'input')
            meta_fmts,  @@metadata_formats = collect_deplate_options('metadata', 'metadata')
            themes,     @@themes     = collect_deplate_options('themes', 'themes',
                                                              :directories => true,
                                                              :suffix => '',
                                                              :rc => true)
            csss,       @@css        = collect_deplate_options('css',       'css', 
                                                               :suffix => '.css',
                                                               :rc => true)
            templates,  @@templates  = collect_deplate_options('templates', 'templates',
                                                              :suffix => '',
                                                              :rc => true)
                
            if FileCache
                File.open(FileCache, 'w+') do |f|
                    data = {
                        'version'    => Deplate::Core.microversion,
                        'modules'    => [modules,    @@modules],
                        'formatters' => [formatters, @@formatters],
                        'themes'     => [themes,     @@themes],
                        'css'        => [csss,       @@css],
                        'templates'  => [templates,  @@templates],
                        'input'      => [input_defs, @@input_defs],
                        'metadata'   => [meta_fmts,  @@metadata_formats],
                    }
                    Marshal.dump(data, f)
                    Deplate::Core.log(['Create file cache', FileCache])
                end
            end
            return modules, formatters, themes, csss, templates, input_defs, meta_fmts
        end

        # This is the actual logging method. Every log message should pass 
        # through this method.
        def log(text, condition=nil, source=nil)
            if log_valid_condition?(condition)
                text = log_filter(text)
                if source
                    msg = log_build_message(text, condition, source.file, source.begin, source.end)
                else
                    msg = log_build_message(text, condition)
                end
                log_to(msg)
                log_to(caller.join("\n")) if $DEBUG and condition == :error
            end
        end

        def canonic_args(hash, key, val, source=nil)
            if key[-1..-1] == '!'
                key  = key[0..-2]
                type = :bool
            end
            if key =~ /^no[A-Z]/
                key  = key[2..2].downcase + key[3..-1]
                val  = false
                type = :bool
            elsif val.nil?
                type = :bool
                val  = true
            else
                case val
                when nil, 'true'
                    type = :bool
                    val  = true
                when 'false'
                    type = :bool
                    val  = false
                else
                    type = :string
                    if val =~ /^"(.*?)"$/
                        val = val[1..-2]
                    elsif val =~ /^\((.*?)\)$/
                        val = val[1..-2]
                    else
                        # val.scan(/\\\\|\s/).each do |s|
                        #     if s =~ /\s/
                        #         Deplate::Core.log(['Deprecated syntax', 
                        #             'Character should be preceded by a backslash', 
                        #             s.inspect, val],
                        #             :anyway, source)
                        #     end
                        # end
                        val = val.strip
                    end
                    val = Deplate::Core.remove_backslashes(val)
                end
            end
            case type
            when :bool
                if key =~ /^\$[^\[]+\[/
                    nokey = key.sub(/\[./) {|t| "[no#{t[1..1].upcase}"}
                    hash[nokey] = !val
                else
                    hash["no#{key[0..0].upcase}#{key[1..-1]}"] = !val
                end
            end
            hash[key] = val
            hash
        end

        def query_user(options, msg, results, rv=true)
            ok = if options and options.ask
                     puts msg
                     results.include?(gets.chomp)
                 else
                     true
                 end
            ok ? rv : !rv
        end
        
        # Remove all backslashes from +text+
        def remove_backslashes(text)
            return text.gsub(/\\(.)/, '\\1') if text
        end

        def split_list(string, chars=nil, deprecated=nil, source=nil, doubt=:use_deprecated)
            if string
                chars ||= ','
                list = string.scan(/((?:\\.|[^#{chars}\\]+)+)(?:[#{chars}]\s*|\Z)/).flatten
                list = list.map {|e| remove_backslashes(e)}
                if deprecated
                    list1 = split_list(string, deprecated)
                    if list1 != list and 
                        # (list1.size > 1 or list1[0] != string) and 
                        string !~ /[#{chars}]/ and string =~ /[#{deprecated}]/
                        # case doubt
                        # when :use_deprecated
                            Deplate::Core.log(['Assuming the use of deprecated list separators', deprecated.inspect, string.inspect], :error, source)
                            return list1
                        # else
                        #     Deplate::Core.log(['Possible use of deprecated list separators', deprecated.inspect, string.inspect], :anyway, source)
                        # end
                    end
                end
                return list
            else
                return []
            end
        end

        def push_value(var, value, sep=',')
            if var and !var.empty?
                [var, sep, value].join
            else
                value
            end
        end

        def escape_characters(text, args)
            esc = args[:esc] || args[:escape] || args['esc'] || args['escape'] || ''
            ebs = args[:escapebackslash] || args['escapebackslash'] || args['template'] || 0
            case ebs
            when true
                ebs = 1
            else
                ebs = ebs.to_i
            end
            if esc.include?('\\')
                esc = esc.delete('\\')
                ebs ||= 1
            end
            if ebs > 0
                text = text.gsub(/\\/, '\\\\' * ebs)
            end
            unless esc.empty?
                text = text.gsub(/([#{esc}])/, '\\\\\\1')
            end
            text
        end

        def authors_split(text)
            text.split(/\s+and\s+/) if text
        end

        # Clean +idx+'s (a instance of Deplate::IndexEntry) name from backslashes
        def get_index_name(idx)
            # return remove_backslashes(idx.name.split(/\s*\|\s*/)[0])
            return remove_backslashes(idx.name)
        end

        # Retrieve field information from a "property list" as used form, e.g., 
        # specifying column widths in tables
        def props(proplist, field)
            if proplist
                Deplate::Core.split_list(proplist, ',', ';').collect do |c|
                    rv = nil
                    for key, val in c.scan(/(\w+?)[:.](\S+)/)
                        if key == field
                            rv = val
                            break
                        end
                    end
                    rv
                end
            else
                []
            end
        end

        # Return the canonic file name for +name+. +maj+ and +min+ 
        # correspond to section numbers.
        def canonic_file_name(name, sfx, args={})
            maj  = args[:maj]
            min  = args[:min]
            dir  = args[:dir]
            raw  = args[:raw]
            name = File.basename(name, '.*')
            name = clean_filename(name) unless raw
            if !name or (maj and maj != 0)
                canonic_numbered_file_name(name, sfx, maj, min, dir)
            elsif min and min != 0
                # fn = "%s.%02d%s" % [name, min, sfx]
                canonic_numbered_file_name(name, sfx, 0, min, dir)
            else
                fn = name + (sfx || '')
                dir ? File.join(dir, fn) : fn
            end
        end

        def clean_filename(text, args={})
            args[:replacement] ||= '='
            return clean_name(text, args)
        end

        # Return an encoded name
        def clean_name(text, args={})
          if text
            chars  = args[:chars] || '[:cntrl:].+*:"?<>|&\\\/%'
            chars += replacement = args[:replacement] || '_'
            if (extrachars = args[:extra])
              chars += extrachars
            end
            text = text.gsub(/[#{chars}]/) do |text|
                case text
                when replacement
                    replacement * 2
                else
                    # replacement + "%02X" % text[0]
                    replacement + text.unpack('H2')[0].upcase
                end
            end
          end
        end

        # Make sure +dir+ exists
        def ensure_dir_exists(dir, options=nil)
            unless File.exist?(dir) or dir.empty? or dir == '.'
                if !options or 
                    options.force or 
                    Deplate::Core.query_user(options, 
                                             "Create directory '#{dir}' (y/N)? ", 
                                             'y')
                    parent = File.dirname(dir)
                    unless File.exist?(parent)
                        ensure_dir_exists(parent, options)
                    end
                    Deplate::Core.log(["Creating directory", dir])
                    Dir.mkdir(dir)
                else
                    log(["Directory doesn't exist", dir, Dir.pwd], :error)
                    exit 5
                end
            end
        end

        def ensure_suffix(name, suffix)
            ext = File.extname(name)
            if ext != suffix
                return name + suffix
            else
                return name
            end
        end

        # Return the output directory for +fname+
        def get_out_name_dir(fname, options)
            if options.recurse_hierarchy
                # dir = File.dirname(fname).split(Regexp.new(Regexp.escape(File::SEPARATOR)))[1..-1]
                # dir = File.dirname(fname).split(Regexp.new(Regexp.escape(File::SEPARATOR)))
                # return File.join(*dir)
                return File.dirname(fname)
            else
                return '.'
            end
        end

        # Purge *path and return it as sting
        def file_join(*path)
            path.compact!
            path.delete(".")
            path.delete("")
            File.join(*path)
        end

        # Get the canonic output filename for fname.
        # fname:: The input file name
        # suffix:: The suffix to use
        # options:: A OpenStruct as returned by Deplate::Core.deplate_options
        # maj:: The major section/page number
        # maj:: The minor section/page number
        def get_out_fullname(fname, suffix, options, args={})
            # File.join(options.dir, get_out_name(fname, suffix, options, args))
            file_join(options.dir, get_out_name(fname, suffix, options, args))
        end

        def get_out_name(fname, suffix, options, args={})
            path = []
            path << get_out_name_dir(fname, options)
            if suffix
                fn  = File.basename(fname, '.*')
                path << canonic_file_name(fn, suffix, args)
            else
                path << fname
            end
            file_join(*path)
        end

        def declare_symbols(name, klass)
            @@symbols[name] = klass
        end
        
        def declare_input_format(input_class, name=nil)
            @@input_classes[name || input_class.myname] = input_class
        end
        
        def declare_bibstyle(bib_class, style)
            @@bib_style[style] = bib_class
        end

        # Make a formatter class publically known.
        def declare_formatter(formatter_class, name=nil)
            @@formatter_classes[formatter_class.myname] = formatter_class
            name = (name || formatter_class.myname).gsub(/[^[:alnum:]_]/, '_')
            self.class_eval do
                define_method("to_#{name}") do |text, *args|
                    sourcename, _ = args
                    reset(true)
                    format_with_formatter(formatter_class, text, sourcename)
                end
            end
        end

        def collect_theme(hash, theme_dir, subdir, suffix)
            for f in Dir[File.join(theme_dir, subdir, "*#{suffix}")]
                name = File.basename(f, suffix)
                hash[name] = f
            end
        end

        # Collect all available modules/parts/libraries etc. Check the 
        # file system and the "builtin" modules (e.g., when using the 
        # win32 exerb distribution).
        def collect_deplate_options(id=nil, subdir='', args={})
            suffix = args[:suffix] || '.rb'
            use_rc = args[:rc] || false
            hash   = {}
            for d in library_directories(@@vanilla, use_rc, [subdir])
                collect_deplate_options_in_hash(hash, suffix, Dir[File.join(d, '*%s' % suffix)], nil, args)
            end

            builtin = "builtin_#{id}"
            if id and respond_to?(builtin)
                files = send(builtin)
                # files.collect! {|f| "#{f}.rb"}
                collect_deplate_options_in_hash(hash, suffix, files, File.join('deplate', subdir), args)
            end
           
            return hash.keys.sort, hash
        end

        # Return an array of directories that could contain deplate 
        # files.
        def library_directories(vanilla, use_rc, subdirs)
            @library_directories ||= {}
            acc = []
            dirs = [DataDir, LibDir]
            dirs.unshift(CfgDir) unless vanilla
            dirs.unshift(*EtcDirs)
            dirs.unshift(File.join(current_pwd, 'deplate.rc')) if use_rc
            for subdir in subdirs
                unless @library_directories[subdir]
                    ad = []
                    for dir in dirs
                        if dir
                            fd = File.join(dir, subdir)
                            if File.exist?(fd)
                                ad << fd
                            end
                        end
                    end
                    @library_directories[subdir] = ad
                end
                acc += @library_directories[subdir]
            end
            acc
        end
 
        def is_file?(fname)
            return !fname.empty? && File.exists?(fname) && !File.directory?(fname)
        end
                
        def current_pwd(deplate=nil)
            if deplate and deplate.current_source
                File.dirname(deplate.current_source)
            else
                Dir.pwd
            end
        end
        
        def quiet?
            @@quiet
        end
        
        private
        # Return the localized text.
        def msg(text)
            if @@message_object
                @@message_object.msg(text)
            else
                text
            end
        end

        # Return the proper numbered output filename for name.
        def canonic_numbered_file_name(name, sfx, maj=0, min=0, dir=nil)
            name = File.basename(name, '.*')
            if min == 0
                idx = '%05d' % maj
            else
                idx = '%05d_%02d' % [maj, min]
            end
            fn = [name, idx, sfx].join
            dir ? File.join(dir, fn) : fn
        end

        # Collect files in +array+ in +hash+.
        def collect_deplate_options_in_hash(hash, suffix, array, subdir=nil, args={})
            for m in array
                unless !subdir and !args[:directories] and File.directory?(m)
                    key = File.basename(m, suffix) || m
                    hash[key] ||= subdir ? File.join(subdir, m) : m
                    hash[key] ||= subdir ? File.join(subdir, m) : m
                end
            end
        end

        # Display text and exit.
        def failhelp(opts, text)
            puts text
            puts
            puts opts
            exit 5
        end

        # * If @@quiet is true, don't display any messages.
        # * If +condition+ is :anyway, :error, or +true+, display the 
        #   message.
        # * If +condition+ is :debug, display the message if $DEBUG is 
        #   set.
        # * If +condition+ is a numeric, display the message if +condition+ 
        #   is less or equal @log_treshhold
        # * If +condition+ is a symbol, display the message if @log_events 
        #   contains +condition+.
        def log_valid_condition?(condition)
            if @@quiet
                return false
            elsif condition
                case condition
                when :anyway, :error, true
                    return true
                when :debug
                    return $DEBUG
                when Numeric
                    return condition <= @log_treshhold
                when Symbol
                    return @log_events.include?(condition)
                end
            else
                return $VERBOSE
            end
        end
      
        # Convert text into a localized message.
        # text:: Either an array or a string.
        def log_filter(text)
            case text
            when Array
                m = []
                text.each_with_index do |t, i|
                    if i == 0
                        m << log_filter(t)
                    else
                        case t
                        when Array
                            m << t.join("\n")
                        else
                            m << t.to_s
                        end
                    end
                end
                if m.size > 1
                    return "#{m[0]}: #{m[1..-1].join(", ")}"
                else
                    return m[0]
                end
            when String, Symbol
                return msg(text)
            else
                raise msg(["Internal error: Bad log text", text])
            end
        end

        # Delegate building the log message to 
        # #log_build_colored_message or #log_build_monochrom_message 
        # depending on whether we use colored output (@@colored_output).
        def log_build_message(*args)
            if @@colored_output
                log_build_colored_message(*args)
            else
                log_build_monochrom_message(*args)
            end
        end
      
        # Build a non-colored log message.
        # text:: A string
        # condition:: A condition evaluated by #log_valid_condition?
        def log_build_monochrom_message(text, condition, file=nil, line_begin=nil, line_end=nil)
            msg = []
            if file
                msg << file
                msg << ':'
                if line_begin
                    msg << line_begin
                    msg << '-' << line_end if line_end and line_end != line_begin
                    msg << ':'
                end
            end
            msg << text
            return msg.join
        end

        # Build a colored log message.
        # text:: A string
        # condition:: A condition evaluated by #log_valid_condition?
        def log_build_colored_message(text, condition, file=nil, line_begin=nil, line_end=nil)
            msg = []
            if file
                msg << Deplate::Color.green << Deplate::Color.bold(file)
                msg << Deplate::Color.yellow << ':'
                if line_begin
                    msg << Deplate::Color.cyan
                    msg << line_begin
                    msg << '-' << line_end if line_end and line_end != line_begin
                    msg << Deplate::Color.yellow
                    msg << ':'
                end
                case condition
                when :error, :unknown_macro
                    msg << Deplate::Color.red
                else
                    msg << Deplate::Color.blue
                end
                msg << text
            else
                case condition
                when :error, :unknown_macro
                    msg << Deplate::Color.red
                else
                    msg << Deplate::Color.magenta
                end
                msg << text
            end
            msg << Deplate::Color.clear
            return msg.join
        end
       
        # Display text on io unless the @@quiet flag is set.
        def log_to(text, io=@@log_destination)
            unless @@quiet
                if io
                    case io
                    when String
                        File.open(io, 'a') {|io| io.puts text}
                    else
                        io.puts text
                    end
                else
                    $stderr.puts msg('No log destination given!')
                end
            end
        end
 
        # ???
        # def dispatch(src, object, method, modifier, *args)
        #     disp = '%s_%s' % [method, modifier]
        #     if object.methods.include?(disp)
        #         return object.send(disp, *args)
        #     else
        #         return nil
        #     end
        # end
    end

    # A open structure that holds this instance's options.
    attr_reader :options

    attr_reader :vanilla

    # The formatter this instance of deplate uses.
    attr_reader :formatter

    # A hash that holds the current document's variables.
    attr_accessor :variables
    
    # Other document specific variables.
    # A hash containing the footnotes (id => object)
    attr_accessor :footnotes
    # An array holding already consumed footnotes IDs.
    attr_accessor :footnotes_used
    # A running index.
    attr_accessor :footnote_last_idx
    
    # A hash (label => [IndexEntry]).
    attr_accessor :index
   
    # A hash (level_string => object); currently only used by the 
    # structured formatter.
    attr_accessor :headings

    # A hash (id => object)
    attr_accessor :clips

    # A hash (label => level_string). Use of this hash should be 
    # replaced with uses of @label_aliases<+TBD+>
    attr_accessor :labels
    # An array used to postpone labels until there is some regular 
    # output.
    attr_accessor :labels_floating
    # A hash (label => corresponding elements).
    attr_accessor :label_aliases
    
    # A hash (slot name => number).
    attr_reader   :slot_names
   
    # The current input filter.
    attr_reader   :input

    # The current output object (Deplate::Output).
    attr_reader   :output
    # An ordered array of output filenames.
    attr_accessor :output_filename
    # An ordered array of top level/page headings.
    attr_accessor :output_headings
    # An array of collected output objects (@output).
    attr_accessor :collected_output
    # The base output file.
    attr_accessor :dest
    # An array holding the elements after reading the input files.
    attr_accessor :accum_elements
    # An array of Proc objects that will be evaluated before processing 
    # any other elements.
    attr_accessor :preprocess
    # An array of Proc objects that will be evaluated after printing any 
    # other elements.
    attr_accessor :postponed_print

    attr_accessor :current_source, :current_source_stats

    # a stack with if/elseif status; skip input if the top-switch is true
    attr_accessor :switches


    # formatter_name:: A formatter name
    # args:: A hash
    def initialize(formatter_name='html', args={})
        @args         = args
        @slot_names   = @@slot_names.dup
        @options      = Deplate::Core.deplate_options(args[:options])
        @sources      = args[:sources] || @options.files
        @dest         = args[:dest]    || @options.out   || ''
        @vanilla      = @@vanilla || args[:vanilla] || false

        # set_safe
        
        reset(!args[:inherit_options])
        @output = Deplate::Output.new(self)
        # @output.destination = File.join(@options.dir, @dest)
        @output.destination = @dest
        
        call_methods_matching(self, /^deplate_initialize_/)

        formatter_class = args[:formatter] || @@formatter_classes[formatter_name]
        if formatter_class
            log('Initializing formatter')
            @formatter = formatter_class.new(self, args)
            call_methods_matching(self, /^formatter_initialize_/)
            call_methods_matching(@formatter, /^formatter_initialize_/)

            log('Initializing modules')
            call_methods_matching(self, /^module_initialize_/)

            log('Setting up text scanner')
            call_methods_matching(self, /^input_initialize_/)
            call_methods_matching(self, /^hook_pre_input_initialize_/)
            initialize_input(args)
            call_methods_matching(self, /^hook_post_input_initialize_/)

            log('Setting up formatter')
            call_methods_matching(@formatter, /^hook_pre_setup_/)
            @formatter.setup
            call_methods_matching(@formatter, /^hook_post_setup_/)

            log('User initialization')
            user_initialize if defined?(user_initialize)
            
            reset_output
            set_standard_clips

            if args[:now]
                log('Here we go ...')
                call_methods_matching(self, /^hook_pre_go_/)
                call_methods_matching(@formatter, /^hook_pre_go_/)
                go_now
                call_methods_matching(self, /^hook_post_go_/)
                call_methods_matching(@formatter, /^hook_post_go_/)
            end
        else
            log(['No or unknown formatter', formatter_name], :error)
        end
    end

    def_delegator(:@output, :pre_matter)
    def_delegator(:@output, :body)
    def_delegator(:@output, :post_matter)
    def_delegator(:@output, :destination)
    # def_delegator(:@output, :top_heading)
    def_delegator(:@output, :body_empty?)
    def_delegator(:@output, :add_at)
    
    def_delegator(:@input, :initialize_particles)
    def_delegator(:@input, :register_particle)
    def_delegator(:@input, :register_element)
    def_delegator(:@input, :register_region)
    def_delegator(:@input, :parse_with_particles)
    def_delegator(:@input, :parse_with_source)
    def_delegator(:@input, :parse)

    # (Re-)set @input
    # args:: A hash as passed to #initialize
    def initialize_input(args=@args)
        @input = args[:input] || @options.input
        unless @input
            # @options.input_class is only considered when defined on 
            # startup (i.e. on the command-line), which is why we check 
            # for :now
            input_class = args[:input_class] ||
                (args[:now] && @options.input_class) ||
                Deplate::Input
            @input = input_class.new(self, args)
        end
    end

    # Change the input format to +name+.
    # name:: The name of an input format.
    def push_input_format(name)
        unless name
            return false
        end
        ic = @@input_classes[name]
        unless ic
            self.class.require_input(@options, name)
            ic = @@input_classes[name]
        end
        if ic
            @input_formats << @input
            @input = ic.new(self, @args)
            return true
        else
            log(['Unknown input format', name, @@input_classes.keys], :error)
            return false
        end
    end
    
    # Restore the previously used input format. If a +name+ is given and 
    # the name matches the previous input format, do nothing.
    # name:: The name of an input format.
    def pop_input_format(name=nil)
        if @input_formats.empty?
            return false
        else
            if name and @input_formats.last.class.myname == name
                return false
            end
            @input = @input_formats.pop
            return true
        end
    end    

    def get_formatter_class(fmt)
        case fmt
        when String
            @@formatter_classes[fmt]
        else
            fmt
        end
    end

    # Define a new slot or reset the position of an already known slot.
    # <+TBD+>There is no information on whether the slot belongs to the 
    # prematter/postmatter/body.
    # key:: The name (string)
    # val:: The position (integer)
    def set_slot_name(key, val)
        slot_names[key] = val
    end

    # Return a slot position by its name.
    def slot_by_name(slot)
        if slot.kind_of?(Numeric)
            slotlist = slot_names.collect {|k,v| v == slot ? k : nil }.compact.join(", ")
            log(["Please refer to slots by their names", slot, slotlist], :error)
            log(caller[0..5].join("\n"), :error)
            slot
        elsif slot.is_a?(Symbol)
            slotstr = slot.to_s
            if slotstr =~ /^prepend_/
                modi = -1
                slot = slotstr[8..-1].to_sym
            else
                modi = 1
            end
            val = slot_names[slot]
            if val
                return val * modi
            else
                return nil
            end
        elsif slot.is_a?(String)
            pos = 0
            operator = "+"
            for i in slot.split(/([+-])/)
                case i
                when "-", "+"
                    operator = i
                else
                    j = slot_names[i.intern]
                    unless j
                        j = i.to_i
                    end
                    pos = pos.send(operator, j)
                end
            end
            pos
        end
    end

    # Call all of obj's methods matching rx
    def call_methods_matching(obj, rx, *args)
        unless @vanilla
            for m in matching_methods(obj, rx)
                obj.send(m, *args)
            end
        end
    end

    def matching_methods(obj, rx)
        obj.methods.find_all {|m| m =~ rx }
    end
    
    # Reset instance variables.
    # all:: reset really all variables (bool)
    def reset(all=false)
        @current_source   = nil
        @current_source_stats = nil
        @auto_numbered   = {}
       
        @variables = @options.variables.dup
        @variables.deplate = self

        @clips            = {}
        @index            = {}
        @index_last_idx   = 0
        @labels           = {}
        @label_aliases    = {}
        @labels_floating  = []
        @ids              = {}
        @preprocess       = []
        @postponed_print  = []

        @footnotes         = {}
        @footnote_last_idx = 0
        @footnotes_used    = []

        @headings          = {}

        @accum_elements    = []
        @switches          = []
        @metadata          = {}
        
        set_lang(@@messages_last)
        set_standard_clips

        if all
            @endmessages           = {}
            @allsources            = {}
            @input_formats         = []
            @options.citations     = []
            @options.bib           = []
            @options.dont_index    = []
            @options.author        = []
            @options.heading_names = []
            Deplate::Core.reset_listings_and_counters(@options)
        end
    end

    # Reset output-related variables.
    # inherit_null_output:: The new output obj inherits the settings from the 
    # initial/anonymous output class (bool)
    def reset_output(inherit_null_output=true)
        log('Reset output', :debug)
        @collected_output = []
        @output_filename  = []
        @output_headings  = []
        @output_maj_min   = [0, 0]
        @null_output      = @output.dup
        if @options.multi_file_output
            dest = @variables['docBasename'] || @dest
            dest &&= File.basename(dest)
            # Deplate::Core.canonic_file_name(dest, @options.suffix, 0, 0)
        else
            dest = nil
        end
        dest    = dest ? Deplate::Core.get_out_fullname(dest, nil, @options) : @dest
        heading = Deplate::NullTop.new(self, :destination => dest)
        @output_filename[0] = dest
        push_top_heading(heading)
        if inherit_null_output
            new_output(@null_output)
        else
            Deplate::Output.reset
            new_output(nil)
        end
    end

    # Set the localization object.
    # lang:: The new language (string)
    def set_lang(lang)
        if lang =~ /\.(\w+)$/
            @variables['encoding'] = $1
        # elsif @@messages.has_key?("#{lang}.#{@variables['encoding']}")
        #     lang = "#{lang}.#{@variables['encoding']}"
        end
        case lang
        when String
            msg_class = @@messages[lang]
        else
            msg_class = lang
        end
        begin
            if msg_class
                @options.messages  = msg_class.new(self)
                @@message_object ||= @options.messages
            elsif is_allowed?('l') and require_module("lang-#{lang}")
                set_lang(lang)
            else
                log(["Bad language definition", lang, "(#{@@messages.keys.join(', ')})"],
                    :error)
            end
        rescue LoadError => e
            log(["Unknown language", lang, "(#{@@messages.keys.join(', ')})",
                'Please consider contributing a message catalog for your language'],
                    :error)
        end
    end

    # See Deplate::Core.log
    def log(*args)
        self.class.log(*args)
    end

    # Register a new message to be displayed after processing the 
    # current document.
    def endmessage(id, message)
        @endmessages[id] = message
    end
    
    # Print messages after having printed the current document.
    def print_endmessages
        @endmessages.each do |id, message|
            log([message], :anyway)
        end
        @endmessages = {}
    end

    # See Deplate::Core.require_module.
    def require_module(m)
        Deplate::Core.require_module(@options, m)
    end

    # Do something at last.
    def go_now
        if @options.each
            go_each
        elsif @options.loop
            loop do
                go
                reset(true)
                reset_output(false)
            end
        else
            @sources.uniq!
            go
        end
    end
   
    # Process each in sources.
    def go_each(sources=@sources)
        rv = nil
        begin
            saved_sources = @sources
            for f in sources
                if File.stat(f).file?
                    if to_be_included?(f)
                        @sources = [f]
                        @dest    = Deplate::Core.get_out_fullname(f, @options.suffix, @options)
                        reset(true)
                        reset_output(false)
                        if block_given?
                            yield
                        else
                            rv = go
                        end
                    end
                elsif @options.recurse
                    go_each(get_dir_listing(f))
                else
                    log(["Is no file", f], :error)
                end
            end
        ensure
            @sources = saved_sources
        end
        rv
    end
   
    # Read input file, process, write the output if writeFile is true.
    def go(writeFile=true)
        process_prelude
        read_file
        process_document
        if writeFile
            body_write
            copy_resources
        end
        print_endmessages
    end

    # Should the file be included or not, e.g., because of a -P 
    # command line option
    def to_be_included?(file)
        rv = get_dir_listing(File.dirname(file))
        rv = rv.include?(file)
        if rv
            log(["Should be included", file])
        else
            log(["Should be excluded", file])
        end
        return rv
    end

    # Evaluate block in the working directory; take care 
    # of the auxiliaryDirSuffix variable
    def in_working_dir(cwd=nil, &block)
        pwd = Dir.pwd
        cwd = auxiliary_dirname(true, true) if cwd.nil?
        if cwd.empty? or cwd == false or pwd == cwd
            block.call
        else
            log(['CHDIR ->', cwd], :debug)
            Dir.chdir(cwd)
            begin
                block.call
            ensure
                log(['CHDIR <-', pwd], :debug)
                Dir.chdir(pwd)
            end
        end
    end

    # Get the name for automatically generated auxiliary files (e.g., 
    # when no ID was provided)
    def auxiliary_auto_filename(type, idx, body=nil, suffix=nil)
        if @variables['mandatoryID']
            raise msg('No ID given')
        else
            prefix = @variables['prefixID']
            if prefix.nil?
                prefix = Deplate::Core.clean_filename(File.basename(@dest, '.*'))
            end
            fn = [prefix]
            fn << ["_#{type}_#{idx}"]
            fn << '.' << suffix if suffix
            return fn.join
        end
    end
    
    # Get the proper filename for an auxiliary file, respecting 
    # the value of auxiliaryDirSuffix
    def auxiliary_filename(filename, full_name=false)
        sd = auxiliary_dirname(full_name)
        if sd
            return Deplate::Core.file_join(sd, filename)
        else
            return filename
        end
    end
   
    # Get the dir for auxiliary files; take care of the 
    # auxiliaryDirSuffix variable
    # - If auxiliaryDirSuffix isn't defined, return default if non-nil.
    # - Create dir if ensure_dir_exists is true.
    def auxiliary_dirname(full_name=false, ensure_dir_exists=false)
        path  = []
        path  << File.dirname(@dest) if full_name
        aux   = @variables['auxiliaryDir']
        if aux
            path << aux
        else
            sdsfx = @variables['auxiliaryDirSuffix']
            path  << File.basename(@dest, '.*') + sdsfx if sdsfx
        end
        rv = Deplate::Core.file_join(*path)
        ensure_dir_exists(rv) if ensure_dir_exists
        rv
    end

    # Get a directory listing while respecting the -p and -P command line options
    def get_dir_listing(dir)
        pwd = Dir.pwd
        begin
            Dir.chdir(dir)
            files = Dir['*']
            match = Dir[@options.file_pattern || '*']
            files.delete_if {|f| File.stat(f).file? and !match.include?(f)}
            if @options.file_excl_pattern
                antilist = Dir[@options.file_excl_pattern]
                for anti in antilist
                    files.delete(anti)
                end
            end
            log(['DIR', dir])
        ensure
            Dir.chdir(pwd)
        end
        unless dir == '.'
            files.collect! {|f| File.join(dir, f)}
        end
        return files
    end
   
    def find_in_lib(fname, args={})
        if args[:pwd]
            fn = File.join(Deplate::Core.current_pwd(self), fname)
            if Deplate::Core.is_file?(fn)
                log(['File in CWD', fn])
                return fn
            end
        end
        files = []
        if @formatter
            @formatter.class.formatter_family_members(:names => args[:formatters]) do |myname|
                dd = File.join('lib', myname, fname)
                files << dd unless files.include?(dd)
            end
        end
        files << File.join(args['subdir'] || 'lib', fname)
        files = Deplate::Core.library_directories(@vanilla, true, files)
        for fn in files
            if Deplate::Core.is_file?(fn)
                log(['File in lib', fn])
                return fn
            end
        end
        return nil
    end

    # def formatter_family_members(args)
    #     (args[:formatter_class] || @formatter.class).formatter_family_members(args)
    # end
    
    # Format either text or, if text is nil, the file "sourcename".  
    # This is the method called by the Deplate::Formatter's 
    # to_whatsoever methods.
    def format_with_formatter(formatter_class, text, sourcename=nil)
        if text
            format_string_with_formatter(formatter_class, text, sourcename)
        elsif sourcename
            format_file_with_formatter(formatter_class, sourcename)
        end
    end

    # Format a file by means of formatter_class that is a child of Deplate::Formatter
    def format_file_with_formatter(formatter_class, sourcename)
        with_formatter(formatter_class, sourcename) do
            go_each([sourcename])
        end
    end
   
    # Format text by means of formatter_class that is a child of Deplate::Formatter
    def format_string_with_formatter(formatter_class, text, sourcename=nil)
        with_formatter(formatter_class, sourcename) do
            format_string(text, sourcename)
        end
    end

    # Format text with the current formatter
    def format_string(text, sourcename=nil)
        reset_output(false)
        maintain_current_source(sourcename) do
            accum_elements  = @accum_elements
            @accum_elements = Array.new
            include_each(text, @accum_elements, sourcename)
            process_document
            return body_string
        end
    end
    
    # Read text from STDIN. End on EOF or due to a matching 
    # pair of #BEGIN, #END pseudo commands
    def include_stdin(array)
        if $stdin.eof?
            log('No more input on STDIN', :anyway)
            exit 1
        end
        maintain_current_source('') do
            log('Including from STDIN')
            acc = []
            end_tag = nil
            $stdin.each_with_index do |l, i|
                if i == 0 and l =~ /^#BEGIN:/
                    end_tag = '#END:' + l[7..-1]
                elsif end_tag and l == end_tag
                    break
                else
                    acc << l
                end
            end
            include_each(acc, array, 'STDIN')
        end
    end

    # Read a file and add the parsed elements to array
    def include_file(array, filename, args={})
        maintain_current_source(filename) do
            log(['Including', filename])
            filename_abs    = File.expand_path(filename)
            unless @options.included
                filename_label  = file_label(filename_abs)
                @labels_floating << filename_label
            end
            File.open(filename, 'r') do |io|
                range = if (skip = args['skip'])
                            skip.to_i..-1
                        elsif (head = args['head'])
                            0..head.to_i
                        elsif (tail = args['tail'])
                            -tail.to_i..-1
                        else
                            nil
                        end
                if range
                    text = io.readlines[range].join
                else
                    text = io.read
                end
                if @formatter and args[:from_enc] != args[:to_enc]
                    text = @formatter.plain_text_recode(text, args[:from_enc], args[:to_enc])
                end
                include_each(text, array, filename)
            end
        end
    end

    # Include each line in enum and accumulate parsed elements in array
    def include_each(enum, array, sourcename=nil)
        case enum
        when Array
            enum = enum.join("\n")
        end
        @input.include_string(enum, array, 0)
    end

    # Include strings as if read from a file and return the resulting array of parsed elements
    def parsed_array_from_strings(strings, linenumber=nil, src='[array]')
        array = []
        erx   = @variables['embeddedTextRx']
        begin
            include_stringarray(strings, array, linenumber, src)
        ensure
            @variables['embeddedTextRx'] = erx if erx
        end
        return array
    end

    # Include strings as if read from a file and push parsed elements onto array
    def include_stringarray(strings, array, linenumber=nil, src='[array]')
        maintain_current_source(src) do
            include_each(strings, array, linenumber || 0)
        end
    end

    def auto_numbered(base, args=nil)
        if args
            n = if (s = args[:set])
                    @auto_numbered[base] = s
                elsif (s = args[:inc])
                    if @auto_numbered[base]
                        @auto_numbered[base] += s
                    else
                        @auto_numbered[base] = 0
                    end
                else
                    log(['Internal error', 'auto_numbered', base, args], :error)
                    nil
                end
            if (t = args[:fmt])
                t % n
            elsif (t = args[:fmt0])
                if n > 0
                    t % n
                else
                    t % nil
                end
            else
                n
            end
        else
            return @auto_numbered[base]
        end
    end
    
    # Set the current top heading.
    # heading:: Heading object
    # text:: The output filename base
    def set_top_heading(heading, text)
        if heading.level <= @options.split_level
            fname = nil
            sfx   = @options.suffix
            # dir   = @options.dir
            if @output_headings.include?(heading)
                maj = top_heading_idx(heading)
            else
                heading.top_heading = heading
                push_top_heading(heading)
                maj = @output_headings.size - 1
                unless text or !@options.multi_file_output
                    afn = @variables['autoFileNames']
                    if afn
                        fname = Deplate::Core.clean_filename(heading.get_text)[0..20]
                        c = auto_numbered(fname)
                        if c
                            fname = Deplate::Core.canonic_file_name(fname, sfx, :maj => c, :min => 0, :raw => true)
                            auto_numbered(fname, :inc => 1)
                        else
                            fname = Deplate::Core.canonic_file_name(fname, sfx, :raw => true)
                            auto_numbered(fname, :set => 0)
                        end
                    else
                        # if @variables['autoBaseName']
                        #     fname = File.basename(@current_source, '.*')
                        #     fmaj  = if auto_numbered(fname)
                        #                 auto_numbered(fname, :inc => 1)
                        #             else
                        #                 auto_numbered(fname, :set => 0)
                        #             end
                        # else
                        #     fname = File.basename(@dest, '.*')
                        #     fmaj  = maj
                        # end
                        fname = @variables['autoBaseName'] ? @current_source : @dest
                        fname = File.basename(fname, '.*')
                        fmaj  = if auto_numbered(fname)
                                    auto_numbered(fname, :inc => 1)
                                # <+TBD+>
                                elsif @accum_elements.size == 1 and 
                                    @accum_elements[0].kind_of?(Deplate::Element::PotentialPageBreak)
                                    auto_numbered(fname, :set => 0)
                                else
                                    auto_numbered(fname, :set => 1)
                                end
                        fname = Deplate::Core.canonic_file_name(fname, sfx, :maj => fmaj, :min => 0, :raw => true)
                    end
                end
            end
            if !@options.multi_file_output
                # fname = ""
                fname = @dest
            else
                if text
                    fname = Deplate::Core.canonic_file_name(text, sfx)
                end
                if fname
                    fname = Deplate::Core.get_out_fullname(fname, nil, @options)
                end
                @output.simulate_reset
            end
            # if fname and @options.multi_file_output
            if fname
                heading.destination = @output_filename[maj] = fname
            end
            log(["Set top heading", maj, (text||"nil"), fname], :debug)
        end
    end

    # Get a top/page heading by its index.
    # idx:: The index (integer)
    def top_heading_by_idx(idx)
        @output_headings[idx || 0]
    end
    
    # Get the top/page heading index (or get the current index if no top 
    # heading object is provided.
    def top_heading_idx(top=nil)
        if top
            @output_headings.index(top)
        else
            @output_headings.size - 1
        end
    end
    
    # Return the number of output pages.
    def number_of_outputs
        @output_headings.size
    end

    # Return the index for a top heading.
    def output_index(top=nil)
        if top
            top_heading_idx(top)
        else
            @collected_output.size - 1
        end
    end

    # Return the nth output filename.
    # idx:: Top heading index (integer)
    def output_filename_by_idx(idx)
        if idx
            idx = idx.to_i if idx.kind_of?(String)
            @output_filename[idx]
        end
    end
    
    # accum format elts in pre/body|matter/post
    def printable_strings(strings, linenumber=nil, src="[array]")
        @formatter.pre_process
        output = []
        accum_elements = []
        include_stringarray(strings, accum_elements, linenumber, src)
        accum_elements.collect! do |e|
            e.doc_type = :array
            e.doc_slot = output
            e.process
        end
        accum_elements.compact!
        for e in accum_elements
            e.doc_type = :array
            e.doc_slot = output
            e.print
        end
        return output
    end
 
    def is_allowed?(ids, args={})
        args = args.dup
        args[:logger] ||= self
        Deplate::Core.is_allowed?(@options, ids, args)
    end
    
    # Return whether ruby code may be evaluated.
    def allow_ruby
        @options.allow_ruby || is_allowed?('x')
    end

    # Return whether external applications may be run
    def allow_external
        @options.allow_external || is_allowed?('X')
    end
    
    # Caller requests calling ruby code with some args
    def eval_ruby(invoker, args, code)
        ar = allow_ruby
        case ar
        when true
            begin
                # +++ Run this in a thread and set $SAFE for this thread only
                context = (args['context'] || '').downcase
                case context
                when 'ruby'
                    return eval(code)
                when 'deplate'
                    return self.instance_eval(code)
                when 'self', 'this'
                    return invoker.instance_eval(code)
                else
                    return Deplate::Void.module_eval(code)
                end
            rescue Exception => e
                src = invoker ? invoker.source : nil
                invoker.log(["Error in ruby code", code, e], :error)
            end
        when 1,2,3,4,5
            result, error = Deplate::Safe.safe(ar, code)
            if error then
                invoker.log(["Error in ruby code", code, error.inspect], :error)
            else
                return result.to_s
            end
        else
            if args['alt']
                return args['alt']
            elsif caller
                invoker.log(["Disabled ruby command", code], :anyway)
            end
        end
    end
    
    # Set a clip.
    # id:: The clip's name
    # value:: An instance of either Deplate::Element::Clip or 
    #   Deplate::Regions::Clip.
    def set_clip(id, value)
        @clips[id] = value
    end

    # Get a clip.
    # id:: The clip's name
    # FIXME: This check for @elt should not be necessary.
    def get_clip(id)
        c = @clips[id]
        if c and !c.elt
            c = @clips[id] = c.process
        end
        c
    end

    # Set all clips.
    # clips:: A hash
    def set_all_clips(clips)
        @clips = clips
    end

    # Get a hash on yet unprocessed clips. Obsolete?
    def get_unprocessed_clips
        @clips
    end
   
    # Get all css files that are required by the current document.
    def collected_css
        @@css
    end
    
    # Return whether +file+ was already included.
    def file_included?(file, dir=nil, try_suffix=nil)
        dir  = dir || "."
        file = File.expand_path(file, dir)
        rv   = @allsources.keys.include?(file)
        if !rv and try_suffix
            file = File.expand_path(file + try_suffix, dir)
            rv   = @allsources.keys.include?(file)
        end
        return rv
    end

    # Make +file+ a filename relative to +dir+.
    def relative_path(file, dir)
        fn1 = Pathname.new(File.expand_path(file))
        fn2 = Pathname.new(File.expand_path(dir))
        rv  = fn1.relative_path_from(fn2).to_s
        return rv == "." ? "" : rv
    end
 
    def relative_path_by_file(file, base_file)
        if file
            if base_file
                relative_path(file, File.dirname(base_file))
            else
                File.basename(file)
            end
        else
            ''
        end
    end
    
    # Return the automatically generated label for an included file.
    def file_label(filename_abs)
        if filename_abs
            label = @allsources[filename_abs]
            unless label
                # rel   = relative_path(filename_abs, Dir.pwd)
                label = "file%03d" % @allsources.size
                label.gsub!(/\W/, "00")
                @allsources[filename_abs] = label
            end
            return label
        else
            return nil
        end
    end

    # Amend +file+'s suffix.
    def file_with_suffix(file, sfx=nil, filename_only=false)
        sfx  = sfx || ''
        fn   = File.basename(file, '.*')
        if filename_only
            return fn + sfx
        else
            dir   = File.dirname(file)
            fname = fn + sfx
            if dir == '.'
                return fname
            else
                return File.join(dir, fname)
            end
        end
    end

    # Return the output file according to +level_as_string+.
    def file_name_by_level(level_as_string)
        if @options.multi_file_output and level_as_string
            if level_as_string.kind_of?(String)
                las = level_as_string
            else
                las = level_as_string.to_s
            end
            case las
            when '', '0'
                top = top_heading_by_idx(0)
            else
                top = nil
                catch(:ok) do
                    each_heading do |heading, title|
                        if heading.level_as_string == las
                            top = heading.top_heading
                            throw :ok
                        end
                    end
                    # raise "Internal error: unknown level: #{level_as_string}"
                    log(['Internal error: Unknown level', level_as_string], :error)
                    return nil
                end
            end
            return top.destination
        elsif level_as_string == "0"
            return File.basename(@dest)
        else
            return ""
        end
    end
    
    # Return the canonic name for an automatically generated label (e.g., 
    # figures, tables ...)
    def elt_label(prefix, text, plain=false)
        if text
            if plain
                return "%s00%s" % [prefix, text.sum]
            else
                return "%s00%s" % [prefix, text.gsub(/\W/, "00")]
            end
        else
            # raise msg("No label")
            log(["No label", prefix], :error)
            return nil
        end
    end

    # Create a new output and push it to @collected_output.
    def new_output(inherited_output=nil, args={})
        @output = Deplate::Output.new(self, inherited_output)
        @collected_output << @output
        @output.top_heading = top_heading_by_idx(@collected_output.size - 1)
        @output.index       = @output_maj_min.dup
        @output.reset
        increase_maj_min
    end

    # Insert a page/output break.
    def break_output(minor=false)
        @output.body_flush
        new_output(@output)
    end

    # Return all the formatted output as string.
    def body_string
        return @collected_output.collect {|o| o.join("\n")}.join("\n")
    end

    # Write the output to the disk.
    def body_write
        rv = nil
        method = uri_method_name_with_prefix("body_write_to_", @dest)
        log(["Writing output file(s)", @collected_output.size])
        if method
            for output in @collected_output
                rv = send(method, @dest, output)
            end
        elsif @dest == '-'
            sep = @variables["stdoutSeparator"]
            for output in @collected_output
                puts(output.join("\n"))
                puts sep if sep
            end
        elsif @options.multi_file_output
            @collected_output.each_with_index do |output, i|
                if output.body_empty?
                    log("Empty body ... skipping")
                else
                    dest = output.destination
                    rv ||= dest
                    log(["Writing file", i, dest])
                    write_file(dest) do |io|
                        io.puts(output.join("\n"))
                    end
                    call_methods_matching(@formatter, /^hook_post_write_file_/)
                    output.merge_metadata(@metadata)
                    if @options.metadata_model and output.metadata_available?
                        md_dest = Deplate::Core.file_join(@options.dir, output.metadata_destination)
                        log(["Saving metadata", md_dest])
                        write_metadata(md_dest, output)
                    end
                end
            end
        else
            dest = @collected_output.first.destination
            # dest = @dest
            log(["Writing file", dest])
            write_file(dest) do |io|
                for output in @collected_output
                    io.puts(output.join("\n"))
                end
                io.puts
            end
            call_methods_matching(@formatter, /^hook_post_write_file_/)
            if @options.metadata_model
                md = @metadata.dup
                for output in @collected_output
                    if output.metadata_available?
                        for key, data in output.metadata
                            for e in data
                                push_metadata(e, md)
                            end
                        end
                    end
                end
                unless md.empty?
                    output  = @collected_output.first
                    md_dest = auxiliary_filename(output.metadata_destination(@dest), true)
                    log(["Saving metadata", md_dest])
                    write_metadata(md_dest, output, md)
                end
            end
        end
        rv || @dest
    end

   
    def copy_resources
        @options.resources.each do |src, anyway|
            res  = File.basename(src)
            dest = auxiliary_filename(res, true)
            if anyway or !File.exist?(dest)
                copy_file(src, dest)
            end
        end
    end


    # Make sure +dir+ exists (create it if it doesn't).
    def ensure_dir_exists(dir)
        Deplate::Core.ensure_dir_exists(dir, @options)
        # unless File.exist?(dir)
        #     if @options.force
        #         Deplate::Core.ensure_dir_exists(dir, @options)
        #     else
        #         log(["Destination directory doesn't exist", dir, Dir.pwd], :error)
        #         exit 5
        #     end
        # end
    end
    
    # Actually write something to some file.
    def write_file(file, mode='w', &block)
        if file
            # pwd = Dir.pwd
            begin
                case file
                when 1, 2, 3, '-'
                    ok = true
                    case file
                    when String
                        file = mode =~ /r/ ? 1 : 2
                    end
                else
                    #     Dir.chdir(@options.dir)
                    ensure_dir_exists(File.dirname(file))
                    ok = if File.exist?(file)
                             Deplate::Core.query_user(@options, 
                                                  "File '#{file}' already exists. Overwrite (y/N)? ", 
                                                  'y')
                         else
                             true
                         end
                end
                if ok
                    log(['Writing file', file], :debug)
                    File.open(file, mode) do |io|
                        block.call(io)
                    end
                end
                # ensure
                #     Dir.chdir(pwd)
            rescue Exception => e
                log(['Error when writing file', file, e], :error)
                exit 5
            end
        else
            log(['No output file', file], :error)
        end
    end
    
    # Copy a file.
    def copy_file(from, to)
        if File.directory?(to)
            to = File.join(to, File.basename(from))
            dir = to
        else
            dir = File.dirname(to)
        end
        if File.exist?(to)
            log(['File already exists', to])
        else
            ok = if @options.ask
                     puts "File '#{file}' already exists. Overwrite (y/N)? "
                     gets.chomp == 'y'
                 else
                     true
                 end
            if ok
                ensure_dir_exists(dir)
                FileUtils.cp_r(from, to)
                log(['Copy file', from, to])
            end
        end
    end
    
    def current_heading
        @options.counters.get('toc')
    end
    
    def current_heading_element
        e = @options.counters.get('toc', true)
        e && e[:container]
    end
    
    # Get the current section's level as string.
    def get_current_heading
        @options.counters.get_s('toc')
    end

    # Increase the heading level.
    def increase_current_heading(container, level)
        @options.counters.increase('toc', :container => container, :level => level)
    end

    # Get the current top heading object.
    def get_current_top
        top_heading_by_idx(top_heading_idx)
    end
 
    def get_numbering_mode(entity, default=1)
        (@variables["#{entity}Numbering"] || default).to_i
    end
    
    # Register a new label.
    # invoker:: The labelled object
    # label:: The label name
    # level_as_string:: The section heading's level as string (redundant???)
    def add_label(invoker, label, level_as_string, opts={})
        if !opts[:anyway] and (@labels[label] or @label_aliases[label])
            invoker.log(['Label already defined', label, level_as_string], :error)
        else
            @labels[label]        = level_as_string
            @label_aliases[label] = opts[:container] || invoker
        end
    end

    def set_label_object(invoker, label, level_as_string, opts={})
        if @label_aliases[label]
            @label_aliases[label] = opts[:container] || invoker
        else
            # add_label(invoker, label, level_as_string, opts
        end
    end
    
    # <+TBD+>This doesn't work as intended. Elements still have to be 
    # labelled in order to be referred to by their ID
    def get_label_by_id(invoker, id)
        o = @ids[id]
        if o
            l = o.label
            l &&= l.first
            if l
                return l
            else
                return id
                # invoker.log(["Object has no label", id], :error)
            end
        else
            invoker.log(['No object with that ID', id], :error)
        end
    end

    # Get the filename of the object marked with +label+.
    def get_filename_for_label(invoker, label)
        f = @label_aliases[label]
        if f
            f = f.top_heading.destination
            d = invoker.top_heading.destination
            if f == d
                return ''
            else
                return relative_path(f, File.dirname(d))
            end
        else
            # puts caller
            invoker.log(['Reference to unknown label', label], :error)
        end
    end
 
    # A dummy method to be overwritten by a metadata module.
    def dump_metadata(data)
        data
    end
    
    # A dummy method to be overwritten by a metadata module.
    def put_metadata(io, metadata)
        io.puts(metadata)
    end
    
    # A dummy method to be overwritten by a metadata module.
    def write_metadata(file, output, metadata=nil)
        write_file(file) do |io|
            md = metadata ? output.format_metadata(metadata) : output.format_metadata
            put_metadata(io, md)
        end
    end

    # Return the metadata as hash.
    def get_metadata(source, metadata)
        if @options.metadata_model
            if source
                metadata['source_file']  = source.file
                metadata['source_begin'] = source.begin
                metadata['source_end']   = source.end
                if (stats = source.stats)
                    if (mtime = stats.mtime)
                        metadata['source_mtime'] = mtime
                    end
                end
            end
            metadata
        else
            nil
        end
    end

    # Register a new metadata entry.
    # source:: The related source filename
    # metadata:: A hash
    def register_metadata(source, metadata)
        if @options.metadata_model
            push_metadata(get_metadata(source, metadata))
        end
    end

    # Actually save the metadata in some variable for later use.
    def push_metadata(data, array=@metadata)
        if @options.metadata_model
            type = data["type"]
            @metadata[type] ||= []
            @metadata[type] << data
        end
    end
   
    # Register an object's ID.
    # <+TBD+>Not systematically used yet.
    def register_id(hash, obj)
        id  = hash["id"]
        xid = hash["xid"]
        if id and xid
            log(["Option clash: both id and xid provided", id, xid], :error, obj.source)
        else
            id ||= xid
        end
        if id and !id.empty?
            if @ids[id]
                # obj.log(["ID with the same name already exists", id, @ids[id].level_as_string], :error)
            else
                obj.log(["Register ID", id, obj.class], :debug)
                @ids[id] = obj
            end
        end
    end
    
    # Register a new index entry.
    def add_index(container, names, level_as_string='')
        @index_last_idx += 1
        id    = "idx00#{@index_last_idx}"
        words = names.split(/\s*\|\s*/)
        lname = Deplate::Core.remove_backslashes(words[0])
        if container
            # container = container.top_container || container
            level_as_string = container.level_as_string
        end
        if @options.dont_index.delete(lname)
            return nil
        else
            i = @index[lname]
            unless i
                i = @index.find do |k, a|
                    a.find do |i|
                        i.synonymes.find {|j| words.include?(j)}
                    end
                end
                if i
                    lname = i[0]
                    i = @index[lname]
                end
            end
            if @options.each
                f = file_with_suffix(File.basename(@current_source), @options.suffix, true)
            elsif @options.multi_file_output
                f = nil
            else
                f = @dest
            end
            d = Deplate::IndexEntry.new(container) do |idx|
                idx.name            = lname
                idx.synonymes       = words
                idx.label           = id
                idx.file            = f
                idx.level_as_string = level_as_string
            end
            if i
                i << d
            else
                @index[lname] = [d]
            end
            return d
        end
    end

    # Remove a registered index entry.
    def remove_index(containes, names)
        lname  = Deplate::Core.remove_backslashes(names.split(/\s*\|\s*/)[0])
        i      = @index[lname]
        if i
            i.pop
            @index.delete(lname) if i.empty?
        end
    end

    # Return a localized version of text. (delegated)
    def msg(text)
        @options.messages.msg(text)
    end

    # Class variable accessor.
    def symbols
        @@symbols
    end

    # Class variable accessor.
    def templates
        @@templates
    end

    # Join an array of particles into a string.
    def join_particles(particles)
        particles.join
    end

    # Return an array of unprocessed particles as string.
    def format_particles(particles)
        return join_particles(particles.collect{|e| e.process; e.elt})
    end

    # Parse +text+ and return a formatted string.
    def parse_and_format(container, text, alt=true, args={})
        t = parse(container, text, alt, args)
        return format_particles(t)
    end

    def parse_and_format_without_wikinames(container, text, alt=true)
        excluded = [
            Deplate::HyperLink::Simple,
            Deplate::HyperLink::Extended,
        ]
        return parse_and_format(container, text, alt, :excluded => excluded)
    end

    # Evaluate block (args: heading, caption) with each heading.
    def each_heading(depth=nil, &block)
        case depth
        when :top
            arr   = @output_headings
            depth = false
        else
            arr = @options.listings.get('toc')
        end
        for section in arr
            if !depth or (section and section.level <= depth)
                unless section and section.args["noList"]
                    if section.kind_of?(Deplate::NullTop)
                        v = section.caption.elt
                    else
                        v = section.description
                        v = v.gsub(/<\/?[^>]*>/, "")
                        v = [section.level_as_string, v].join(" ")  unless section.plain_caption?
                    end
                    block.call(section, v)
                end
            end
        end
    end
    
    def bib_styler(style)
        styler = @@bib_style[style] || @@bib_style['default']
        styler.new(self)
    end
   
    def home_index
        hidx = @variables['homeIndex']
        if hidx
            return hidx
        else
            @collected_output.each_with_index do |o, i|
                unless o.body_empty?
                    return i
                end
            end
            return 0
        end
    end

    def object_by_id(id)
        o = @ids[id]
        if o
            return o
        else
            log(['Unknown ID', id], :error)
        end
    end


    private
    def set_safe
        if @options.allow_ruby and @options.allow_ruby.kind_of?(Integer)
            $SAFE = @options.allow_ruby
        end
    end

    def set_standard_clips
        unless @options.clips_initialized
            if defined?(@input) and @input
                for id, text in @options.clips
                    if text.kind_of?(Deplate::Element::Clip)
                        @options.clips[id] = text
                    else
                        src  = '[clip]'
                        text = parse_with_source(src, text, false) 
                        @options.clips[id] = Deplate::Element::Clip.new(text, self, src)
                    end
                end
                @options.clips_initialized = true
            end
            @clips = @options.clips.dup
        end
    end
    
    def reset_footnotes
        @footnote_last_idx = 0
        @footnotes_used = []
    end

    # Execute block but make sure that @current_source remains unchanged
    def maintain_current_source(source, &block)
        begin
            current_source       = @current_source
            current_source_stats = @current_source_stats
            @current_source      = source
            if source and File.exist?(source)
                @current_source_stats = File.stat(source)
            else
                @current_source_stats = nil
            end
            block.call
        ensure
            @current_source = current_source
            @current_source_stats = current_source_stats
        end
    end

    # Set @formatter to an instance of formatter_class, call block, and 
    # restore the old @formatter
    def with_formatter(formatter_class, sourcename=nil, &block)
        formatter_orig = @formatter
        options_orig   = @options
        begin
            if @formatter.instance_of?(formatter_class)
                @formatter = @formatter.dup
                @formatter.reset!
            else
                @formatter = formatter_class.new(self, @args)
            end
            @options = formatter_class.set_options_for_file(options.dup, sourcename)
            rv = block.call
        ensure
            @formatter = formatter_orig
            @options   = options_orig
        end
    end

    def process_prelude
        prelude = @options.prelude
        unless prelude.empty?
            include_stringarray(prelude, @accum_elements, nil, "[prelude]")
        end
    end

    # Read the file
    def read_file(sources=@sources)
        for f in sources
            method = uri_method_name_with_prefix("read_from_", f)
            if method
                send(method, f)
            elsif f == "-"
                include_stringarray(@@deplate_template, @accum_elements, nil, "@@deplate_template")
                include_stdin(@accum_elements)
            elsif File.exists?(f)
                if File.stat(f).file?
                    include_stringarray(@@deplate_template, @accum_elements, nil, "@@deplate_template")
                    include_file(@accum_elements, f)
                elsif @options.recurse
                    read_file(get_dir_listing(f))
                else
                    log(['Is no file', f], :error)
                end
            else
                log(['File not found', f], :error)
            end
        end
    end
   
    def process_document
        @formatter.pre_process
        process_etc
        process
        print_prepare
        print_etc
        print
        body_finish
    end
   
    def process_etc
        unless @output_headings.empty?
            @output_headings.first.first_top = true
            @output_headings.last.last_top   = true
        end

        filter = @variables['efilter']

        for p in preprocess
            p.call unless p.exclude?(filter)
        end

        for hd in @headings.keys
            if @headings[hd].exclude?(filter)
                @headings.delete(hd)
            end
        end

        # Basically, this shouldn't be necessary as a filtered element 
        # should never make it into the listing.
        for name,_ in @options.listings
            @options.listings.get(name).delete_if {|e| e.exclude?(filter)}
        end

        for fn in @footnotes.keys
            e = @footnotes[fn]
            @footnotes[fn] = e.process
        end

        for clp in @clips.keys
            e = @clips[clp]
            @clips[clp]  = e.process
        end
    end

    # process elts
    def process
        log('Processing elements')
        call_methods_matching(@formatter, /^hook_pre_process_/)
        filter = @variables['efilter']
        @accum_elements.collect! do |e|
            e.process unless e.exclude?(filter)
        end
        @accum_elements.flatten!
        @accum_elements.compact!
    end

    def print_prepare
        log('Preparing formatting')
        call_methods_matching(@formatter, /^hook_pre_prepare_/)
        @formatter.prepare
        call_methods_matching(@formatter, /^prepare_/)
        call_methods_matching(@formatter, /^hook_post_prepare_/)
    end

    def print_etc
        reset_footnotes
    end

    def print
        log("Formatting elements")
        for e in @accum_elements
            e.print
        end
        for p in @postponed_print
            p.call
        end

    end

    def body_finish
        @output.body_flush
    end

    def uri_method_name_with_prefix(prefix, uri)
        begin
            uri    = URI.parse(uri)
            scheme = uri.scheme
            if scheme
                name = prefix + scheme
                if respond_to?(name)
                    return name
                end
            end
        rescue URI::InvalidURIError => e
        end
        return nil
    end

    # Set heading as the current top heading.
    def push_top_heading(heading)
        @output_headings << heading
    end
    
    def increase_maj_min(minor=false)
        if minor
            @output_maj_min[1] += 1
        else
            @output_maj_min[0] += 1
        end
    end
    
end


# vim: ff=unix
# Local Variables:
# revisionRx: MicroRev\s\+=\s\+\'
# End:
