# encoding: ASCII
# xmlrpc.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Jän-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.250
#
# = Description
# 
# = Usage
# In theory, it should work like this:
# 
#     a> deplate -m xmlrpc -&
#     b> irb
#     irb(main):001:0> require 'xmlrpc/client'
#     irb(main):001:0> deplate = XMLRPC::Client.new("localhost", "/deplate", 2000)
#     irb(main):002:0> puts deplate.call("convert", "html", "Some text and more and so on ...")
#     <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
#     <html lang="en">
#     <head>
#     [...]
#     irb(main):003:0> 
# 
# = TODO
# = CHANGES

require 'deplate/converter'
require 'ostruct'
require 'tmpdir'
require 'fileutils'
require 'webrick'
require 'xmlrpc/server'

class Deplate::Core
    def go_now
        @variables['xmlrpcID'] ||= 'deplate'
        @xmlrpc_converters = {}
        @xmlrpc_timeout    = @variables['xmlrpcTimeout']
        if @xmlrpc_timeout
            @xmlrpc_timeout = @xmlrpc_timeout.to_i
        else
            @xmlrpc_timeout = 300
        end
        
        xml_servlet = XMLRPC::WEBrickServlet.new
        xml_servlet.add_handler('convert') do |format, text|
            xmlrpc_convert_string(format, text)
        end
        xml_servlet.add_handler('shutdown') do |code|
            xmlrpc_shutdown(code)
        end
        xml_servlet.add_handler('convert_string') do |format, text|
            xmlrpc_convert_string(format, text)
        end
        xml_servlet.add_handler('convert_file') do |format, filename|
            xmlrpc_convert_file(format, filename)
        end
        xml_servlet.add_handler('string_to_fileset') do |format, filename, text|
            xmlrpc_string_to_fileset(format, filename, text)
        end
        xml_servlet.add_handler('fileset_to_fileset') do |format, filename, fileset|
            xmlrpc_fileset_to_fileset(format, filename, fileset)
        end
        xml_servlet.add_multicall

        uri  = URI.parse(@sources.first) || OpenStruct.new
        port = uri.port
        unless port
            port = @variables['xmlrpcPort']
            port = port ? port.to_i : 2000
        end

        path = uri.path
        if !path or path == '-'
            path = @variables['xmlrpcPath'] || '/deplate'
        end

        valid_ips = @variables['xmlrpcAllow']
        if valid_ips
            valid_ips = Deplate::Core.split_list(valid_ips, ',', ' ')
            valid_ips.collect! do |s|
                if s =~ /^\d+\.\d+\.\d+\.\d+\$/
                    s = Regexp.escape(s)
                end
                Regexp.new(s)
            end
            set_valid_ip(valid_ips)
        end
        
        log('XMLRPC: Starting server', :anyway)
        # @@log_destination = File.open(@variables["logFile"] || "deplate.log", "w")
        begin
            @xmlrpc_server = WEBrick::HTTPServer.new(:Port => port)
            @xmlrpc_server.mount(path, xml_servlet)
            @xmlrpc_server.logger.level = 1
            trap('INT') { @xmlrpc_server.shutdown }
            @xmlrpc_server.start
        ensure
            # @@log_destination.close
        end
    end

    def xmlrpc_shutdown(code)
        if @variables['xmlrpcAllowShutdown']
            @xmlrpc_server.shutdown
            return true
        else
            log('Ignored: shutdown', :anyway)
            return false
        end
    end
    
    def xmlrpc_convert_string(format, text)
        cvt = get_converter(format)
        if cvt
            return cvt.convert_string(text)
        else
            raise FaultException
        end
    end

    def xmlrpc_convert_file(format, filename)
        cvt = get_converter(format)
        if cvt
            return cvt.convert_file(filename)
        else
            raise FaultException
        end
    end
    
    def xmlrpc_string_to_fileset(format, filename, text)
        convert_to_fileset(filename) do
            convert_and_collect(format, filename, text)
        end
    end

    def xmlrpc_fileset_to_fileset(format, filename, fileset)
        convert_to_fileset(filename) do
            definition = fileset.delete(filename)
            text       = definition['contents']
            convert_and_collect(format, filename, text) do
                write_fileset(fileset)
            end
        end
    end

    private
    def convert_to_fileset(fileset_id, &block)
        unless defined?(@tmpdir)
            @tmpdir = @variables['tmpDir']
            unless @tmpdir
                if Dir.tmpdir
                    @tmpdir = File.join(Dir.tmpdir, @variables['xmlrpcID'], fileset_id)
                end
            end
            @lockdir = File.join(Dir.tmpdir,'deplate_locks')
        end
        if @tmpdir
            if File.exists?(@tmpdir)
                FileUtils.rm(Dir[File.join(@tmpdir, '*')])
            else
                FileUtils.mkdir(@tmpdir)
            end
            unless File.exists?(@lockdir)
                FileUtils.mkdir(@lockdir)
            end
            lockfile = File.join(@lockdir, fileset_id)
            if File.exists?(lockfile)
                timeout = File.mtime(lockfile) + @xmlrpc_timeout
                if timeout > Time.now
                    log(['XMLRPC: Fileset is locked', fileset_id, timeout], :error)
                    raise FaultException
                end
            end
            File.open(lockfile, 'w') {|io|}
            begin
                Dir.chdir(@tmpdir)
                return block.call
            ensure
                Dir.chdir(pwd)
                FileUtils.rm(lockfile)
            end
        else
            log('XMLRPC: No writable temporary directory', :error)
            raise FaultException
        end
    end

    def convert_and_collect(format, filename, text)
        yield if block_given?
        rv = {filename => xmlrpc_convert_string(format, text)}
        collect_fileset(rv)
        return rv
    end

    def write_fileset(fileset)
        for fname, definition in fileset
            if File.exists?(fname)
                changed = definition['changed']
                mtime   = definition['mtime']
                size    = definition['size']
                if !changed and mtime and size and mtime == File.mtime(fname) and size == File.size(fname)
                    next
                end
            end
            fname    = @formatter.encode_id(fname)
            contents = definition['contents']
            File.open(fname, 'w') {|io| io.puts(contents)}
        end
    end
    
    def collect_fileset(hash)
        for f in Dir['*']
            f = @formatter.encode_id(f)
            definition = {}
            definition['mtime']    = File.mtime(f)
            definition['size']     = File.size(f)
            definition['contents'] = File.open(f) {|io| io.read}
            hash[f] = definition
        end
    end
    
    def get_converter(format)
        if @variables['xmlrpcReuseInterpreter']
            cvt = @xmlrpc_converters[format] ||= Deplate::Converter.new(format, :master => self)
            # p "DBG deplate=#{cvt.object_id} #{@xmlrpc_converters[format].object_id}"
        else
            cvt = Deplate::Converter.new(format, :master => self)
        end
        return cvt
    end
end

