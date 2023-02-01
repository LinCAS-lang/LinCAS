# Copyright (c) 2023 Massimiliano Dal Mas
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
  module VmArgs 

    macro vm_setup_args_fast_track(ci, calling)
      vm_set_up_kwargs({{ci}}, {{calling}}) if {{ci}}.has_kwargs?
      vm_set_up_splat({{ci}}, {{calling}}) if {{ci}}.splat
    end

    def vm_check_arity(expected, given)
    end

    ##
    # Only for calls to internal methods
    def vm_collect_args(argc, calling : VM::CallingInfo)
      return case argc
      when 0 
        {topn(0)}
      when 1
        {topn(1), topn(0)}
      when 2
        {topn(2), topn(1), topn(0)}
      when 3
        {topn(3), topn(2), topn(1), topn(0)}
      else
        depth = calling.argc
        {topn(depth), @stack.shared_copy(@sp - depth, depth).as(LcVal)}
      end
    end

    ##
    # Used to prepare args on stack for internal or python calls
    def vm_setup_args_internal_or_python(ci : CallInfo, calling : VM::CallingInfo)
      if !ci.dbl_splat || !ci.has_kwargs?
        vm_setup_args_fast_track(ci, calling)
      elsif ci.has_kwargs? && ci.dbl_splat
        vm_set_up_kwargs(ci, calling)
        vm_merge_kw
        calling.argc -= 1
        vm_set_up_splat(ci, calling) if ci.splat
      end
    end

    def vm_setup_iseq_args(env : VM::Environment, arg_info : ISeq::ArgInfo, ci : CallInfo, calling : VM::CallingInfo)
      if arg_info.arg_simple? && (!ci.dbl_splat || !ci.has_kwargs?)
        vm_setup_args_fast_track(ci, calling)
        vm_check_arity(arg_info.argc, calling.argc)
        vm_migrate_args(env, calling)
        return 0
      else
        return vm_setup_arg_complex(env, arg_info, ci, calling)
      end
    end

    ##
    # Assumes max a hash after splat argument.
    private def vm_set_up_splat(ci : CallInfo, calling : VM::CallingInfo)
      if !ci.dbl_splat || !ci.has_kwargs?
        debug("Preserving kw args while setting up splat")
        kwargs = pop
      end
      debug("Popping splat array")
      splat = pop
      vm_ensure_type splat, Internal::LcArray
      splat = splat.as(Ary)
      debug("Splatting array")
      splat.each { |elem| push elem }
      if kwargs
        debug("Restoring kwargs")
        push kwargs
      end
      calling.argc += (splat.size - 1)
    end

    ##
    # Assumes no other argument on stack after hash value
    private def vm_set_up_kwargs(ci : CallInfo, calling : VM::CallingInfo)
      kwtable = ci.kwarg.not_nil!
      hash = Internal.build_hash
      debug("Creating hash table for kw args")
      kwtable.reverse_each do |name|
        Internal.lc_hash_set_index(hash, Internal.string2sym(name), pop)
      end

      debug("Pushing argument hash")
      push hash
      calling.argc -= (kwtable.size - 1)
    end

    def vm_setup_arg_complex(env : VM::Environment, arg_info : ISeq::ArgInfo, ci : CallInfo, calling : VM::CallingInfo)
      # Argument migration to env is done directly here, stack is left unchanged
    end

    private def vm_migrate_args(env : VM::Environment, calling : VM::CallingInfo)
      elem_p = offset = @sp - calling.argc
      while elem_p < @sp
        env[elem_p - offset] = @stack[elem_p]
        elem_p += 1
      end
    end
  end
end