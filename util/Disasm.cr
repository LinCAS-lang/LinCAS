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
      @stack = [] of ISeq
      @line_index = 0
      @lc         = -1
      @last_line  = -1
      @sp         = 0
    end

    def disasm
      type     = @iseq.type.to_s
      filename = @iseq.filename
      symtab   = @iseq.symtab 
      puts "#{type}>#{"="* (79 - type.size)}",
           "file: #{filename}",
           "local table: (size: %s, args: %s, named_args: %s, block_arg: %s)" %
           [symtab.size, @iseq.args || 0, @iseq.named_args || 0, @iseq.block_arg || -1]
           
      print_symtable(@iseq.symtab)
      print_encoded(@iseq.encoded)
    end

    def print_symtable(symtab)
      str = String.build do |io|
        symtab.each_with_index do |name, i|
          io << i << ':' << ' ' << name << "  "
        end
      end
      puts str
    end

    def print_encoded(encoded : Array(IS))
      pattern = "%04d %-13s %-51s%10s"
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
        when .setlocal_0?, .setlocal_1?, .setlocal_2?, .setinstance_v?, .setclass_v?,
             .getlocal_0?, .getlocal_1?, .getlocal_2?, .getconst?, .storeconst?
          pattern % {i, ins, @iseq.symtab[op.value], line}
        when .setlocal?, .getlocal?
          op2 = encoded[i += 1].value
          pattern % {i, ins, "#{op2} #{@iseq.symtab[op.value]}", line}
        when .jump?, .jumpf?, .jumpt?, .jumpf_and_pop?
          pattern % {i, ins, op, line}
        when .pushobj?
          obj = get_object_str(op.value)
          pattern % {i, ins, obj, line}
        when .put_class?, .put_module?
          offset = encoded[i += 1].value
          name = @iseq.names[op.value]
          @stack << {@iseq.jump_iseq[offset], name } 
          pattern % {i, ins, "#{name} at #{offset}", line}
        when .call?, .call_no_block?
          ci = @iseq.call_info[op.value]
          block = ci.block || "null"
          ci_str = callinfo_pattern % {ci.name, ci.argc, ci.kwarg, ci.explicit, block}
          pattern % {i, ins, ci_str, line}
        when .define_method?, .define_smethod?
          op2, op3 = get_is_and_op(encoded[i += 1])
          name = @iseq.names[op2.value >> 32]
          @stack << {@iseq.jump_iseq[op3], name}
          mid = "#{name}:#{FuncVisib.new(op.value.to_i32)} at #{op3}"
          pattern % {i, ins, mid, line}
        else
          pattern % {i, ins, op, line}
        end
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

    private def get_line(i)
      line_ref = @iseq.line[@lc + 1]?
      if line_ref && line_ref.sp <= i 
        @lc += 1
        line = line_ref.line
      else 
        line = @iseq.line[@lc].line
      end
      if @last_line == -1 || @last_line != line 
        @last_line = line 
        return line 
      end
      nil
    end

    private def get_instruction(op_code)
      return op_code & IS::IS_MASK
    end 

    private def get_operand(op_code)
      return op_code & IS::OP_MASK
    end

  end
end