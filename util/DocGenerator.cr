# Copyright (c) 2017-2023 Massimiliano Dal Mas
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "set"
require "colorize"

module DocGenerator
  def self.scan_directory(directory)
    return Dir.children(directory).map! { |d| File.expand_path(d, directory)}
  end

  class DocGenerator

    URL = "https://github.com/LinCAS-lang/LinCAS/tree/master/src/Internal"

    API_METHOD_DEF = /def.*self\.(?<name>lc_[a-zA-Z_]*)/
    MODULE_DEF     = /(?<var>@@lc[a-zA-Z_]*).*=.*lc_build_internal_(?<type>class|module)\("(?<name>[a-zA-Z_]*)"[, ]*(?<super>@@lc_[a-zA-Z_]*)?.*\)/
    METHOD_DEF     = /define_method\([ ]*(?<klass>(@@lc)?[a-zA-Z_]*)[, ]*"(?<name>.*)".*(?<method>lc[a-zA-Z_]*).*\)/
    SINGLETON_METHOD_DEF = /define_singleton_method\(.*(?<klass>(@@lc)?[a-zA-Z_]*)[, ]*"(?<name>.*)".*(?<method>lc[a-zA-Z_]*).*\)/
    ALIAS_DEF      = /alias_method_str\([ ]*(?<klass>(@@lc)?[a-zA-Z_]*)[, ]*"(?<name>.*)"[, ]*"(?<alias>.*)".*\)/

    
    def self.generate_doc(files : Array(String), output_dir : String, version : String)
      DocGenerator.new(files, File.expand_path(output_dir), version).generate_doc
    end

    record MethodEntry,
      name : String ,
      doc  : String,
      file : String,
      line : Int32

    class ModuleDef
      getter name, type, super, doc, file, methods, singleton_methods
      def initialize(
        @var_name : String, # For debug only
        @name     : String,
        @type     : Symbol,
        @super    : String,
        @doc      : String,
        file      : String
      )
        @file = Set(String).new << File.basename(file)
        @methods = @singleton_methods = {} of String => MethodDef
      end
      
      def initialize(@var_name : String)
        @name    = ""
        @type    = :Undefined
        @super   = ""
        @doc     = ""
        @file    = Set(String).new
        @methods = @singleton_methods = {} of String => MethodDef
      end

      def define(
        @name  : String,
        @type  : Symbol,
        @super : String,
        @doc   : String,
        file   : String
      )
        @file << File.basename(file)
      end

      def set_method(m_name, definition, _file)
        @file << File.basename(_file)
        @methods[m_name] = MethodDef.new(definition)
      end

      def set_singleton_method(name, definition)
        @singleton_methods[name] = MethodDef.new(definition)
      end

      def set_alias(m_name, aliased)
        begin
          p_def = @methods[m_name]
          @methods[aliased] = p_def.copy_with(other_ref: m_name, is_alias: true)
        rescue
          raise "Failed to set alias #{m_name.inspect}  => #{aliased} for #{@name}"
        end
      end

      def inspect
        String.build do |io|
          io.puts "#{type} in #{@var_name}:#{@file.to_a}"
          @methods.each do |k, m|
            io.puts "  #{k} => #{m.api_name}"
          end
        end
      end

      record MethodDef,
        api_name : String,
        other_ref = "",
        is_alias  = false
    end

    def initialize(@files : Array(String), @output_dir : String, @version : String)
      @methods = {} of String => MethodEntry
      @modules = {} of String => ModuleDef
      @line = 0
    end

    def generate_doc
      @files.each do |file|
        if File.exists?(file) && File.file?(file) && File.basename(file) != "Symbolic.cr"
          print "Scanning #{File.basename(file)}..."
          scan_file file
          puts "Ok".colorize(:green)
        end
        @line = 0
      end
      dir = "#{@output_dir}/core"
      Dir.mkdir(dir) unless Dir.exists? dir
      generate_index_table
      generate_modules_doc
    end

    protected def readline(file)
      line = file.gets
      if line
        @line += 1
        line = line.lstrip ' '
      end
      return line
    end

    protected def scan_file(filename)
      file = File.open(filename)
      while line = readline file
        doc = ""
        if line.starts_with? '#'
          doc = String.build do |io|
            io.puts line.not_nil!.lstrip('#')
            while (line = readline file) && line.starts_with? '#'
              io.puts line.lstrip('#')
            end
          end
        end

        # Skip any @[AlwaysInline]
        if line && line.starts_with? "@["
          line = readline file
        end

        case line
        when nil
          break
        when .starts_with? /def.*self.lc_/
          match = API_METHOD_DEF.match line
          if (name = match.try &.["name"])
            @methods[name] = MethodEntry.new(name, doc, filename, @line)
          else
            raise "Failed to get function definition name"
          end
        when .starts_with? /@@lc_/
          match = MODULE_DEF.match line
          if match
            var   = match["var"]
            type  = match["type"]
            name  = match["name"]
            super = match["super"]?
            type  = type == "class" ? :Class : :Module
            if m_def = @modules[var]?
              if m_def.name.empty? && m_def.type == :Undefined
                m_def.define(name, type, super || "", doc, filename)
              else
                raise "Class rdefinition detected ('#{line}')"
              end
            else
              @modules[var] = ModuleDef.new(var, name, type, super || "", doc, filename)
            end
          end
        when .starts_with? /define_method/
          match = METHOD_DEF.match line
          if match
            klass  = match["klass"]
            name   = match["name"]
            method = match["method"]
            m_def = @modules[klass]? || (@modules[klass] = ModuleDef.new(klass))
            m_def.set_method(name, method, filename)
          else
            raise "Failed to get method definition ('#{line}')"
          end
        when .starts_with? /define_singleton_method/
          match = SINGLETON_METHOD_DEF.match line
          if match
            klass  = match["klass"]
            name   = match["name"]
            method = match["method"]
            m_def = @modules[klass]? || (@modules[klass] = ModuleDef.new(klass))
            m_def.set_singleton_method(name, method)
          else
            raise "Failed to get singleton method_definition ('#{line}')"
          end
        when .starts_with? /alias_method_str/
          match = ALIAS_DEF.match line
          if match
            klass = match["klass"]
            name  = match["name"]
            alias_name = match["alias"]
            @modules[klass].set_alias(name, alias_name)
          else
            raise "Failed to get method alias definition ('#{line}')"
          end
        end
      end
      file.close
    end

    protected def generate_index_table
      print "\nGenerating summary..."
      modules = @modules.values.sort_by! &.name
      File.open("#{@output_dir}/SUMMARY.md", "w+") do |io|
        io << "* Version: #{@version}\n"
        modules.each do |mod|
          if !(mod.type == :Undefined)
            io << "  * [#{mod.name} [#{mod.type}]](core/#{mod.name}.html)\n"
          else
            puts "Warning: undefined module found:".colorize :yellow
            puts mod.inspect
          end
        end
      end
      puts "Ok".colorize(:green)
    end

    protected def generate_modules_doc
      @modules.each do |_, mod|
        next if mod.type == :Undefined
        print "GEnerating documentation for #{mod.type}: #{mod.name}..."
        File.open("#{@output_dir}/core/#{mod.name}.md", "w+") do |io|
          io << '#' << mod.type << ':' << ' ' << mod.name << '\n'
          io.puts mod.doc
          io.puts "## Defined in"

          files = mod.file.map { |name| "[#{name}](#{URL}/#{name})"}
          io.puts files.join(", ")
          io.puts "---"
          io.puts "## Index:"
          s_methods = mod.singleton_methods.map { |name, _| "  * [::#{name}]()"}
          methods = mod.methods.map { |name, _| "  * [##{name}]()"}
          io.puts s_methods.join '\n'
          io.puts methods.join '\n'
          io.puts "---"
          print_methods io, mod.singleton_methods, "::"
          print_methods io, mod.methods, "#"
        end
        puts "Ok".colorize :green
      end
    end

    protected def print_methods(io, methods, type)
      methods.each do |name, method|
        begin
          io.puts "### #{type}#{name}\n"
          entry = @methods[method.api_name]
          io << entry.doc << "\n\n"
          io.puts "[see definition](#{URL}/#{File.basename(entry.file)}#L#{entry.line})\n\n---\n"
        rescue e
          io.puts "\n---\n"
          puts "Warning: #{e.inspect}".colorize :yellow
        end
      end
    end
  end

  def self.run
    if dir = ARGV[0]?
      dir        = File.expand_path(dir)
      version    = File.read("#{dir}/VERSION").chomp
      output_dir = "#{dir}/doc/#{version}"
      Dir.mkdir_p(output_dir) unless Dir.exists? output_dir

      directories = scan_directory "#{dir}/src/Internal"
      DocGenerator.generate_doc directories, output_dir, version
    end
  end

  at_exit { 
    begin
      run
    rescue e
      puts e.inspect_with_backtrace
    end
  }
end