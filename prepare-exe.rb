#!/usr/bin/env ruby
# prepare-exe.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://members.a1.net/t.link/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     21-Nov-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.124

# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

module PrepareExe
    module_function

    BuiltIn = <<EOR
class Deplate::Core
    class << self
        def builtin_modules
            return [
%s
            ]
        end

        def builtin_formatters
            return [
%s
            ]
        end

        def builtin_css
            return []
        end
    
        def builtin_input
            return [
%s
            ]
        end
    
        def builtin_metadata
            return [
            ]
        end
    
        def builtin_locale
            return [
            ]
        end
    end
end
EOR

    RubyLib    = "c:/ruby/lib/ruby/1.8"
    RubySiteLib = "c:/cygwin/lib/ruby/site_ruby/1.8"
    # RubyLib    = "/cygdrive/c/ruby/lib/ruby/1.8"
    RubyLibBin = "i386-mswin32"

    # RubyLib     = "c:/cygwin/lib/ruby/1.8"
    # RubyLib     = "/lib/ruby/1.8"
    # RubyLibBin  = "i386-cygwin"
    # RubySiteLib = "/lib/ruby/site_ruby/1.8"
    Exr = <<EOR
set_kcode	none
add_ruby_script	deplate.rb	lib/deplate.rb
add_ruby_script	deplate/builtin.rb	builtin.rb

%s

add_ruby_script	rbconfig.rb	#{RubyLib}/#{RubyLibBin}/rbconfig.rb
 
# add_ruby_script	base64.rb	#{RubyLib}/base64.rb
# add_ruby_script	digest/md5.rb	#{RubyLib}/digest/md5.rb
# add_ruby_script	digest/sha1.rb	#{RubyLib}/digest/sha1.rb
# add_ruby_script	erb.rb	#{RubyLib}/erb.rb
# add_ruby_script	etc.rb	#{RubyLib}/etc.rb
# add_ruby_script	fcntl.rb	#{RubyLib}/fcntl.rb
add_ruby_script	fileutils.rb	#{RubyLib}/fileutils.rb
add_ruby_script	forwardable.rb	#{RubyLib}/forwardable.rb
add_ruby_script	ftools.rb	#{RubyLib}/ftools.rb
add_ruby_script	getopts.rb	#{RubyLib}/getopts.rb
add_ruby_script	optparse.rb	#{RubyLib}/optparse.rb
add_ruby_script	ostruct.rb	#{RubyLib}/ostruct.rb
add_ruby_script	pathname.rb	#{RubyLib}/pathname.rb
add_ruby_script	tmpdir.rb	#{RubyLib}/tmpdir.rb
# add_ruby_script	openssl.rb	#{RubyLib}/openssl.rb
# add_ruby_script	socket.rb	#{RubyLib}/socket.rb
# add_ruby_script	stringio.rb	#{RubyLib}/stringio.rb
# add_ruby_script	tempfile.rb	#{RubyLib}/tempfile.rb
# add_ruby_script	thread.rb	#{RubyLib}/thread.rb
# add_ruby_script	timeout.rb	#{RubyLib}/timeout.rb
# add_ruby_script	term/ansicolor	#{RubySiteLib}/term/ansicolor.rb

add_ruby_script	parsedate.rb	#{RubyLib}/parsedate.rb
add_ruby_script	date/format.rb	#{RubyLib}/date/format.rb
add_ruby_script	rational.rb	#{RubyLib}/rational.rb
add_ruby_script	time.rb	#{RubyLib}/time.rb

add_ruby_script	uri.rb	#{RubyLib}/uri.rb
add_ruby_script	uri/common.rb	#{RubyLib}/uri/common.rb
add_ruby_script	uri/ftp.rb	#{RubyLib}/uri/ftp.rb
add_ruby_script	uri/generic.rb	#{RubyLib}/uri/generic.rb
add_ruby_script	uri/http.rb	#{RubyLib}/uri/http.rb
add_ruby_script	uri/https.rb	#{RubyLib}/uri/https.rb
add_ruby_script	uri/ldap.rb	#{RubyLib}/uri/ldap.rb
add_ruby_script	uri/mailto.rb	#{RubyLib}/uri/mailto.rb

# add_ruby_script	yaml.rb	#{RubyLib}/yaml.rb
# add_ruby_script	yaml/baseemitter.rb	#{RubyLib}/yaml/baseemitter.rb
# add_ruby_script	yaml/constants.rb	#{RubyLib}/yaml/constants.rb
# add_ruby_script	yaml/emitter.rb	#{RubyLib}/yaml/emitter.rb
# add_ruby_script	yaml/error.rb	#{RubyLib}/yaml/error.rb
# add_ruby_script	yaml/rubytypes.rb	#{RubyLib}/yaml/rubytypes.rb
# add_ruby_script	yaml/stream.rb	#{RubyLib}/yaml/stream.rb
# add_ruby_script	yaml/syck.rb	#{RubyLib}/yaml/syck.rb
# add_ruby_script	yaml/yamlnode.rb	#{RubyLib}/yaml/yamlnode.rb
# add_ruby_script	yaml/basenode.rb	#{RubyLib}/yaml/basenode.rb
# add_ruby_script	yaml/dbm.rb	#{RubyLib}/yaml/dbm.rb
# add_ruby_script	yaml/encoding.rb	#{RubyLib}/yaml/encoding.rb
# add_ruby_script	yaml/loader.rb	#{RubyLib}/yaml/loader.rb
# add_ruby_script	yaml/store.rb	#{RubyLib}/yaml/store.rb
# add_ruby_script	yaml/stringio.rb	#{RubyLib}/yaml/stringio.rb
# add_ruby_script	yaml/types.rb	#{RubyLib}/yaml/types.rb
# add_ruby_script	yaml/ypath.rb	#{RubyLib}/yaml/ypath.rb
# 
# add_extension_library	syck.so	#{RubyLib}/i386-cygwin/syck.so

# add_ruby_script	webrick.rb	#{RubyLib}/webrick.rb
# add_ruby_script	webrick/accesslog.rb	#{RubyLib}/webrick/accesslog.rb
add_ruby_script	webrick/cgi.rb	#{RubyLib}/webrick/cgi.rb
# add_ruby_script	webrick/compat.rb	#{RubyLib}/webrick/compat.rb
# add_ruby_script	webrick/config.rb	#{RubyLib}/webrick/config.rb
# add_ruby_script	webrick/cookie.rb	#{RubyLib}/webrick/cookie.rb
# add_ruby_script	webrick/htmlutils.rb	#{RubyLib}/webrick/htmlutils.rb
# add_ruby_script	webrick/httpauth/authenticator.rb	#{RubyLib}/webrick/httpauth/authenticator.rb
# add_ruby_script	webrick/httpauth/basicauth.rb	#{RubyLib}/webrick/httpauth/basicauth.rb
# add_ruby_script	webrick/httpauth/digestauth.rb	#{RubyLib}/webrick/httpauth/digestauth.rb
# add_ruby_script	webrick/httpauth/htdigest.rb	#{RubyLib}/webrick/httpauth/htdigest.rb
# add_ruby_script	webrick/httpauth/htgroup.rb	#{RubyLib}/webrick/httpauth/htgroup.rb
# add_ruby_script	webrick/httpauth/htpasswd.rb	#{RubyLib}/webrick/httpauth/htpasswd.rb
# add_ruby_script	webrick/httpauth/userdb.rb	#{RubyLib}/webrick/httpauth/userdb.rb
# add_ruby_script	webrick/httpauth.rb	#{RubyLib}/webrick/httpauth.rb
# add_ruby_script	webrick/httpproxy.rb	#{RubyLib}/webrick/httpproxy.rb
# add_ruby_script	webrick/httprequest.rb	#{RubyLib}/webrick/httprequest.rb
# add_ruby_script	webrick/httpresponse.rb	#{RubyLib}/webrick/httpresponse.rb
# add_ruby_script	webrick/https.rb	#{RubyLib}/webrick/https.rb
# add_ruby_script	webrick/httpserver.rb	#{RubyLib}/webrick/httpserver.rb
# add_ruby_script	webrick/httpservlet/abstract.rb	#{RubyLib}/webrick/httpservlet/abstract.rb
# add_ruby_script	webrick/httpservlet/cgi_runner.rb	#{RubyLib}/webrick/httpservlet/cgi_runner.rb
# add_ruby_script	webrick/httpservlet/cgihandler.rb	#{RubyLib}/webrick/httpservlet/cgihandler.rb
# add_ruby_script	webrick/httpservlet/erbhandler.rb	#{RubyLib}/webrick/httpservlet/erbhandler.rb
# add_ruby_script	webrick/httpservlet/filehandler.rb	#{RubyLib}/webrick/httpservlet/filehandler.rb
# add_ruby_script	webrick/httpservlet/prochandler.rb	#{RubyLib}/webrick/httpservlet/prochandler.rb
# add_ruby_script	webrick/httpservlet.rb	#{RubyLib}/webrick/httpservlet.rb
# add_ruby_script	webrick/httpstatus.rb	#{RubyLib}/webrick/httpstatus.rb
# add_ruby_script	webrick/httputils.rb	#{RubyLib}/webrick/httputils.rb
# add_ruby_script	webrick/httpversion.rb	#{RubyLib}/webrick/httpversion.rb
# add_ruby_script	webrick/log.rb	#{RubyLib}/webrick/log.rb
# add_ruby_script	webrick/server.rb	#{RubyLib}/webrick/server.rb
# add_ruby_script	webrick/ssl.rb	#{RubyLib}/webrick/ssl.rb
# add_ruby_script	webrick/utils.rb	#{RubyLib}/webrick/utils.rb
# add_ruby_script	webrick/version.rb	#{RubyLib}/webrick/version.rb

# add_ruby_script	xmlrpc/server.rb	#{RubyLib}/xmlrpc/server.rb
EOR

    @rubysrc   = []
    @modules   = []
    @formatter = []
    @input     = []
    @metadata  = []

    @excluded_modules = [
        "deplate/mod/xmlrpc.rb",
    ]

    def accum(dir, root, acc, exclude=nil)
        begin
            cd = Dir.getwd()
            Dir.chdir(dir)
            Dir.chdir(root) if root
            for f in Dir["*.rb"]
                if exclude and exclude.find do |p|
                    if p.kind_of?(Regexp) then
                        f =~ p
                    else
                        f == p
                    end
                end
                    next
                end
                fn = File.basename(f, ".rb")
                acc << {
                    :name => fn,
                    :script => File.join(*([root, f].compact)),
                    :require => File.join(*([root, fn].compact)),
                    :full => File.join(*([dir, root, f].compact)),
                }
            end
        ensure
            Dir.chdir(cd)
        end
    end

    def collect_files(dir)
        if @rubysrc.empty?
            accum(dir, nil, @rubysrc)
            accum(dir, "deplate", @rubysrc, ['builtin.rb'])
        end
        accum(dir, "deplate/mod", @modules) if @modules.empty?
        @modules.delete_if {|e| @excluded_modules.include?(e[:script])}
        accum(dir, "deplate/fmt", @formatter)     if @formatter.empty?
        accum(dir, "deplate/input", @input)       if @input.empty?
        accum(dir, "deplate/metadata", @metadata) if @metadata.empty?
    end

    def format_array(array)
        arr = array.collect do |m|
            %{                "#{m[:name]}",}
        end
        arr.join("\n")
    end
    
    def build_builtin(dir)
        collect_files(dir)
        mods  = format_array(@modules)
        fmts  = format_array(@formatter)
        input = format_array(@input)
        meta  = format_array(@metadata)
        File.open("builtin.rb", "w") do |io|
            io.puts(BuiltIn % [mods, fmts, input, meta])
        end
    end

    def format_exr(acc)
        rv = []
        for e in acc
            rv << "add_ruby_script	#{e[:script]}	#{e[:full]}"
        end
        rv.join("\n")
    end
    
    def build_exr(dir)
        collect_files(dir)
        scripts = format_exr(@rubysrc)
        mods    = format_exr(@modules)
        fmts    = format_exr(@formatter)
        input   = format_exr(@input)
        meta    = format_exr(@metadata)
        File.open("deplate.exr", "w") do |io|
            io.puts(Exr % [scripts, fmts, mods, input, meta].join("\n\n"))
        end
    end
end

if __FILE__ == $0
    dir = ARGV[0]
    if dir
        PrepareExe.build_builtin(dir)
        PrepareExe.build_exr(dir)
    else
        puts <<Usage
prepare-exe DIR
Usage
    end
end


