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
      new(filename, reader, Set(String).new, stringpool)
    end
     
    def initialize(filename : String, reader : Char::Reader, @consts : Set(String), stringpool : StringPool? = nil) 
      super(filename, reader, stringpool)
      @method_nesting = 0
      @block_nesting  = 0
      @symtable       = [SymTable.new]
      @stop_on_do     = false
      @temp_serial    = 0
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
        skip_end
        body << parse_expression
        next_token_skip_end
      end
      check :EOF
      body
    end

    def is_assignable?(node)
      case node 
      when Assign 
        if is_assignable? node.right 
          true 
        else 
          false 
        end
      when Call 
        !node.has_parenthesis? && ( node.name == "[]" ||
          (node.name.ends_with?("=")) ) 
      else 
        false 
      end
    end

    def parse_assign 
      if @token.type == :EOF 
        return Noop.new 
      end

      exp = parse_expression
      skip_space

      if @token.type == :":="
        location = @token.location
        if is_assignable? exp 
          next_token_skip_space_or_newline
          right = parse_op_assign
          case exp 
          when Call 
            exp.name += "="
            if exp.args
              exp.args.not_nil! << right
            else 
              exp.args = [right] of Node
            end
          when Assign 
            exp.right = Assign.new(exp.right, right).at location
          else 
            exp = Assign.new(exp, right).at location
          end
        else 
          unexpected_token :EOL, :";"
        end
      end 
      return exp
    end

    def parse_expression(node = nil)
      location = @token.location
      exp = parse_op_assign
      parse_expression_suffix(exp, location) 
    end

    def parse_expression_suffix(atomic, location)
      while true
        case @token.type 
        when :SPACE 
          next_token 
        when :IDENT 
          case @token.value 
          when :if 
            atomic = parse_expression_suffix(location) { |cond|    If.new(cond, atomic) }
          when :while 
            atomic = parse_expression_suffix(location) { |cond| While.new(cond, atomic) }
          when :until
            atomic = parse_expression_suffix(location) { |cond| Until.new(cond, atomic) }
          else 
            break 
          end
        when :")", :",", :EOL, :EOF 
          break 
        else 
          break
        end 
      end 
      return atomic
    end 

    def parse_expression_suffix(location)
      enable_regex
      next_token_skip_end
      exp = parse_op_assign
      exp = yield exp 
      exp.at location 
      return exp
    end

    def parse_op_assign(allow_ops = true, allow_suffix = true)
      location = @token.location 

      atomic = parse_ternary_if 
      
      while true 
        case @token.type 
        when :SPACE 
          next_token
        when :IDENT 
          unexpected_token unless allow_suffix
          break
        when :":="
          enable_regex
          break unless is_assignable? atomic
          
          if atomic.is_a? Call 
            if atomic.name == "[]"
              atomic.name == @stringpool.get "[]="
            else 
              atomic.name = "#{atomic.name}="
            end  
            if !atomic.args 
              atomic.args = [] of Node 
            end 
            next_token_skip_space_or_newline
            atomic.args.not_nil! <<  parse_op_assign 
          else 
            if atomic.is_a? ConstDef 
              # lc_bug("ConstDef node should never be reached")
            end 

            if atomic.is_a?(Variable) && atomic.name == "self"
              parser_raise("Can't change value of self", location)
            end  

            if atomic.is_a?(Variable) && atomic.type.unknown?
              register_id atomic.name, ID::LOCAL_V
              atomic.type = ID::LOCAL_V
            end

            location = @token.location
            next_token_skip_space_or_newline
            
            value  = parse_op_assign
            atomic = Assign.new(atomic, value).at location   
          end  
        when :"+=", :"-=", :"*=", :".*=", :"**=", :"/=", :"\\=", :"%=", :"&&=", :"||=", :"&=", :"|="
          
          location = @token.location
          unexpected_token unless allow_ops

          break unless is_assignable? atomic

          if atomic.is_a?(Namespace) || atomic.is_a?(ConstDef)
            parser_raise("Can't reassign a constant", location)
          end 

          if atomic.is_a?(Variable) && atomic.name == "self"
            parser_raise("Can't change value of self", location)
          end 

          method = @stringpool.get(@token.type.to_s.rstrip("="))

          enable_regex
          next_token_skip_space_or_newline
          exp = parse_assign
          atomic = OpAssign.new(atomic, method, exp).at location  
        else 
          break 
        end
      end
      return atomic  
    end

    def parse_ternary_if 
      location  = @token.location
      condition = parse_range
      skip_space 
      while @token.type == :"?"
        check_void_value condition, location
        next_token_skip_space_or_newline
        true_c = parse_ternary_if
        skip_space_or_newline
        check :":"
        false_c = parse_ternary_if
        skip_space
        condition = If.new(condition, true_c, false_c).at location
      end 
      return condition
    end 

    def parse_range 
      location = @token.location
      atomic = parse_or
      case @token.type
      when :".."
        new_range(atomic,location)
      when :"..."
        new_range(atomic,location, inclusive: false)
      else 
        atomic 
      end
    end

    def new_range(left, location, inclusive = true)
      check_void_value left, location
      next_token_skip_space_or_newline
      check_void_expression_kw
      right = parse_or 
      return RangeLiteral.new(left, right, inclusive).at location
    end 

    macro def_op_parsing(name, next_op, node, operators)
      def parse_{{name.id}}
        skip_space
        location = @token.location
        left = parse_{{next_op.id}}
        while true 
          case @token.type
          when :SPACE
            next_token 
          when {{operators.id}}
            check_void_value left, location
            location = @token.location
            method   = @stringpool.get @token.type.to_s
            next_token_skip_space_or_newline

            right = parse_{{next_op.id}}
            left  = {{node.id}}.at location
          else 
            return left
          end
        end 
      end 
    end

    def_op_parsing :or, :and, "Or.new(left,right)", %(:"||")
    def_op_parsing :and, :equal, "And.new(left,right)", %(:"&&")
    def_op_parsing :equal, :comp, "Call.new(left, method, [right] of Node)", %(:"<", :"<=", :">", :">=")
    def_op_parsing :comp, :bin_or, "Call.new(left, method, [right] of Node)", %(:"=", :"==", :"!=", :"===", :"=~")
    def_op_parsing :bin_or, :bin_and, "Call.new(left, method, [right] of Node)", %(:"|", :"^")
    def_op_parsing :bin_and, :shift, "Call.new(left, method, [right] of Node)", %(:"&")
    def_op_parsing :shift, :add_or_sub, "Call.new(left, method, [right] of Node)", %(:"<<", :">>")
    def_op_parsing :add_or_sub, :mul_or_div, "Call.new(left, method, [right] of Node)", %(:"+", :"-")
    def_op_parsing :mul_or_div, :pow, "Call.new(left, method, [right] of Node)", %(:"*", :".*", :"/", :"\\\\")
    
    def parse_pow
      skip_space
      location = @token.location
      left = parse_prefix 
      while true 
        case @token
        when :SPACE
          next_token 
        when :"**"
          
          check_void_value left, location
          location = @token.location
          method   = @stringpool.get @token.type.to_s
          next_token_skip_space_or_newline

          right = parse_pow
          left  = Call.new(left, method, [right] of Node).at location
        else 
          return left
        end
      end 
    end

    def parse_prefix
      case @token.type
      when :"+", :"-", :"!", :"~"
        location = @token.location
        case @token.type
        when :"+", :"-"
          name = @stringpool.get "#{@token.type.to_s}@"
        else 
          name = @token.type.to_s 
        end
        next_token_skip_space_or_newline
        check_void_expression_kw
        receiver = parse_prefix
        return Call.new(receiver,name, nil).at location
      else
        return parse_atomic_with_suffix
      end
    end 

    def parse_atomic_with_suffix
      location = @token.location 
      atomic   = parse_atomic
      atomic   = parse_atomic_post atomic, location
      return atomic
    end 

    def parse_atomic
      case @token.type 
      when :IDENT, :CAPITAL_VAR
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
        when :true 
          disable_regex
          next_token
          TrueLiteral.new
        when :false
          disable_regex
          next_token 
          FalseLiteral.new
        else
          if @token.is_kw
            unexpected_token
            Noop.new
          else 
            is_capital = @token.type == :CAPITAL_VAR
            name = @token.value.to_s 
            if id_is?(name, ID::LOCAL_V)
              type = ID::LOCAL_V
            else 
              type = ID::UNKNOWN 
            end 
            disable_regex
            next_token 
            Variable.new(name, type, is_capital)
          end
        end
      when :INT, :FLOAT, :COMPLEX 
        type      = @token.type 
        value     = @token.value.to_s
        location  = @token.location
        disable_regex
        next_token
        NumberLiteral.new(value, type).at location
      when :SYMBOL 
        value = @token.value.to_s 
        disable_regex
        next_token
        SymbolLiteral.new(value)
      else
        unexpected_token
        Noop.new
      end
    end

    # Disables lexing of regexp delimiter after finishing
    def parse_stmts_delimited(token_t : Symbol)
      body = Body.new
      while @token.type != :EOF &&  @token.type != token_t
        skip_end
        body << parse_assign
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
      if @token.type == :IDENT
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

      return cls 
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

      return mod
    end

    def parse_ident
      name   = nil
      global = false
      if @token.type == :"::"
        global = true 
        next_token_skip_space_or_newline
      end
      check :IDENT, :CAPITAL_VAR 
      parse_ident_after_colons(@token.location, global)
    end 

    def parse_ident_after_colons(location, global)
      names = [] of String 
      names << @token.value.to_s
      next_token 
      while @token.type == :"::"
        next_token_skip_space_or_newline
        check :IDENT, :CAPITAL_VAR
        names << @token.value.to_s 
        next_token
      end 

      register_id names.last, ID::CONST 
      namespace = Namespace.new(names, global)
      namespace.at location 
      return namespace
    end 

    def parse_atomic_post(atomic : Node, location)
      while true
        case @token.type
        when :SPACE
          break
        when :EOL 
          case atomic 
          when ClassNode, ModuleNode, FunctionNode
            break 
          end 

          location = @token.location 
          next_token_skip_space_or_newline
          unless @token.type == :"."
            lex_restore_state(location)
            break 
          end
        when :"."
          check_void_value atomic, location  
          location = @token.location 
          next_token
          check_callable_name
          name = ((@token.value == "") ? @token.type : @token.value).to_s
          next_token

          space_consumed = false
          block          = nil
          if @token.type == :SPACE 
            disable_regex
            next_token
            space_consumed = true
          end

          case @token.type 
          when :":="
            next_token

            if @token.type == :"("
              if current_char == "*" 
                next_token_skip_space 
                arg = parse_call_arg 
                skip_space_or_newline 
                check :")"
                next_token
              else 
                arg = parse_op_assign
              end 
            else 
              skip_space_or_newline
              arg = parse_call_arg
            end

            atomic = Call.new(atomic, "#{name}=", [arg] of Node).at location 
            next
          when :"+=", :"-=", :"*=", :".*=", :"/=", :"\\=", :"%=", :"|=", :"&=", :"^=", :"**=", :"||=" 
            op_location = @token.location
            method = @stringpool.get @token.type.to_s.rstrip("=")
            next_token_skip_space_or_newline
            value  = parse_op_assign
            call   = Call.new(atomic, name).at location
            atomic = OpAssign.new(call, method, value).at op_location 
            next 
          else 
            call_args = preserve_stop_on_do {space_consumed ? parse_call_args_space_consumed : parse_call_args}
            if call_args 
              args       = call_args.args 
              named_args = call_args.named_args
              block      = call_args.block 
              block_arg  = call_args.block_arg 
              has_parenthesis = call_args.has_parenthesis
            else 
              args = named_args = block = block_arg = nil 
            end 
          end

          block = parse_block(block, @stop_on_do)
          if block && block_arg
            parser_raise("Both block arg and actual block given", location)
          end 
          has_parenthesis = 
          atomic = Call.new(atomic, name, args, named_args, block_arg, block, !!has_parenthesis).at location
        when :"[]"
          check_void_value atomic, location
          location = @token.location 
          disable_regex
          next_token_skip_space
          name = @stringpool.get "[]"
          atomic = Call.new(atomic, name).at location      
        when :"["
          check_void_value atomic, location
          location = @token.location
          next_token_skip_space_or_newline
          call_args = preserve_stop_on_do { parse_call_args_space_consumed(check_plus_minus: false, allow_curly: true, end_tk: :"]") }
          skip_space_or_newline
          check :"]"
          disable_regex
          next_token_skip_space

          if call_args
            args       = call_args.args 
            named_args = call_args.named_args
            block_arg  = call_args.block_arg
            block      = call_args.block
          end 

          block = parse_block(block, @stop_on_do)
          if block && block_arg
            parser_raise("Both block arg and actual block given", location)
          end 
          name = @stringpool.get "[]"
          atomic = Call.new(atomic, name, (args || [] of Node), named_args, block_arg,  block).at location
        else 
          break
        end  
      end
      return atomic
    end

    record CallArgs,
      args       : Array(Node)?,
      named_args : Array(NamedArg)?,
      block_arg  : Node?,
      block      : Block?,
      has_parenthesis : Bool = true

    def parse_call_args(allow_curly = false, control = false)
      case @token.type 
      when :"("
        enable_regex

        args = [] of Node 
        @stop_on_do = false 
        double_splat = false 

        next_token_skip_space_or_newline
        while @token.type != :")"
          if block_var_follows?
            return parse_call_block_arg(args, check_par: true)
          end 
          if @token.type == :IDENT && current_char == ':'
            return parse_named_call_args(args, allow_newline: true)
          else 
            arg = parse_call_arg(double_splat)
            args << arg 
            double_splat = arg.is_a? DoubleSplat
          end 
          
          skip_space_or_newline
          if @token.type == :","
            enable_regex
            next_token_skip_space_or_newline
          end            
        end
        check :")"
        disable_regex
        next_token_skip_space
        return CallArgs.new args, nil, nil, nil, false
      when :SPACE 
        disable_regex
        next_token
        if @stop_on_do && @token.keyword? :do 
          return nil
        end 

        if control && @token.keyword? :do 
          unexpected_token
        end 
        puts "parsing args space consumed"
        return parse_call_args_space_consumed(check_plus_minus: true, allow_curly: allow_curly, control: control) 
      else 
        nil
      end 
    end

    def parse_call_args_space_consumed(check_plus_minus = true, allow_curly = false, control = false, end_tk = :")")
      case @token.type 
      when :"&"
        return nil if current_char.ascii_whitespace?
      when :"+",:"-"
        if check_plus_minus 
          return nil if current_char.ascii_whitespace?
        end
      when :"{"
        return nil unless allow_curly
      when :"*", :"**", :"::"
        return nil if current_char.ascii_whitespace?
      when :IDENT, :INT, :FLOAT, :COMPLEX, :"$", :"$!", :SYMBOL, :CLASS_VAR, :INSTANCE_VAR, :CAPITAL_VAR, :"[", :"[]", :"(", :":\"", :"'", :"\"", :"!"
        # nothing 
      else 
        return nil 
      end

      case @token.value
      when :if, :while, :until
        return nil unless next_comes_colon_space?
      end 

      args = [] of Node 
      @stop_on_do = true unless control 

      double_splat = false 
      while @token.type != :EOL && @token.type != :";" && @token.type != :EOF && @token.type != :":" && @token.type != end_tk
        
        if block_var_follows?
          return parse_call_block_arg(args, check_par: false)
        end 
        
        if (@token.type == :IDENT || @token.type == :CAPITAL_VAR) && current_char == ':'
          return parse_named_call_args(args, allow_newline: false)
        else 
          arg = parse_call_arg(double_splat)
          args << arg 
          double_splat = arg.is_a? DoubleSplat
        end 

        skip_space 

        if @token.type == :","
          location = @token.location
          enable_regex
          next_token_skip_space_or_newline
          parser_raise("Invalid trailing comma", location) if @token.type == :EOF
        else 
          break 
        end
      end 
      return CallArgs.new args, nil, nil, nil, false
    end

    def parse_named_call_args(args, allow_newline = true)
      named_args = [] of NamedArg

      while true 
        location = @token.location
        if named_args_start? 
          name = @token.value.to_s 
          next_token 
        else 
          parser_raise "Expected named arg, not #{@token.type}", location
          name = ""
        end

        if named_args.any? { |arg| arg.name == name }
          parser_raise "Duplicated named argument", location
        end 
        
        check :":"
        next_token_skip_space_or_newline

        value = parse_op_assign
        named_args << NamedArg.new(name, value).at location

        skip_space
        skip_space_or_newline if allow_newline
        if @token.type == :","
          next_token_skip_space_or_newline
          if @token.type == :")" || @token.type == :"]" || @token.type == :"&"
            break 
          end 
        else 
          break 
        end  
      end 

      if block_var_follows? 
        return parse_call_block_arg(args, check_par: allow_newline, named_args: named_args)
      end 
      check :")" if allow_newline

      if allow_newline
        skip_space_or_newline
      else 
        skip_space
      end 
      return CallArgs.new args, named_args, nil, nil, false     
    end 

    def parse_call_arg(double_splat = false)
      splat = nil
      case @token.type
      when :"*"
        unless current_char.ascii_whitespace?
          if double_splat
            parser_raise "Splat not allowed after double splat", @token.location
          end 
          splat = :single
          next_token
        end 
      when :"**"
        unless current_char.ascii_whitespace?
          splat = :double
          next_token
        end 
      end 

      arg = parse_op_assign 

      case splat
      when :single 
        arg = Splat.new(arg)
      when :double 
        arg = DoubleSplat.new(arg)
      end

      return arg
    end 

    def parse_call_block_arg(args, check_par, named_args = nil)
      location = @token.location 
      
      block_arg_name = next_temp_var
      obj = Variable.new(block_arg_name, ID::LOCAL_V)

      next_token_skip_space
      if @token.type == :SYMBOL
        name = @token.value.to_s.lstrip(":")
        next_token
        call = Call.new(obj, name)
        obj = Block.new([obj] of Node, -1, Body.new << call, SymTable.new)
      elsif @token.type == :IDENT || @token.type == :CAPITAL_VAR
        obj = parse_op_assign
      else 
        unexpected_token :SYMBOL, :IDENT, :CAPITAL_VAR
        obj = nil
      end 

      if check_par
        skip_space_or_newline
        check :")"
        next_token_skip_space
      else 
        skip_space
      end
      return CallArgs.new args, named_args, obj, nil, check_par
    end 

    def parse_block(block, stop_on_do) 
      if @token.keyword? :do 
        return block if stop_on_do

        parser_raise "Block already specified", @token.location if block 
        
        parse_block2
      else 
        skip_space
        parse_curly_block(block)
      end 
    end 

    def parse_curly_block(block)
      if @token.type == :"{"
        parser_raise "Block already specified", @token.location if block
        parse_block2 
      else 
        block 
      end
    end

    def parse_block2
      if @token.keyword? :do
        next_token_skip_space_or_newline
        check :"{"
      elsif @token.type != :"{"
        return nil 
      end
      push_symtab
      @block_nesting += 1
      location = @token.location
      enable_regex
      next_token_skip_space_or_newline

      if @token.type == :"|"
        block_arg   = [] of Node 
        arg_names   = [] of String 
        splat_index = nil
        index       = 0
        
        next_token_skip_space_or_newline
        while @token.type != :"|" && @token.type != :EOF 
          if @token.type == :"*"
            if splat_index
              parser_raise "Splat block argument already defined", @token.location
            end 
            splat_index = index 
            next_token
          end 
          
          case @token.type
          when :IDENT, :CAPITAL_VAR
            arg_name = @token.value.to_s 
            if arg_names.includes? arg_name
              parser_raise "Duplicated block argument `#{arg_name}'", @token.location
            end 
            arg_names << arg_name
          when :UNDERSCORE 
            arg_name = "_"
          else 
            unexpected_token :IDENT, :CAPITAL_VAR
            arg_name = ""
          end
          register_id arg_name, ID::LOCAL_V
          var = Variable.new(arg_name, ID::LOCAL_V)
          next_token_skip_space

          if @token.type == :":="
            if index == splat_index
              unexpected_token :",", :"|"
            end
            loc = @token.location
            next_token_skip_space_or_newline
            value = parse_or 
            var = Assign.new(var, value).at loc 
            skip_space
          end
          
          block_arg << var 

          if @token.type == :","
            next_token_skip_space_or_newline
          end

          index += 1
        end 
        check :"|"
        next_token_skip_end
      end 

      body = Body.new 

      while @token.type != :"}" && @token.type != :EOF 
        body << parse_expression
      end 
      check :"}"
      next_token
      @block_nesting -= 1
      return Block.new(block_arg, splat_index || -1, body, pop_symtab).at location
    end

    def named_args_start?
      return (@token.type == :IDENT || @token.type == :CAPITAL_VAR) && current_char == ':' && peek_char != ':'
    end 

    def next_comes_colon_space?
      pos = current_pos 
      comes_colon_space = false
      if next_char_no_column_increment == ':'
        if peek_char == ' '
          comes_colon_space = true 
        end 
      end 
      self.set_current_pos = pos 
      return comes_colon_space
    end 

    def block_var_follows?
      @token.type == :"&" && !current_char.ascii_whitespace?
    end

    def preserve_stop_on_do(val = false)
      stop_on_do = @stop_on_do
      @stop_on_do = val 
      val = yield 
      @stop_on_do = stop_on_do
      return val 
    end 

    def check(*token_t, kw = false)
      if !token_t.includes?(@token.type) || @token.is_kw != kw
        unexpected_token
      end 
    end

    def check_void_value(exp, location)
      if exp.is_a? ControlExpression
        parser_raise "Void value expression", location
      end 
    end

    def check_void_expression_kw
      case @token.type 
      when :IDENT
        case @token.value 
        when :return, :next # :break 
          parser_raise "Void value expression", @token.location
        end 
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

    def next_temp_var
      return "__temp#{@temp_serial += 1}"
    end

    def unexpected_token(*args)
      msg = String.build do |io|
        io << "Unexpected "
        if @token.is_kw
          io << "keyword "
          io << @token.value.to_s 
        elsif @token.type == :EOF 
          io << "end of file"
        else 
          io << "token "
          io << @token.type.to_s
        end 

        if !args.empty? 
          io << ", expecting: "
          io << args.join(" or ")
        end
        io << '\n'
        io << "Line: " << @token.location.line << ':' << @token.location.column
        io << '\n'
        io << "In: " << @filename
      end 
      # Exec.lc_raise(LcSyntaxError, msg)
      raise Exception.new msg
    end

    def parser_raise(msg, location)
      puts "Syntax error detected"
    end

  end

end