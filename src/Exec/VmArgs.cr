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
      ({{rest}}).times do |i|
        {{env}}[{{from}} + i] = {{splat}}[{{offset}} + i]
      end
    end

    @[AlwaysInline]
    private def get_splat(index)
      splat = topn(index)
      vm_ensure_type splat, Internal::LcArray
      return lc_recast(splat, Ary) # Force casting to Ary
    end

    @[AlwaysInline]
    private def get_kwsplat(index)
      kwsplat = topn(index)
      vm_ensure_type kwsplat, Internal::LcHash
      return lc_cast(kwsplat, Internal::LcHash)
    end

    def vm_check_arity(min, max, given)
      debug "Arg check: min:#{min}, max:#{max}, given: #{given}"
      unless min <= given <= max
        raise "Wrong number of arguments (given #{given}, expected #{max == Float32::INFINITY ? "#{min}+" : min..max})"
      end
    end

    def argument_kwerror(reason : String, kws : Array(String))
      error = "#{reason} keyword(s) #{kws}"
      raise error
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
    def vm_setup_args_internal_or_python(ci : CallInfo, calling : VM::CallingInfo, argc)
      if !ci.dbl_splat || !ci.has_kwargs?
        vm_setup_args_fast_track(ci, calling)
      elsif ci.has_kwargs? && ci.dbl_splat
        vm_set_up_kwargs(ci, calling)
        hash = pop
        vm_merge_kw(topn(0), hash)
        calling.argc -= 1
        vm_set_up_splat(ci, calling) if ci.splat
      end
      if argc >= 0 # Likely
        min_argc = max_argc = argc
      else
        min_argc = argc.abs - 1
        max_argc = Float32::INFINITY
      end
      vm_check_arity(min_argc, max_argc, calling.argc)
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
        @_kwsplat = nil.as(Internal::LcHash?) # Caches double splat
        @_splat = nil.as(Ary?) # Caches splat
      end
      property orig_argc, argc, splat, kwsplat, kwarg, splat_index, _splat, _kwsplat
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
      if !arg_info.kwargs? && !arg_info.dbl_splat?
        debug("Simplifying stack for simple call args")
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
          value = pop
          vm_array_append(topn(0), value) # Splat array is always dupped
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

      if ci.dbl_splat
        # we just cache the double splat for later use
        args._kwsplat = get_kwsplat (ci.kwarg ? ci.kwarg.not_nil!.size : 0)
      end

      vm_check_arity(min_argc, max_argc, given_argc)
      if arg_info.argc > 0
        args = args_setup_positional(env, arg_info, args)
      end
      if arg_info.optc > 0
        iseq_offset, args = args_setup_opt(env, arg_info, args)
      end
      if arg_info.splat?
        args_setup_splat(env, arg_info, args)
      end

      # We may not have kw args from the call (ci.kwarg)
      # so we pass an empty static array instead. This is
      # a small memory optimization
      tmp = uninitialized String[0]
      if arg_info.kwargc > 0
        args_setup_kw(env, arg_info, args, ci.kwarg || tmp)
      end

      # At this point we have consumed all the arguments before splat
      # and the splat itself. We are also sure that all the explicit
      # keywords are set. We just miss to set up a double splat if existing.
      # In case the method doesn't we have to throw an error on every extra
      # keyword argument provided.
      # The following method behaves differently then the previous ones and
      # it is delegated to raise the error
      args_setup_kwsplat(env, arg_info, args, ci.kwarg || tmp)

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
        debug("Setting up opt args from stack")
        vm_migrate_args(env, elem_p, offset, optc)
        args.orig_argc -= optc
        args.argc      -= optc
        iseq_offset     = arg_info.opt_table[optc]
      else
        # we have some opt arg on stack, maybe a splat too
        vm_migrate_args(env, elem_p, offset, args.argc)
        if args.splat
          # partial or zero opt args are on stack, but we have a splat
          debug("Setting up opt args from stack + splat")
          splat       = args._splat.not_nil!
          splat_index = args.splat_index
          from        = arg_info.argc + args.argc
          if splat.size - splat_index >= optc - args.argc
            # splat has all the opt_args (we don't care if splat has more)
            debug("Setting up opt args from splat (complete)")
            migrate_args_from_splat(env, from, optc - args.argc, splat, splat_index)
            args.splat_index += optc - args.argc
            iseq_offset       = arg_info.opt_table[optc]
          else
            # Splat has only partial opt args
            debug("Setting up opt args from splat (partial)")
            rest = splat.size - splat_index
            migrate_args_from_splat(env, from, rest, splat, splat_index)
            args.splat_index = splat.size.to_i32
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

    private def args_setup_splat(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args)
      argc = args.argc
      if args.splat
        ary = splat = args._splat.not_nil!
        if argc == 0
          if args.splat_index == 0
            # Splat is just the given splat

            # nothing to do here
            debug "Setting up splat = given splat"
          else
            # splat is just partial. Shift the remaining values to the left
            # unsafe code below
            debug "Setting up remaining splat"
            size = splat.size - args.splat_index
            splat.ptr.move_from(splat.ptr + args.splat_index, size)
            splat.size = size
          end
        else
          debug "Setting up splat stack + splat"
          # we have some arg left on stack + splat
          # unsafe code below
          new_capa = splat.size + argc
          if new_capa > splat.total_size
            splat.ptr = splat.ptr.realloc(new_capa)
            splat.total_size = new_capa
          end
          tmp = splat.ptr + argc
          tmp.move_from(splat.ptr, splat.size)
          tmp -= argc
          tmp.copy_from(@stack.ptr + (@sp - args.orig_argc), argc)
          splat.size = new_capa
        end
      elsif argc > 0
        # we have no splat given, but we have args left on stack
        debug "Setting up splat from stack"
        ary = Ary.new argc
        orig_argc = args.orig_argc
        argc.times do |i|
          ary[i] = topn(orig_argc - i - 1) # Slower code, but safe
        end
      else
        # splat is just an empty array
        debug "Setting up empty splat"
        ary = Internal.build_ary_new
      end
      env[arg_info.splat] = ary
    end

    # kw is an array of strings or an empty static array. 
    # We leave the compiler infer the type
    private def args_setup_kw(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args, kw)
      debug("Setting up keyword arguments")
      kw_bit = 0u64
      kw_relative_start = kw.size - 1
      kwsplat = args._kwsplat # get from cached object. Could be nil...
      env_relative_start = arg_info.argc + arg_info.optc + (arg_info.splat? ? 1:0)

      vm_ensure_type kwsplat, Internal::LcHash if kwsplat
      missing = nil
      kwrest  = nil

      arg_info.named_args.each do |name, (index, mandatory)|
        if kw.includes? name
          kw_index = kw.index! name
          env[index] = topn(kw_relative_start - kw_index)
          kw_bit |= 0x01 << (index - env_relative_start)
        elsif kwsplat
          sym = Internal.string2sym(name)
          if Internal.hash_has_key(kwsplat, sym)
            value = Internal.lc_hash_fetch(kwsplat, Internal.string2sym(name))
            env[index] = value
            kw_bit |= 0x01 << (index - env_relative_start)
          else
            missing = [] of String unless missing
            missing << name if mandatory
          end
        elsif mandatory
          missing = [] of String unless missing
          missing << name
        else
          # do nothing
        end
      end
      argument_kwerror "Missing", missing if missing && !missing.empty?
      env.kw_bit = kw_bit
    end

    private def args_setup_kwsplat(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args, kw)
      kwsplat = args._kwsplat
      allowed_kw = arg_info.kwargs? ? arg_info.named_args : NamedTuple.new
      total_kw = kw.size + (kwsplat ? kwsplat.size:0) - env.kw_bit.popcount # total kw passed - total kw matched
      if total_kw == 0
        env[arg_info.dbl_splat] = Internal.build_hash if arg_info.dbl_splat?
        # otherwise do nothing
      elsif !arg_info.dbl_splat?
        # we have unknown keywords
        unknown = [] of String
        kw.each do |name|
          unknown << name unless allowed_kw.has_key? name
        end
        if kwsplat
          Internal.hash_each_key(kwsplat) do |key|
            name = Internal.sym2string(key) # Temporary solution. Should call obj_any2string
            unknown << name unless allowed_kw.has_key? name
          end
        end
        argument_kwerror "Unknown", unknown if !unknown.empty? # this if condition is somehow redundant
      else
        # We have a splat to put all the missing keywords
        new_kwsplat = Internal.build_hash
        kwbeg = kw.size - 1 # where kw values start on stack
        # We push the remaining passed keywords
        kw.each_with_index do |name, i|
          unless allowed_kw.has_key? name
            key = Internal.string2sym(name)
            value = topn(kwbeg - i)
            Internal.lc_hash_set_index(new_kwsplat, key, value)
          end
        end
        # We push the remaining keywords from the passed double splat
        if kwsplat
          Internal.hash_iterate(kwsplat) do |entry|
            name = Internal.sym2string(entry.key) # Temporary. Key could be anything
            Internal.lc_hash_set_index(new_kwsplat, entry.key, entry.value) unless allowed_kw.has_key? name
          end
        end
        env[arg_info.dbl_splat] = new_kwsplat
      end
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