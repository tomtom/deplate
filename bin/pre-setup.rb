deplate_libdir = ENV['DEPLATE_HOME']
if deplate_libdir
    deplate_lib=File.join(deplate_libdir, 'deplate')
else
    deplate_lib='deplate'
end
# w32 = config("win32") == 'yes' || RUBY_PLATFORM =~ /mswin/
w32 = RUBY_PLATFORM =~ /mswin/

if w32

    f = "deplate.bat"
    t = <<EOS
@echo off
ruby -r"#{deplate_lib}" -e Deplate::Core.deplate -- %*
EOS
    
else
    
    f = "deplate"
    t = <<EOS
#!/usr/bin/env ruby
require '#{deplate_lib}'
Deplate::Core.deplate
EOS
    
end

f = File.join(File.dirname(__FILE__), f)
File.open(f, "w") do |io|
    io.puts t
end

File.chmod(0755, f)

# vim: ff=unix
