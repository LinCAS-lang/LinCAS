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

    UNLIMITED_ARGUMENTS = Float32::INFINITY

    macro vm_setup_args_fast_track(ci, calling)
      vm_set_up_splat({{ci}}, {{calling}}) if {{ci}}.splat
      vm_set_up_kwargs({{ci}}, {{calling}}) if {{ci}}.has_kwargs?
    end

    macro migrate_args_from_splat(env, from, rest, splat, offset = 0)
      ({{rest}}).times do |i|
        {{env}}[{{from}} + i] = {{splat}}[{{offset}} + i]
      end
    end

    @[AlwaysInline]
    private def get_splat
      splat = pop
      vm_ensure_type splat, Internal::LcArray
      return lc_recast(splat, Ary) # Force casting to Ary
    end

    @[AlwaysInline]
    private def get_kwsplat
      kwsplat = pop
      vm_ensure_type kwsplat, Internal::LcHash
      return lc_cast(kwsplat, Internal::LcHash)
    end

    def vm_check_arity(min, max, given)
      debug "Arg check: min:#{min}, max:#{max}, given: #{given}"
      unless min <= given <= max
        raise "Wrong number of arguments (given #{given}, expected #{max == UNLIMITED_ARGUMENTS ? "#{min}+" : min..max})"
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
        max_argc = UNLIMITED_ARGUMENTS
      end
      vm_check_arity(min_argc, max_argc, calling.argc)
    end

    def vm_setup_iseq_args(env : VM::Environment, arg_info : ISeq::ArgInfo, ci : CallInfo, calling : VM::CallingInfo)
      if arg_info.arg_simple? && (!ci.dbl_splat)
        # Here we have only positional arguments and optional splat
        # or positional arguments and kw arguments.
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

    private def vm_set_up_splat(ci : CallInfo, calling : VM::CallingInfo)
      splat = get_splat
      debug("Splatting array")
      splat.each { |elem| push elem }
      calling.argc += (splat.size - 1)
    end

    ##
    # Assumes no other argument on stack after hash value
    # Any check to assert that ci.kwarg is not nil has to be done before
    # calling this function
    private def vm_set_up_kwargs(ci : CallInfo, calling : VM::CallingInfo)
      kwtable = ci.kwarg
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
    class Args
      {%for name in {"initialize", "unsafe_init"}%}
        def {{name.id}}(
          # Basic stuff
          @orig_argc : Int32, # start of args
          @argc : Int32, # number of args on stack

          @splat_index = 0,
          @keywords = nil.as(Array(String)?),
          @kw_values = nil.as(Array(LcVal)?)
        ) 
          @_kwsplat = nil.as(Internal::LcHash?) # Caches double splat
          @_splat = nil.as(Ary?) # Caches splat
          @env_count = 0
          self
        end
      {% end %}
      property orig_argc, argc, splat, kwsplat, kwarg, splat_index, _splat, _kwsplat, env_count
      property! keywords, kw_values
    end


    def vm_setup_arg_complex(env : VM::Environment, arg_info : ISeq::ArgInfo, ci : CallInfo, calling : VM::CallingInfo)
      min_argc = arg_info.argc
      max_argc = arg_info.splat? ? UNLIMITED_ARGUMENTS : min_argc + arg_info.optc
      iseq_offset = 0
      dbl_splat = false
      
      # For performance reasons, we don't want to create an Args object on heap
      # but we still want to be able to modify it without returning
      # the object every time.
      # Since we know the object is used only in this scope and its children,
      # we can create a memory slot in stack with sise of Args instance 
      # and cast its pointer to Args. Its equivalent in C is
      # ```
      # Args arg_body, *args;
      # args = &arg_body;
      # ```
      # arg_body shall never be touched to prevent memory corruption
      arg_body = uninitialized UInt8[instance_sizeof(Args)]
      args = arg_body.to_unsafe.as(Args).unsafe_init(
        @sp - calling.argc, 
        given_argc = ci.argc
      )

      if ci.has_kwargs?
        args.keywords = ci.kwarg
        kw_len = args.keywords.size
        if arg_info.kwargs?
          # migrate the kw  values to args
          args.kw_values = Array(LcVal).build(kw_len) { |ptr| ptr.copy_from(@stack.ptr + (@sp - kw_len), kw_len); kw_len}
          args.argc -= kw_len
          given_argc -= kw_len
          @sp -= kw_len # virtually erease keyword parameters from stack
          calling.argc -= kw_len
        else
          # keywords are just a positional hash
          given_argc = args_kw_to_hash(args)
          calling.argc -= kw_len - 1
          dbl_splat = arg_info.dbl_splat?
        end
      end

      # We are sure there is nothing after splat. This is
      # ensured at compile time 
      if ci.splat
        splat = get_splat # splat is popped
        given_argc += splat.size - 1 # removing the splat in the counting
        args._splat = splat
        args.argc -= 1
        calling.argc -= 1
      end

      if ci.dbl_splat || dbl_splat
        args_kwsplat_magic_pop(args)
        calling.argc -= 1 if !ci.splat
        given_argc = args_given_argc args
      end

      vm_check_arity(min_argc, max_argc, given_argc)

      # if we have a splat, we may have more than positional
      # or optional arguments on stack. We want to move the
      # exceeding ones to the splat, so that we don't run
      # into problems when migrating everything to env.
      # At this point we know we have a splat, otherwise
      # the argc check would have failed due to too many args
      truncate = min_argc + arg_info.optc
      if args.argc > truncate
        args_copy(args, truncate)
        calling.argc = truncate 
      end

      # Now we have this situation:
      # stack = [m1, m2, m3, ..., mN]
      #                             ^@sp
      # args
      #  |> orig_argc = @sp - N
      #  |> argc = N
      #  |> _splat = Ary?
      #  |> _kwsplat = LcHash?
      #  |> keywords = Array(String)?
      #  |> kw_values = Array(LcVal)?
      #
      # We migrate the arguments at this point and start from there.
      # We have the positional arguments in place, splat, keywords
      # or kwsplat in args, ready to be fixed in env
      vm_migrate_args(env, calling)

      if arg_info.argc > 0
        args_setup_positional(env, arg_info, args)
      end

      if arg_info.optc > 0
        iseq_offset = args_setup_opt(env, arg_info, args)
      end

      if arg_info.splat?
        args_setup_splat(env, arg_info, args)
      end
      
      if arg_info.kwargs?
        if args.kw_values?
          args_setup_kw(env, arg_info, args)
        elsif kwsplat = args._kwsplat
          # TODO: what if splat keys are not symbols?
          # For now just raise a type error
          args.keywords, args.kw_values = split_kwsplat(kwsplat)
          args_setup_kw(env, arg_info, args)
        else
          args.keywords = nil
          args_setup_kw(env, arg_info, args)
        end
      elsif arg_info.dbl_splat?
        args_setup_kwsplat(env, arg_info, args)
      elsif (kwsplat = args._kwsplat) && kwsplat.size > 0
        unknown = gather_unknown_keywords(kwsplat)
        argument_kwerror "Unknown", unknown
      end
      
      if arg_info.block_arg?
        args_setup_block_arg(env, arg_info.block_arg, calling.block)
      end
      
      return iseq_offset
    end

    @[AlwaysInline]
    private def args_kw_to_hash(args : Args)
      keywords = args.keywords
      kw_start = args.orig_argc + (args.argc - keywords.size)
      hash = Internal.build_hash
      keywords.each_with_index do |name, i|
        Internal.lc_hash_set_index(hash, Internal.string2sym(name), @stack[kw_start + i])
      end
      args.argc -= keywords.size - 1
      @sp = kw_start # virtually erease the keyword values from stack
      push hash 
      return args.argc
    end

    ##
    # It pops the keyword hash. If splat is given,
    # then kwsplat is the last element. Otherwise
    # pop it from stack
    @[AlwaysInline]
    private def args_kwsplat_magic_pop(args : Args)
      kwsplat = nil
      if !(splat = args._splat)
        kwsplat = get_kwsplat
        args.argc -= 1
      elsif splat.size > 0 
        kwsplat = splat.pop
        vm_ensure_type kwsplat, Internal::LcHash
      end
      args._kwsplat = kwsplat.as Internal::LcHash
    end

    @[AlwaysInline]
    private def args_given_argc(args : Args)
      if splat = args._splat
        return args.argc + splat.size
      else
        return args.argc
      end
    end

    ##
    # This is an unsafe function.
    # It moves arguments from stack to a splat.
    # The moved arguments are placed before the splat content
    @[AlwaysInline]
    private def args_copy(args : Args, truncate)
      start = args.orig_argc + truncate
      rest = args.argc - truncate
      orig = @stack.ptr + start
      if splat = args._splat
        splat_p = splat.ptr
        if splat.size + rest > splat.total_size
          splat.total_size = splat.size + rest
          splat.ptr = splat_p = splat_p.realloc(splat.total_size)
        end
        (splat_p + rest).move_from(splat_p, splat.size)
        splat_p.copy_from(orig, rest)
      else
        splat = Ary.new rest
        splat.ptr.copy_from(orig, rest)
        args._splat = splat
      end
      @sp = start
    end

    private def args_setup_positional(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args)
      debug "Setting up positional args"
      argc = arg_info.argc
      if argc <= args.argc
        # It's ok. Everything is on place
        args.argc -= argc
      else
        debug "Setting up positional args from splat"
        # We have a splat for sure.
        splat = args._splat.not_nil!
        i = args.argc
        j = 0
        while i < argc
          env[i] = splat[j]
          i += 1
          j += 1
        end
        args.splat_index = j
        args.argc = 0
      end
      args.env_count = argc
    end

    private def args_setup_opt(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args)
      i = 0
      optc = arg_info.optc

      if args.argc >= optc
        # Everything is already in place
        args.argc -= optc
        i = optc
      else
        i = args.argc
        j = args.env_count
        args.argc = 0

        if splat = args._splat
          debug "Setting up opt from splat"

          size = splat.size
          while i < optc && args.splat_index < size
            env[j] = splat[args.splat_index]
            i += 1
            j += 1
            args.splat_index += 1
          end
        end
      end
      args.env_count += optc # doesn't matter if we don't have all the optc
      return arg_info.opt_table[i]
    end

    private def args_setup_splat(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args)
      debug "Setting up splat"
      if splat = args._splat
        unless args.splat_index.zero?
          size = splat.size - args.splat_index
          splat.ptr.move_from(splat.ptr + args.splat_index, size)
          splat.size = size
        end
        env[args.env_count] = splat.as(LcVal)
        args._splat = nil
      else
        env[args.env_count] = Internal.build_ary_new
      end
      args.env_count += 1
    end

    # kw is an array of strings or an empty static array. 
    # We leave the compiler infer the type
    private def args_setup_kw(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args)
      debug("Setting up keyword arguments")
      kw_bit = 0u64
      env_relative_start = arg_info.argc + arg_info.optc + (arg_info.splat? ? 1:0)

      missing = nil
      found = 0
      tmp0 = uninitialized String[0]
      tmp1 = uninitialized LcVal[0]

      keywords = args.keywords? || tmp0
      kw_values = args.kw_values? || tmp1

      arg_info.named_args.each do |name, (index, mandatory)|
        if keywords.includes? name
          kw_index = keywords.index! name
          env[index] = kw_values[kw_index]
          kw_bit |= 0x01 << (index - args.env_count)
          found += 1
        elsif mandatory
          missing = [] of String unless missing
          missing << name
        else
          # do nothing
        end
      end
      argument_kwerror "Missing", missing if missing

      if arg_info.dbl_splat?
        env[arg_info.dbl_splat] = make_dbl_splat(arg_info, keywords, kw_values)
      elsif found != keywords.size
        unknown = keywords.to_a - arg_info.named_args.keys
        argument_kwerror "Unknown", unknown
      end
      env.kw_bit = kw_bit
    end

    @[AlwaysInline]
    private def make_dbl_splat(arg_info, passed_kw, passed_val)
      acceptable_kw = arg_info.named_args
      hash = Internal.build_hash
      passed_kw.each_with_index do |kw, i|
        unless acceptable_kw.has_key? kw
          key = Internal.string2sym(kw)
          Internal.lc_hash_set_index(hash, key, passed_val[i])
        end
      end
      return hash
    end

    @[AlwaysInline]
    private def args_setup_kwsplat(env : VM::Environment, arg_info : ISeq::ArgInfo, args : Args)
      if !(kwsplat = args._kwsplat)
        kwsplat = Internal.build_hash
      end
      env[arg_info.dbl_splat] = kwsplat
    end

    @[AlwaysInline]
    private def split_kwsplat(kwsplat : Internal::LcHash)
      keywords = Array(String).new initial_capacity: kwsplat.size
      values = Array(LcVal).new initial_capacity: kwsplat.size
      Internal.hash_iterate(kwsplat) do |entry|
        key = entry.key
        value = entry.value
        if key.is_a? Internal::LcSymbol
          keywords << Internal.sym2string(key)
          values << value
        else
          lc_raise(LcTypeError, "Hash key #{Internal.obj_inspect(key)} is not a symbol")
        end
      end
      return {keywords, values}
    end

    private def gather_unknown_keywords(kwsplat : Internal::LcHash)
      keys = [] of String
      Internal.hash_each_key(kwsplat) do |key|
        keys << if key.is_a? Internal::LcSymbol
          Internal.sym2string(key)
        else
          Internal.obj_inspect(key)
        end
      end
      return keys
    end

    @[AlwaysInline] 
    private def args_setup_block_arg(env : VM::Environment, index : Int32, block : VM::BlockHandler?)
      if block
        if block.is_a? LcBlock
          block = Internal.lincas_block_to_proc block
        end
        env[index] = block
      end
    end

    protected def vm_setup_block_args(env : VM::Environment, arg_info : ISeq::ArgInfo, ci : CallInfo, calling : VM::CallingInfo)
      if arg_info.arg_simple?
        vm_setup_args_fast_track(ci, calling)
        vm_migrate_args(env, calling)
        # TODO: code for autosplat

        if calling.argc > arg_info.argc
          # truncate? 
        else
          # Nothing to do. Args in env are already set to null
        end
        return 0
      else
        return vm_setup_arg_complex(env, arg_info, ci, calling)
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