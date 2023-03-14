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
  class Disasm
    include Internal 

    @last_line : Int32 | Int64
    def initialize(@iseq : ISeq)
      @stack = [{@iseq, ""}]
      @lc         = -1
      @last_line  = -1
      @ident = ""
    end

    def disasm
      while !@stack.empty?
        @iseq, name = @stack.shift
        disasm_general(name)
        puts nil
      end
    end

    def disasm_general(name)
      reset_line
      type     = @iseq.type.to_s
      filename = @iseq.filename
      iseq_name = name == "" ? "#{type}" : "#{type}:#{name}"
      puts "#{@ident}#{iseq_name}>#{"="* (79 - type.size)}",
           "#{@ident}file: #{filename}",
           "#{@ident}local table: (size: %s, argc: %s, [opt: %s splat: %s, kw: %s, kwsplat: %s, block: %s])" %
           format_arg_info(@iseq)

      print_catchtbl(@iseq.catchtable)
      print_symtable(@iseq.symtab)
      print_encoded(@iseq.encoded)
    end

    def format_arg_info(iseq)
      size = iseq.symtab.size
      argc = opt = kw = 0
      splat = kwsplat = block = -1
      if iseq.type == ISType::METHOD
        args = iseq.arg_info
        argc = args.argc
        opt = args.optc
        splat = args.splat
        kw = args.kwargc
        kwsplat = args.dbl_splat
        block = args.block_arg
      end
      return [size, argc, opt, splat, kw, kwsplat, block]
    end

    def print_symtable(symtab)
      str = String.build do |io|
        symtab.each_with_index do |name, i|
          io << @ident << i << ':' << ' ' << name << "  "
        end
      end
      puts str
    end

    def print_encoded(encoded : Array(IS))
      pattern = "#{@ident}%04d %-13s %-51s%10s"
      line_pattern = "(%4s)[Li]"
      callinfo_pattern = "<ci!name:%s, argc:%s, kwarg:%s, explict:%s, %s>"
      i = -1
      size = encoded.size
      while (i += 1) < size
        is = encoded[i]
        line = get_line(i)
        line = line ? line_pattern % line : nil
        ins  = get_instruction(is)
        op   = get_operand(is)
        puts case ins
        when .pop?, .leave?, .noop?, .push_true?, .push_false?, .push_self?, .push_null?
          pattern % {i, ins, nil, line}
        when .setinstance_v?, .setclass_v?,
             .getconst?, .storeconst?
          pattern % {i, ins, @iseq.names[op], line}
        when .setlocal_0?, .getlocal_0?
          pattern % {i, ins, get_var_name(@iseq.symtab, 0, op), line}
        when .setlocal_1?, .getlocal_1?
          pattern % {i, ins, get_var_name(@iseq.symtab, 1, op), line}
        when .setlocal_2?, .getlocal_2?
          pattern % {i, ins, get_var_name(@iseq.symtab, 2, op), line}
        when .setlocal?, .getlocal?
          op2 = encoded[i += 1].value
          pattern % {i, ins, "#{op} #{get_var_name(@iseq.symtab, op, op2)}", line}
        when .jump?, .jumpf?, .jumpt?, .jumpf_and_pop?
          pattern % {i, ins, op, line}
        when .pushobj?
          obj = get_object_str(op)
          pattern % {i, ins, obj, line}
        when .put_class?, .put_module?
          offset = encoded[i += 1].value
          name = @iseq.names[op]
          @stack << {@iseq.jump_iseq[offset], name } 
          # Counter i is adjusted to the real instruction count
          pattern % {i - 1, ins, "#{name} at #{offset}", line}
        when .call?, .call_no_block?, .invoke_block?
          ci = @iseq.call_info[op]
          block = ci.block || "null"
          ci_str = callinfo_pattern % {ci.name, ci.argc, ci.kwarg?, ci.explicit, block}
          @stack << {block, "block"} if !block.is_a? String
          pattern % {i, ins, ci_str, line}
        when .const_or_call?, .call_or_const?
          ci = @iseq.call_info[op]
          pattern % {i, ins, ci.name, line}
        when .define_method?, .define_smethod?
          op2, op3 = get_is_and_op(encoded[i += 1])
          name = @iseq.names[op2.value >> 32]
          @stack << {@iseq.jump_iseq[op3], name}
          mid = "#{name}:#{FuncVisib.new(op.to_i32)} at #{op3}"
          # Counter i is adjusted to the real instruction count
          pattern % {i - 1, ins, mid, line}
        else
          pattern % {i, ins, op, line}
        end
      end
    end

    def print_catchtbl(catch_tbl)
      format = "| catch type: %-5s st %04d, ed %04d, cont %04d"
      if !catch_tbl.empty?
        puts "== catch table"
        catch_tbl.each do |entry|
          puts format % {entry.type.to_s.downcase, entry.start, entry.end, entry.cont}
          case entry.type
          when .catch?
            preserve_state(entry.iseq) do 
              @ident += "| "
              disasm_general(nil) 
            end
          end
        end
        puts "|#{"-" * (79)}"
      end
    end

    def get_object_str(offset)
      obj = @iseq.object[offset]
      case obj
      when LcInt, LcFloat
        Internal.num2num(obj).to_s
      else 
        "at:#{offset}" 
      end
    end 

    def get_var_name(symtab, level, offset)
      level.times { symtab = symtab.previous.not_nil! }
      return symtab[offset]
    end

    def reset_line
      @lc         = -1
      @last_line  = -1
    end

    private def get_line(i)
      return nil if @iseq.line.empty?
      line_ref = @iseq.line[@lc + 1]?
      if line_ref && line_ref.sp <= i 
        @lc += 1
        line = line_ref.line
      else 
        line = @iseq.line[@lc].line
      end
      if line_ref && (@last_line == -1 || @last_line != line)
        @last_line = line 
        return line 
      end
      nil
    end

    private def get_instruction(op_code)
      return op_code & IS::IS_MASK
    end 

    private def get_operand(op_code)
      return (op_code & IS::OP_MASK).value
    end

    private def get_is_and_op(is)
      return {get_instruction(is), get_operand(is)}
    end

    def preserve_state(iseq)
      state = {@iseq,  @lc, @last_line, @ident}
      @iseq = iseq
      reset_line
      yield
      @iseq, @lc, @last_line, @ident = state
    end

  end
end