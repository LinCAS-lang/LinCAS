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

require "string_pool"

module LinCAS
  class Lexer #< Reader
    getter filename

    @stringpool : StringPool

    def self.new(filename : String, code : String, stringpool : StringPool? = nil)
      new(filename, Char::Reader.new(code), stringpool)
    end

    def initialize(@filename : String, @reader : Char::Reader, stringpool : StringPool? = nil) 
      @regex_enabled  = true
      @line           = 1i64
      @col            = 1
      @stringpool     = stringpool || StringPool.new
      @token          = Token.new
      @space_skipped  = true
    end

    def next_token
      @token.reset 

      while current_char == '#' || (current_char == '/' && peek_char == '*')
        skip_comment 
      end
      
      start =   current_pos
      space_skipped = false
      @token.location = current_location
      case current_char
      when '\0'
        @token.type = :EOF
      when '\n' 
        consume_newline
      when ' ', '\t'
        consume_space
        space_skipped = true
      when ';'
        next_char_and_token :";"
      when '('
        next_char_and_token :"("
      when ')'
        next_char_and_token :")"
      when '['
        case next_char
        when ']'
          if next_char == '='
            next_char_and_token :"[]="
          else 
            @token.type = :"[]"
          end
        else 
          @token.type = :"["
        end
      when ']'
        next_char_and_token :"]"
      when '{'
        @token.type = :"{"
        next_char
      when '}'
        next_char_and_token :"}" 
      when '|'
        case next_char
        when '|'
          if next_char == '='
            next_char_and_token :"||="
          else 
            @token.type = :"||" 
          end
        when '='
          next_char_and_token :"|="
        else
          @token.type = :|
        end
      when '"'
        delimiter_t = Token::DelimiterType.new(:"\"", current_char, true, true)
        @token.type = :"\""
        @token.delimiter_t = delimiter_t
        next_char
      when '\''
        delimiter_t = Token::DelimiterType.new(:"'", current_char, false, false)
        @token.type = :"'"
        @token.delimiter_t = delimiter_t
        next_char
      when ','
        next_char_and_token :","
      when '.'
        case next_char
        when '.'
          if peek_char != '*'
            case next_char
            when '.'
              next_char_and_token :"..."
            else
              @token.type = :".."
            end
          else 
            space_skipped = true 
            @token.type = :"."
          end
        when '*'
          case peek_char 
          when '=' 
            if @space_skipped
              next_char
              next_char :".*="
            else 
              space_skipped = true
              @token.type = :"."
            end
          else 
            if @space_skipped
              next_char :".*"
            else 
              space_skipped = true
              @token.type = :"."
            end
          end
        else
          @token.type = :"."
        end
      when '+'
        case next_char
        when '='
          next_char_and_token :"+="
        when '@'
          if !ident_start? peek_char
            next_char_and_token :"+@"
          else 
            @token.type = :"+"
          end
        else 
          @token.type = :"+"
        end
      when '-'
        case next_char
        when '='
          next_char_and_token :"-="
        when '@'
          if !ident_start? peek_char
            next_char_and_token :"-@"
          else 
            @token.type = :"-"
          end
        else 
          @token.type = :"-"
        end
      when '*'
        case next_char
        when '='
          next_char_and_token :"*="
        when '*'
          case next_char
          when '='
            next_char_and_token :"**="
          else 
            @token.type = :"**"
          end 
        else 
          @token.type = :"*"
        end
      when '/'
        if @regex_enabled
          delimiter_t = Token::DelimiterType.new(:REGEXP_D, current_char, false, true)
          @token.type = :REGEXP_D
          @token.delimiter_t = delimiter_t
          next_char
          return @token
        end
        case next_char
        when '='
          next_char_and_token :"/="
        else 
          @token.type = :"/"
        end
      when '\\'
        case next_char
        when '='
          next_char_and_token :"\\="
        else
          @token.type = :"\\"
        end
      when '^'
        case next_char
        when '='
          next_char_and_token :"^="
        else 
          @token.type = :"^"
        end 
      when '>'
        case next_char
        when '='
          next_char_and_token :">="
        when '>'
          next_char_and_token :">>"
        else 
          @token.type = :">"
        end 
      when '<'
        case next_char
        when '='
          next_char_and_token :"<="
        when '<'
          next_char_and_token :"<<"
        else 
          @token.type = :"<"
        end 
      when '%'
        if next_char == '='
          next_char_and_token :"%="
        else 
          @token.type = :"%"
        end
      when '!'
        if next_char == '='
          next_char_and_token :"!="
        else 
          @token.type = :"!" 
        end
      when '='
        case next_char
        when '='
          if next_char == '='
            next_char_and_token :"==="
          else 
            @token.type = :"=="
          end 
        when '>'
          next_char_and_token :"=>"
        else 
          @token.type = :"="
        end
      when '&'
        case next_char
        when '&'
          if next_char == '='
            next_char_and_token :"&&="
          else
            @token.type = :"&&" 
          end
        when '='
          next_char_and_token :"&="
        else 
          @token.type = :"&"
        end
      when ':'
        case next_char
        when '='
          if next_char == '='
            next_char_and_symbol start
          else
            @token.type = :":="
          end
        when '+', '-', '^', '\\', '/', '&', '%', '|', '!'
          next_char_and_symbol start
        when '*'
          if next_char == '*'
            next_char_and_symbol start
          else 
            symbol start
          end
        when ':'
          next_char_and_token :"::"
        when '['
          case next_char
          when ']'
            if next_char == '='
              next_char_and_symbol start
            else 
              symbol start
            end 
          else 
            @token.type = :":"
            self.set_current_pos = start + 1 
          end
        when '<'
          char = next_char
          if (char == '=') || (char == '<')
            next_char_and_symbol start
          else 
            symbol start
          end
        when '>'
          char = next_char
          if (char == '=') || (char == '>')
            next_char_and_symbol start
          else 
            symbol start
          end
        when '"'
          next_char_and_token :":\""
        else
          if ident_start? current_char
            while ident_part? next_char
              # do nothing
            end 
            if current_char == '?' || ((current_char == '!' || current_char == '=') && peek_char != '=')
              next_char
            end
            @token.type  = :SYMBOL
            @token.value = string_range_from_pool start + 1
            set_token_raw_from_start start
          else
            @token.type = :":"
          end
        end
      when '$'
        if next_char == '!'
          next_char_and_token :"$!"
        else 
          @token.type = :"$"
        end
      when '?'
        next_char_and_token :"?"
      when '0'
        scan_zero_number start
      when '1', '2', '3', '4', '5', '6', '7', '8', '9'
        scan_number start
      when '@'
        class_var = (next_char == '@') ? (next_char; true) : false
        if ident_start? current_char
          while ident_part? next_char
            # do nothing 
          end
          @token.type  = class_var ? :CLASS_VAR : :INSTANCE_VAR
          @token.value = string_range_from_pool(start)
        else 
          raw = string_range(start)
          #lex_raise()
        end
      else 
        if current_char.ascii_uppercase?
          while ident_part? next_char
            # do nothing 
          end 
          @token.type  = :CAPITAL_VAR 
          @token.value = string_range_from_pool start
        elsif ident_start? current_char
          scan_kw_or_ident start 
        else 
          #lex_raise()
        end 
      end
      @space_skipped = space_skipped
      @token
    end 

    def next_string_token(delimiter_t )
      @token.reset
      interpolation   = delimiter_t.interpolation
      escape          = delimiter_t.escape
      delimiter       = delimiter_t.delimiter
      start           = current_pos 
      @token.location = current_location
      if interpolation && (current_char == '#') && (peek_char == '{')
        next_char
        next_char
        @token.type = :"\#{"
        return @token
      end 
      if current_char == delimiter
        @token.type = delimiter_t.type 
        return @token
      end
      io = IO::Memory.new
      loop do 
        case current_char
        when '\0'
          #lex_raise()
        when '#'
          if interpolation && (peek_char == '{')
            break
          else 
            io << current_char
            next
          end
        when '\\'
          if escape 
            case next_char
            when 'a'
              io << '\a'
            when 'b'
              io << 'b'
            when 'n'
              io << '\n'
            when 'r'
              io << '\r'
            when 't'
              io << '\t'
            when 'v'
              io << '\v'
            when 'f'
              io << '\f'
            when 'e'
              io << '\e'
            when '\n'
              @line += 1
              @col   = 0
              while true
                char = next_char
                case char
                when '\0'
                 #lex_raise()
                when '\n'
                  @line += 0
                  @col   = 0
                when .ascii_whitespace?
                  # Continue
                else
                  break
                end
              end
            else 
              io << current_char
            end
          else 
            io <<  current_char
          end
        when delimiter
          break 
        else
          io << current_char
        end
        next_char
      end 
      @token.type = :STRING
      @token.value = io.to_s 
      @token
    end

    def scan_zero_number(start)
      case peek_char
      when '1', '2', '3', '4', '5', '6', '7', '8', '9'
        lex_warn "Number starting with zero"
        next_char
        scan_number current_pos
      when '.'
        scan_number start
      when 'i'
        next_char
        if !(ident_part? next_char)
          self.set_current_pos = start 
          scan_number start
        end
      else 
        scan_number start
      end
    end

    def scan_digits
      has_underscore = false
      while true
        char = next_char
        if char.ascii_number?
          # Nothing to do
        elsif char == '_'
          has_underscore = true
        else
          break
        end
      end
      return has_underscore
    end

    def scan_number(start)
      num_type       = :INT
      has_underscore = scan_digits

      case current_char
      when '.'
        if peek_char.ascii_number?
          num_type = :FLOAT
          has_underscore ||= scan_digits
        end
        case current_char
        when 'e', 'E'
          char = peek_char
          if char == '+' || char == '-'
            next_char
          end 
          if peek_char.ascii_number?
            has_underscore ||= scan_digits
          else 
            #lex_raise()
          end
          if (current_char == 'i') && !(ident_part? peek_char)
            num_type = :COMPLEX
            next_char
          end
        when 'i'
          if !(ident_part? peek_char)
            next_char
            num_type = :COMPLEX
          end
        end
      when 'i'
        if !(ident_part? peek_char)
          next_char
          num_type = :COMPLEX
        end
      when 'e', 'E'
        char = current_char
        if char == '+' || char == '-'
          next_char
        end 
        if peek_char.ascii_number?
          num_type = :FLOAT
          has_underscore ||= scan_digits
        else 
          #lex_raise()
        end
      end

      end_pos = current_pos 
      if end_pos - start == 1
        value = string_range_from_pool(start, end_pos)
      else  
        value = string_range(start, end_pos)
      end 
      value = value.delete('_') if has_underscore
      @token.type = num_type
      @token.value = value
      set_token_raw_from_start start
    end

    def scan_ident(start)
      while ident_part? current_char
        next_char
      end 
      if (current_char == '?' || current_char == '!') &&  peek_char != '='
        next_char 
      end    
      @token.value = string_range_from_pool start
      if @token.value == "_"
        @token.type = :UNDERSCORE 
      else 
        @token.type   = :IDENT  
      end 
      @token
    end

    def scan_kw_or_ident(start)
      case current_char
      when 'c'
        case next_char
        when 'a'
          case next_char 
          when 's'
            if (next_char == 'e')
              return check_kw start, :case 
            end 
          when 't'
            if (next_char == 'c') && (next_char == 'h')
              return check_kw start, :catch 
            end 
          end 
        when 'l'
          if (next_char == 'a') && (next_char == 's') && (next_char == 's')
            return check_kw start, :class
          end 
        when 'o'
          if (next_char == 'n') && (next_char == 's') && (next_char == 't')
            return check_kw start, :const 
          end
        end
      when 'd'
        if (next_char == 'o') 
          if peek_char == 'w'
            next_char
            if (next_char == 'n') && (next_char == 't') && (next_char == 'o')
              return check_kw start, :downto 
            end
          else 
            return check_kw start, :do 
          end
        end
      when 'e'
        if (next_char == 'l') && (next_char == 's')
          case next_char
          when 'e'
            return check_kw start, :else 
          when 'i'
            if next_char == 'f'
              return check_kw start, :elsif
            end            
          end
        end 
      when 'f'
        case next_char
        when 'o'
          if next_char == 'r'
            return check_kw start, :for 
          end
        when 'a'
          if (next_char == 'l') && (next_char == 's') && (next_char == 'e')
            return check_kw start, :false 
          end
        end
      when 'i'
        case next_char 
        when 'f'
          return check_kw start, :if
        when 'n'
          if (next_char == 'h') && (next_char == 'e') && (next_char == 'r') && (next_char == 'i') && (next_char == 't') && (next_char == 's')
            return check_kw start, :inherits 
          end
        end
      when 'l'
        if (next_char == 'e') && (next_char == 't')
          return check_kw start, :let 
        end
      when 'm'
        if (next_char == 'o') && (next_char == 'd') && (next_char == 'u') && (next_char == 'l') && (next_char == 'e')
          return check_kw start, :module 
        end
      when 'n'
        case next_char 
        when 'e'
          case next_char
          when 'w'
            return check_kw start, :new 
          when 'x'
            if next_char == 't'
              return check_kw start, :next 
            end
          end
        when 'u'
          if (next_char == 'l') && (next_char == 'l')
            return check_kw start, :null 
          end
        end 
      when 'p'
        case next_char 
        when 'r'
          case next_char
          when 'i'
            if (next_char == 'v') && (next_char == 'a') && (next_char == 't') && (next_char == 'e')
              return check_kw start, :private
            end
          when 'o'
            if (next_char == 't') && (next_char == 'e') && (next_char == 'c') && (next_char == 't') && (next_char == 'e') && (next_char == 'd')
              return check_kw start, :protected 
            end
          end
        when 'u'
          if (next_char == 'b') && (next_char == 'l') && (next_char == 'i') && (next_char == 'c')
            return check_kw start, :public 
          end
        end  
      when 'r'
        if (next_char == 'e') && (next_char == 't') && (next_char == 'u') && (next_char == 'r') && (next_char == 'n')
          return check_kw start, :return 
        end
      when 's'
        if (next_char == 'e') && (next_char == 'l')
          case next_char
          when 'f'
            return check_kw start, :self 
          when 'e'
            if (next_char == 'c') && (next_char == 't')
              return check_kw start, :select 
            end 
          end
        end
      when 't'
        case next_char
        when 'h'
          if (next_char == 'e') && (next_char == 'n')
            return check_kw start, :then 
          end
        when 'o'
          return check_kw start, :to
        when 'r'
          case next_char
          when 'y'
            return check_kw start, :try 
          when 'u'
            if next_char == 'e'
              return check_kw start, :true 
            end 
          end
        end
      when 'u'
        if (next_char == 'n') && (next_char == 't') && (next_char == 'i') && (next_char == 'l')
          return check_kw start, :until 
        end 
      when 'w'
        if (next_char == 'h') && (next_char == 'i') && (next_char == 'l') && (next_char == 'e')
          return check_kw start, :while 
        end
      when 'y'
        if (next_char == 'i') && (next_char == 'e') && (next_char == 'l') && (next_char == 'd')
          return check_kw start, :yield 
        end
      when '_'
        if next_char == '_'
          case next_char
          when 'F'
            if (next_char == 'I') && (next_char == 'L') && (next_char == 'E') && (next_char == '_') && (next_char == '_')
              return check_kw start, :__FILE__ 
            end
          when 'D'
            if (next_char == 'I') && (next_char == 'R') && (next_char == '_') && (next_char == '_')
              return check_kw start, :__DIR__ 
            end
          end
        end
      end
      scan_ident start 
    end 

    def check_kw(start, kw)
      if ident_part?(next_char) || current_char == '?' || current_char == '!'
        scan_ident start 
      else
        @token.type  = :IDENT 
        @token.value = kw
        @token.is_kw = true
      end
      @token
    end 

    def next_token_skip_end
      next_token
      skip_end
    end

    def next_token_skip_space 
      next_token
      while @token.type == :SPACE
        next_token
      end 
    end

    def next_token_skip_space_or_newline
      next_token
      skip_space_or_newline
    end

    def skip_space 
      while @token.type == :SPACE
        next_token
      end
    end

    def skip_space_or_newline 
      while (@token.type == :EOL) || (@token.type == :SPACE)
        next_token
      end
    end

    def skip_end 
      while (@token.type == :EOL) || (@token.type == :";") || (@token.type == :SPACE)
        next_token
      end
    end

    def lex_restore_state(location : Location)
      @col  = location.column
      @line = location.line
      self.set_current_pos = location.lex_pos
      next_token
    end  

    @[AlwaysInline]
    def set_current_pos=(pos)
      @reader.pos = pos
    end

    @[AlwaysInline]
    def current_pos 
      @reader.pos 
    end

    def current_char
      @reader.current_char 
    end

    def next_char 
      @col += 1
      @reader.next_char
    end

    def next_char_no_column_increment
      @reader.next_char 
    end

    def next_char(token_t)
      @token.type = token_t
      next_char
      @token
    end

    def next_char_and_token(t_type)
      @token.type = t_type
      next_char
    end

    def symbol(start)
      @token.type  = :SYMBOL
      end_pos      = current_pos 
      @token.value = string_range(start + 1)
      set_token_raw_from_start(start)   
    end

    def next_char_and_symbol(start)
      next_char
      symbol start
    end

    def peek_char
      @reader.peek_next_char
    end

    def skip_comment
      if current_char == '#'
        while next_char != '\n'
        end 
      else
        next_char
        while !(next_char == '*' && peek_char == '/')
          if current_char == '\n'
            @line += 1
            @col = 0
          end
        end
        next_char
        next_char
      end
    end

    def consume_space
      while {' ', '\t'}.includes? next_char
        # do nothing 
      end 
      @token.type = :SPACE
    end

    def consume_newline
      while current_char == '\n'
        @line += 1 
        next_char
      end 
      @col = 1 
      @token.type = :EOL
    end 

    def string_range(start_pos)
      string_range(start_pos,   current_pos)
    end

    def string_range(start_pos, end_pos)
      @reader.string.byte_slice(start_pos, end_pos - start_pos)
    end

    def string_range_from_pool(start_pos)
      string_range_from_pool(start_pos,   current_pos)
    end 

    def string_range_from_pool(start_pos, end_pos)
      @stringpool.get string_range(start_pos, end_pos)
    end

    def set_token_raw_from_start(start)
      @token.raw = string_range(start)
    end

    def ident_start?(char)
      char.ascii_letter? || char == '_' || char.ord > 0x9f
    end

    def ident_part?(char)
      ident_start?(char) || char.ascii_number?
    end

    @[AlwaysInline]
    def current_location
      Location.new(@line, @col, current_pos)
    end
        
    @[AlwaysInline]
    def enable_regex 
      @regex_enabled = true 
    end
        
    @[AlwaysInline]
    def disable_regex 
      @regex_enabled = false 
    end

    def lex_warn(msg)
      msg = String.build do |io|
        io << "Warning: " << msg << '\n'
        io << "Line: " << @line << ':' << @col << '\n'
        io << "In: " << @filename << '\n'
      end
    end 

    def lex_raise(error, msg)
      body = String.build do |io|
        io << msg << '\n'
        io << "Line:" << @line << ':' << @col << '\n'
        io << "In: " << @filename 
      end 
      Exec.lc_raise(error, body)
    end

   end
end