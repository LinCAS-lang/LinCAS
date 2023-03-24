# Copyright (c) 2020-2023 Massimiliano Dal Mas
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
  module Backtrace

    protected def vm_get_backtrace
      return "" if @control_frames.empty?
      @control_frames[-1] = @current_frame.copy_with(pc: @pc - 1)
      # the first frame is always the main frame, therefore
      # we have an iseq chunch from which we can extract the
      # location info
      p_location = {filename: "", line: 1}
      String.build do |io|
        @control_frames.each do |frame|
          p_location = get_location(frame, p_location, io)
          io << "\n"
        end
      end
    end

    protected def get_location(frame, p_location, io)
      if frame.flags.dummy_frame?
        iseq = frame.iseq
        filename = iseq.filename
        line = iseq.start_location
      elsif !frame.flags.icall_frame?
        dist = frame.pc - frame.pc_bottom
        iseq = frame.iseq
        filename = iseq.filename
        line = find_line(iseq.line, dist)
      else
        filename = p_location[:filename]
        line     = p_location[:line]
      end
      io << "  from " << filename << ":" << line << ":in "
      get_name(frame.env, io)
      return {filename: filename, line: line}
    end

    private def find_line(lines, dist)
      line = lines.first.line
      lines.each do |location|
        if location.sp <= dist
          line = location.line
        else
          break
        end
      end
      return line
    end

    private def get_name(env, io)
        case env.frame_type
        when .main_frame?, .class_frame?
          base_env_or_cref_name env, io
        when .block_frame?, .proc_frame?
          base_env = env.previous
          level = 0
          while base_env && base_env.frame_type.includes? (VM::VmFrame.flags(BLOCK_FRAME, PROC_FRAME))
            base_env = base_env.previous
            level += 1
          end
          io << "block "
          io << (level > 0 ? "(#{level + 1} levels) in " : "in ")
          base_env_or_cref_name base_env.not_nil!, io
        else
          io << env.context.name
        end
    end

    @[AlwaysInline]
    private def class_or_module_name(klass : LcClass, io)
      name = klass.name
      io << (klass.type.in?({SType::CLASS, SType::PyCLASS}) ? 
                              "<class:#{name}>" : "<module:#{name}>")
    end

    @[AlwaysInline]
    private def base_env_or_cref_name(env : VM::Environment, io)
      if env.frame_type.main_frame?
        io << "<main>"
      elsif env.frame_type.top_frame?
        io << "<top (required)>"
      else
        context = env.context
        io << (context.is_a?(LcMethod) ? context.name : class_or_module_name(context, io))
      end
    end

  end
end