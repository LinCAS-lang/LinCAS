# Copyright (c) 2020 Massimiliano Dal Mas
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

module LinCAS
  class Parser < Lexer
     
    def self.new(filename : String, stringpool : StringPool? = nil)
      reader = Char::Reader.new(File.read(filename))
      new(filename, reader, stringpool)
    end

    def self.new(filename : String, code : String, stringpool : StringPool? = nil)
      reader = Char::Reader.new(code)
      new(filename, reader, stringpool)
    end
     
    def initialize(filename : String, reader : Char::Reader, stringpool : StringPool? = nil) 
      super(filename, reader, stringpool)
      @method_nesting = 0
      @block_nesting  = 0
      @symtable       = [SymTable.new]
    end

    def push_symtab
      @symtable.push SymTable.new 
    end 

    def pop_symtab
      @symtable.pop 
    end

    def register_id(name, id_t)
      entry = @symtable.last[name]? 
      if !entry
        entry = SymTable::Entry.new 
        @symtable.last[name] = entry 
      end
      entry << id_t 
      true 
    end

    def id_is?(name, type)
      entry = @symtable.last[name]?
      return false unless entry 
      return entry.includes? type
    end 

    def parse
      enable_regex 
      next_token_skip_end
      stmts = parse_statements
      return Program.new(filename, stmts) 
    end

    def parse_statements
      body = Body.new
      while @token.type != :EOF
        body << parse_statement
        next_token_skip_end
      end
      body
    end

    def parse_statement
      case @token.type 
      when :IDENT
        case @token.value 
        when :class
          parse_class
        when :module
          parse_module
        # when :public, :protected, :private, :let
        # when :try
        # when :if
        # when :while
        # when :do
        # when :for
        # when :select
        # when :const
        else
          if @token.is_kw
            unexpected_token
            Noop.new
          else 
            parse_expression
          end
        end
      else
        parse_expression
      end
    end

    # Disables lexing of regexp delimiter after finishing
    def parse_stmts_delimited(token_t : Symbol)
      body = Body.new
      while @token.type != :EOF &&  @token.type != token_t
        skip_end
        body << parse_statement
      end
      check token_t
      disable_regex
      next_token
      body
    end

    def parse_class
      location = @token.location
      next_token_skip_space 
      name   = parse_ident
      parent = nil 
      body   = nil
      skip_space_or_newline
      if @token.type = :IDENT
        if @token.is_kw && @token.value == :inherits
          next_token_skip_space_or_newline
          parent = parse_ident
        else 
          unexpected_token :inherits, :"{"
        end 
      end 
      skip_end 
      push_symtab
      if @token.type == :"{"
        next_token_skip_end
        body = parse_stmts_delimited :"}"
      else 
        unexpected_token :"{"
      end
      cls = ClassNode.new(name, parent || Noop.new, body || Body.new, pop_symtab)
      cls.at location
      
      return parse_call_or_op_post cls
    end

    def parse_module
      location = @token.location
      next_token_skip_space 
      name = parse_ident
      body = nil 
      skip_end 
      push_symtab
      if @token.type == :"{"
        next_token_skip_end
        body = parse_stmts_delimited :"}"
      else 
        unexpected_token :"{"
      end
      mod = ModuleNode.new(name, body || Body.new, pop_symtab)
      mod.at location 

      return parse_call_or_op_post mod
    end

    def parse_ident
      name   = nil
      global = false
      if @token.type == :"::"
        global = true 
        next_token_skip_space_or_newline
      end
      check :IDENT 
      parse_ident_after_colons(@token.location, global)
    end 

    def parse_ident_after_colons(location, global)
      names = [] of String 
      names << @token.value.to_s
      next_token 
      while @token.type == :"::"
        next_token_skip_space_or_newline
        check :IDENT
        names << @token.value.to_s 
        next_token
      end 

      register_id names.last, ID::CONST 
      namespace = Namespace.new(names, global)
      namespace.at location 
      return namespace
    end 

    def parse_call_or_op_post(node : Node)
      node
      # parse_exp(parse_call_post(node))
    end 

    def parse_call_post(atomic : Node)
      while true
        case @token.type
        when :SPACE 
          break
        when :EOL 
          case atomic 
          when ClassNode, ModuleNode, FunctionNode
            break 
          end 
          next_token_skip_space_or_newline
          break unless @token.type == :"."
        when :"."
          location = @token.location 
          next_token
          check_callable_name
          name = ((@token.value == "") ? @token.type : @token.value).to_s
          next_token
          case @token.type 
          when :"("
            args = parse_call_args(delimited: true)
          when :SPACE 
            restore_pt = @token.location 
            next_token_skip_space
            args = parse_call_args(restore_point: restore_pt, max: 1)
          when :":="
            name = "#{name}="
          else 
            args = nil
          end
          atomic = Call.new(atomic, name, args)
          atomic.at location
        when :"[]"
        when :"[]="
        when :"["
        end  
      end
      return atomic
    end

    def parse_call_args(delimited = false, restore_point = nil)
      args = 
      if delimited 
        case @token.type 
        when :"("
          end_delimiter = :")"
        when :"["
          end_delimiter = :"]"
        else 
          lc_bug("Unknown arg delimiter #{@token.type}")
        end 
      else 
        
      end
      if restore 
        lex_restore_state restore_point
      end
    end

    def parse_expression(node = nil)
      Noop.new
    end

    def check(token_t, kw = false)
      if @token.type != token_t || @token.is_kw != kw
        unexpected_token
      end 
    end

    def check_callable_name
      names = {
        :"+",
        :"-",
        :"*",
        :"**",
        :"/",
        :"\\",
        :"|",
        :"||",
        :"&",
        :"&&",
        :"^",
        :">",
        :">=",
        :"<",
        :"<=",
        :"=",
        :"==",
        :"===",
        :"<<",
        :">>",
        :"%",
        :"!"
      } 
      unless @token.type == :IDENT || names.includes? @token.type
        unexpected_token :IDENT, *names 
      end 
    end 

    def unexpected_token(*args)
      
    end

  end

end