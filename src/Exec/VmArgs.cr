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

    macro migrate_args_from_splat(env, from, rest, splat, offset = 0)
      {{rest}}.times do |i|
        {{env}}[{{from}} + i] = {{splat}}[{{offset}} + i]
      end
    end

    @[AlwaysInline]
    private def get_splat(index)
      splat = topn(index)
      vm_ensure_type splat, Internal::LcArray
      return splat.as(Ary)
    end

    def vm_check_arity(min, max, given)
      debug "Arg check: min:#{min}, max:#{max}, given: #{given}"
      unless min <= given <= max
        raise "Wrong number of arguments (given #{given}, expected #{max == Float32::INFINITY ? "#{min}+" : min..max})"
      end
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
        hash = pop
        vm_merge_kw(topn(0), hash)
        calling.argc -= 1
        vm_set_up_splat(ci, calling) if ci.splat
      end
      # MISSING : arity check
    end

    def vm_setup_iseq_args(env : VM::Environment, arg_info : ISeq::ArgInfo, ci : CallInfo, calling : VM::CallingInfo)
      if arg_info.arg_simple? && (!ci.dbl_splat || !ci.has_kwargs?)
        debug "Setting up arg simple"
        vm_setup_args_fast_track(ci, calling)
        vm_check_arity(arg_info.argc, arg_info.argc, calling.argc)
        vm_migrate_args(env, calling)
        return 0
      else
        debug "Setting up arg complex"
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

    ##
    # Keeps the info of the args on stack.
    # the abstraction is:
    # [positional][splat][kwsplat][kw values]
    # <-- argc -->
    # ^ orig_argc
    # Everytime positional arguments are consumed,
    # orig_argc and argc are adjusted to point to the
    # remaining ones (if any).
    # if argc == 0, then orig_argc points to one of
    # the following elements, if provided by the call.
    struct Args
      def initialize(
        @orig_argc : Int32, # relative start of args
        @argc : Int32, # number of args before splat
        @splat : Bool = false,
        @kwsplat : Bool = false,
        @kwarg : Bool = false,
        @splat_index = 0
      ) 
        @_splat = nil.as(Ary?) # Caches splat
      end
      property orig_argc, argc, splat, kwsplat, kwarg, splat_index, _splat
    end


    def vm_setup_arg_complex(env : VM::Environment, arg_info : ISeq::ArgInfo, ci : CallInfo, calling : VM::CallingInfo)
      min_argc = arg_info.argc
      max_argc = arg_info.splat? ? Float32::INFINITY : min_argc + arg_info.optc
      iseq_offset = 0

      args = Args.new(calling.argc, ci.argc_before_splat, ci.splat, ci.dbl_splat, ci.has_kwargs?)
      
      # If the method has no kwsplat or kwarguments, then we treat everything
      # as a positional argument of type hash, or inserted in splat, if present.
      # the idea is to organise things like this on stack:
      # [positional][splat]
      # <-- argc -->      ^ @sp
      # ^ orig_argc
      if !(arg_info.kwargs? && arg_info.dbl_splat?)
        if ci.has_kwargs?
          vm_set_up_kwargs(ci, calling)
          if ci.dbl_splat
            hash = pop
            vm_merge_kw(topn(0), hash) # To check if hash1 dupped
            calling.argc -= 1
          end
          args.kwarg = false
        end
        if ci.splat && (ci.dbl_splat || ci.has_kwargs?)
          vm_array_append # Splat array is always dupped
          calling.argc -= 1
          args.kwsplat = false
        elsif ci.dbl_splat || ci.has_kwargs?
          args.argc += 1 # kwargs or kwsplat are counted as a positional argument
        end
        args.orig_argc = calling.argc
      end

      given_argc = args.argc # splat and double splat not counted yet

      if ci.splat
        index = calling.argc - args.argc - 1
        splat = get_splat index
        given_argc += splat.size - 1 # removing the splat in the counting
        args._splat = splat
      end

      vm_check_arity(min_argc, max_argc, given_argc)

      if arg_info.argc > 0
        args = args_setup_positional(env, arg_info, args)
      end
      if arg_info.optc > 0
        iseq_offset, args = args_setup_opt(env, arg_info, args)
      end

      return iseq_offset
    end

    private def args_setup_positional(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args)
      elem_p = @sp - args.orig_argc
      offset = 0
      if arg_info.argc <= args.argc
        # All positional arguments are already in args.argc
        vm_migrate_args env, elem_p, offset, arg_info.argc
        args.orig_argc -= arg_info.argc
        args.argc -= arg_info.argc
      else
        # Positional arguments are partially in args.argc and splat
        lc_bug "Failed to detect missing arguments" unless args.splat
        vm_migrate_args env, elem_p, offset, args.argc
        splat = args._splat.not_nil!
        from = args.argc
        args.splat_index = rest = arg_info.argc - from
        migrate_args_from_splat(env, from, rest, splat)
        args.orig_argc -= args.argc
        args.argc = 0
      end
      return args
    end

    private def args_setup_opt(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args)
      elem_p = @sp - args.orig_argc 
      offset = arg_info.argc # opt start in env
      optc = arg_info.optc
      if optc <= args.argc
        # All the opt args are already on stack
        vm_migrate_args(env, elem_p, offset, optc)
        args.orig_argc -= optc
        args.argc      -= optc
        iseq_offset     = arg_info.opt_table[optc]
      else
        # we have some opt arg on stack, maybe a splat too
        vm_migrate_args(env, elem_p, offset, args.argc)
        if args.splat
          # partial or zero opt args are on stack, but we have a splat
          splat       = args._splat.not_nil!
          splat_index = args.splat_index
          from        = arg_info.argc + args.argc
          if splat.size - splat_index >= optc - args.argc
            # splat has all the opt_args (we don't care if splat has more)
            migrate_args_from_splat(env, from, optc, splat, splat_index)
            args.splat_index += optc
            iseq_offset       = arg_info.opt_table[optc]
          else
            # Splat has only partial opt args
            rest = splat.size - splat_index
            migrate_args_from_splat(env, from, rest, splat, splat_index)
            iseq_offset = arg_info.opt_table[rest]
          end
        else
          iseq_offset = arg_info.opt_table[args.argc]
        end
        args.orig_argc -= args.argc
        args.argc = 0 
      end
      return {iseq_offset, args}
    end

    @[AlwaysInline]
    private def vm_migrate_args(env : VM::Environment, calling : VM::CallingInfo)
      vm_migrate_args env, (@sp - calling.argc), 0, calling.argc
    end

    @[AlwaysInline]
    private def vm_migrate_args(env : VM::Environment, elem_p, offset, count)
      # Unsafe code!
      env_p = env.to_unsafe + offset
      stack_p = @stack.ptr + elem_p
      count.times do
        env_p.value = stack_p.value
        env_p += 1
        stack_p += 1
      end
    end
  end
end