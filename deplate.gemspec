#!/usr/bin/env ruby

require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name         = 'deplate'
  if ENV['TESTING']
      s.version  = `deplate --microversion`.chomp
  else
      s.version  = `deplate --version`.chomp
  end
  s.author       = 'Tom Link'
  s.email        = 'micathom AT gmail com?subject=deplate'
  s.homepage     = 'http://deplate.sourceforge.net'
  s.summary      = 'Convert wiki-like markup to latex, docbook, html, or html-slides'
  s.description  = <<EOF
deplate is a ruby based tool for converting documents written in an 
unobtrusive, wiki-like markup to LaTeX, HTML, "HTML slides", or docbook.  
It supports page templates, embedded LaTeX code, footnotes, citations, 
bibliographies, automatic generation of an index, table of contents etc.  
It can be used to create web pages and (via LaTeX or Docbook) 
high-quality printouts from the same source. deplate probably isn't 
suited for highly technical documents or documents that require a 
sophisticated graphical layout. For other purposes it should work fine.

deplate aims to be modular and easily extensible. It is the accompanying 
converter for the Vim viki plugin. In the family of wiki engines, the 
choice of markup originated from the emacs-wiki.
EOF
  s.platform     = Gem::Platform::RUBY
  s.require_path = 'lib'
  # s.autorequires = ["deplate.rb", "ps2ppm.rb"]
  # s.autorequire  = 'deplate.rb'
  s.rubyforge_project = 'deplategem'
  s.has_rdoc     = true
  s.rdoc_options << '--main' << 'README.TXT'
  # s.files        = Dir.glob("{bin,man,lib,docs}/**/*").delete_if do |item|
  s.files        = Dir.glob('{bin,etc,man,lib}/**/*').delete_if do |item|
      [
          '.svn',
          'CVS',
          '.cvsignore',
          '.lvimrc',
          'tags',
          'metaconfig',
          'setup.rb',
          'post-install.rb',
          'pre-setup.rb',
          'deplate.exy',
      ].any? do |w| 
          item.include?(w)
      end
  end
  s.extra_rdoc_files = [
      'README.TXT',
      'AUTHORS.TXT',
      # 'NEWS.TXT',
      # 'CHANGES.TXT',
      'LICENSE.TXT',
      # 'TODO.TXT',
      # 'VERSION.TXT',
  ]
  s.files += s.extra_rdoc_files
  s.bindir = 'bin'
  s.executables = ['deplate']
  s.default_executable = 'deplate'
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end
