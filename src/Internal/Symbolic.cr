
# Copyright (c) 2017-2018 Massimiliano Dal Mas
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




module LinCAS::Internal

    @@sym_dict = uninitialized Hash(SBaseC.class | SBaseS.class,LcClass)
    alias Symbolic_t =  LcVal | Symbolic 

    class LcFunction < BaseC
        @func : Symbolic = NanC
        property func
    end

    struct FakeFun < BaseS
        @func : Symbolic = NanC
        property func
    end

    macro check_fun(f,ret = true)
        if !({{f}}.is_a? LcFunction)
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof({{f}})} into Symbolic")
            {% if ret %}
                return Null 
            {% else %}
                next Null 
            {% end %}
        end
    end

    macro ensure_var(var)
        if !(get_function({{var}}).is_a? Variable)
            lc_raise(LcTypeError,"Argument must be Variable, not #{lc_typeof({{var}})}")
            return Null 
        end
    end

    macro set_function(obj,func)
        lc_cast({{obj}},LcFunction | FakeFun).func = {{func}}
    end

    macro get_function(obj)
        lc_cast({{obj}},LcFunction | FakeFun).func
    end

    private def self.to_symbolic(*values) : Array(Symbolic)
        tmp = [] of Symbolic
        values.each do |el|
            if el.is_a? LcFunction || el.is_a? FakeFun
                tmp << el.func
            elsif el.is_a? Symbolic
                tmp << el
            elsif el.is_a? LcNum
                tmp << Snumber.new(num2num(el).as(IntnumR))
            else
                lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(el)} into Symbolic")
                tmp << NanC
            end
        end
        return tmp
    end

    {% for block in { {"sum",'+'},{"sub",'-'},{"prod",'*'},{"div",'/'},{"power","**"} } %}
        def self.s_{{block[0].id}}(v1 : Symbolic_t,v2 : Symbolic_t)
            v1,v2 = to_symbolic(v1,v2)
            return v1 {{block[1].id}} v2
        end
    {% end %}

    def self.s_invert(obj :  LcVal)
        v = to_symbolic(obj)[0]
        return -v
    end

    def self.function_allocate(klass : LcClass)
        tmp = LcFunction.new
        tmp.klass = klass 
        tmp.data  = klass.data.clone 
        tmp.id    = tmp.object_id 
        return lc_cast(tmp, LcVal)
    end

    @[AlwaysInline]
    def self.lc_function_allocate(klass : LcVal)
        return function_allocate(klass.as(LcClass))
    end

    def self.build_function
        return function_allocate(@@lc_symbolic)
    end

    def self.build_function(func : Symbolic)
        tmp = function_allocate(@@sym_dict[func.class])
        set_function(tmp,func)
        return tmp
    end

    def self.build_function(func : FakeFun)
        func = get_function(func)
        tmp  = function_allocate(@@sym_dict[func.class])
        set_function(tmp,func)
        return tmp
    end

    def self.build_fake_fun(func : Symbolic)
        tmp = FakeFun.new
        tmp.klass = @@lc_symbolic 
        tmp.id    = pointerof(func).address
        tmp.flags |= ObjectFlags::FAKE
        tmp.func  = func
        return tmp
    end

    def self.lc_func_to_s(obj :  LcVal)
        return build_string_recycle(get_function(obj).to_s.to_s)
    end

    {% for name in %w|sum sub prod div power|%}
        def self.lc_func_{{name.id}}(f1 :  LcVal, f2 :  LcVal)
            check_fun(f2) unless f2.is_a? LcNum
            return build_function(s_{{name.id}}(get_function(f1),(f2.is_a? LcNum) ? f2 : get_function(f2)))
        end
    {% end %}

    def self.lc_func_uminus(f :  LcVal)
        return build_function(-get_function(f))
    end

    def self.lc_func_diff(f :  LcVal, var :  LcVal)
        check_fun(var)
        ensure_var(var)
        func = get_function(f)
        v    = get_function(var)
        return build_function(func.diff(v))
    end

    def self.lc_func_eval(f :  LcVal, dict :  LcVal)
        hash_check(dict)
        tmp = get_function(f).eval(lc_cast(dict,LcHash))
        return num_auto(tmp)
    end

    def self.lc_func_vars(f :  LcVal)
        func = get_function(f)
        tmp  = [] of Variable
        ary  = build_ary_new
        func.get_params(tmp)
        tmp.each do |param|
            lc_ary_push(ary,build_function(param))
        end
        return ary 
    end

    def self.lc_func_integrate(f :  LcVal, a :  LcVal, b :  LcVal)
        a1   = lc_num_to_cr_f(a)
        return Null unless a1
        b1   = lc_num_to_cr_f(b)
        return Null unless b1
        sign = 0
        if a1 > b1 
            sign = 1 
            a,b = b,a 
        end
        func = get_function(f)
        if func.is_a? Snumber
            val = (-1) ** sign * (b1 - a1) * func.val
        else
            val = (-1) ** sign * simpson(func,a,b)
        end
        return num_auto(val)
    end

    def self.lc_var_init(f :  LcVal, string :  LcVal)
        check_string(string)
        str = string2cr(string).as(String)
        v   = Variable.new(str)
        set_function(f,v)
        return f 
    end

    def self.lc_var_name(func :  LcVal)
        func = get_function(func)
        return build_string(lc_cast(func,Variable).name)
    end

    def self.lc_snum_init(f :  LcVal, value :  LcVal)
        if !(value.is_a?  LcVal)
            lc_raise(LcTypeError,"Argument must be Number, (#{lc_typeof(value)} given)")
            return Null 
        end
        v = num2num(value)
        if v.is_a? BigInt
            lc_raise(LcNotSupportedError,"Big integers are not supported in symbolics yet")
            return Null 
        end
        neg = v < 0
        v = v.abs 
        func = Snumber.new(v.as(IntnumR))
        set_function(f,neg ? Negative.create(func) : func)
        return f 
    end
       
    snum_init = LcProc.new do |args|
        next lc_snum_init(*lc_cast(args,T2))
    end

    def self.lc_val_get_v(func :  LcVal)
        func = get_function(func)
        if func.is_a? Snumber
            val  = lc_cast(func,Snumber).val 
        else
            val  = lc_cast(func,Constant).value 
        end
        if val.is_a? Float
            return num2float(val)
        end
        return num2int(val)
    end

    val_get_v = LcProc.new do |args|
        next internal.lc_val_get_v(*lc_cast(args,T1))
    end

    def self.lc_const_init(f :  LcVal,value : Symbolic)
        set_function(f,value)
        return f
    end

    

    def self.lc_neg_init(f :  LcVal,value :  LcVal)
        check_fun(value)
        neg = Negative.create(get_function(value))
        set_function(f,neg)
        return f
    end

    neg_init = LcProc.new do |args|
        next lc_neg_init(*lc_cast(args,T2))
    end

    def self.lc_binary_op_init(f :  LcVal,left :  LcVal,right :  LcVal,type : Class)
        check_fun(left)
        check_fun(right)
        lft = get_function(left)
        rht = get_function(right)
        tmp = type.new(lft,rht)
        set_function(f,tmp)
        return f
    end

    @[AlwaysInline]
    def self.lc_sum_init(f : LcVal,left : LcVal, right : LcVal)
        return lc_binary_op_init(f,left,right,Sum)
    end

    @[AlwaysInline]
    def self.lc_sub_init(f : LcVal,left : LcVal, right : LcVal)
        return lc_binary_op_init(f,left,right,Sub)
    end

    @[AlwaysInline]
    def self.lc_product_init(f : LcVal,left : LcVal, right : LcVal)
        return lc_binary_op_init(f,left,right,Product)
    end

    @[AlwaysInline]
    def self.lc_division_init(f : LcVal,left : LcVal, right : LcVal)
        return lc_binary_op_init(f,left,right,Division)
    end

    @[AlwaysInline]
    def self.lc_power_init(f : LcVal,left : LcVal, right : LcVal)
        return lc_binary_op_init(f,left,right,Power)
    end

    def self.lc_sfunc_init(f :  LcVal, arg :  LcVal,type)
        check_fun(arg)
        tmp = type.new(get_function(arg))
        set_function(f,tmp)
        return f
    end

    def self.lc_sfunc_arg(f :  LcVal)
        tmp = get_function(f).as(Function).value 
        return build_function(tmp)
    end

    def self.lc_binop_left(f :  LcVal)
        func = get_function(f)
        return Null if func == NanC
        return build_function(lc_cast(func,BinaryOp).left)
    end

    def self.lc_binop_right(f :  LcVal)
        func = get_function(f)
        return Null if func == NanC
        return build_function(lc_cast(func,BinaryOp).right)
    end

    def self.init_symbolic
        @@lc_symbolic = internal.lc_build_internal_class("Symbolic")

        define_allocator(@@lc_symbolic,lc_function_allocate)

        add_method(@@lc_symbolic,"to_s",lc_func_to_s,     0)
        alias_method_str(@@lc_symbolic,"to_s","inspect"       )
        add_method(@@lc_symbolic,"+",lc_func_sum,         1)
        add_method(@@lc_symbolic,"-",lc_func_sub,         1)
        add_method(@@lc_symbolic,"*",lc_func_prod,        1)
        add_method(@@lc_symbolic,"/",lc_func_div,         1)
        add_method(@@lc_symbolic,"\\",lc_func_div,        1)
        add_method(@@lc_symbolic,"**",lc_func_power,      1)
        add_method(@@lc_symbolic,"-@",lc_func_uminus,     0)
        add_method(@@lc_symbolic,"diff",lc_func_diff,     1)
        add_method(@@lc_symbolic,"eval",lc_func_eval,     1)
        add_method(@@lc_symbolic,"vars",lc_func_vars,     0)
        add_method(@@lc_symbolic,"integrate",lc_func_integrate, 2)

        # Class Variable
        var_class = lc_build_internal_class("Variable",@@lc_symbolic)

        add_method(var_class,"init",lc_var_init,           1)
        add_method(var_class,"name",lc_var_name,           0)

        # Class Value
        num_class = lc_build_internal_class("Value",@@lc_symbolic)

        add_method(num_class,"init",lc_snum_init,         1)
        add_method(num_class,"value",lc_val_get_v,        0)

        # Class Constant
        const_class = lc_build_internal_class("Constant",@@lc_symbolic)
        add_method(const_class,"value",lc_val_get_v,       0)

        # Class EClass & PiClass
        e_class  = lc_build_internal_class("EClass",const_class)
        pi_class = lc_build_internal_class("PiClass",const_class)

        const_e_init  = LcProc.new { |args| next lc_const_init(*lc_cast(args,T1),EC)  }
        const_pi_init = LcProc.new { |args| next lc_const_init(*lc_cast(args,T1),PiC) }

        lc_add_internal(e_class,"init",const_e_init,         0)
        lc_add_internal(pi_class,"init",const_pi_init,       0)

        # Class Infinity, NegInfinity, NanClass
        inf_class    = lc_build_internal_class("Infinity",const_class)
        neginf_class = lc_build_internal_class("NegInfinity",inf_class)
        nan_class    = lc_build_internal_class("NanClass",const_class)

        const_inf_init  = LcProc.new { |args| next lc_const_init(*lc_cast(args,T1),PinfinityC) }
        const_ninf_init = LcProc.new { |args| next lc_const_init(*lc_cast(args,T1),NinfinityC) }    
        const_nan_init  = LcProc.new { |args| next lc_const_init(*lc_cast(args,T1),NanC)       }

        lc_add_internal(inf_class,"init",const_inf_init,     0)
        lc_add_internal(neginf_class,"init",const_ninf_init, 0)
        lc_add_internal(nan_class,"init",const_nan_init,     0)

        # Class Negative
        neg_class = internal.lc_build_internal_class("Negative",@@lc_symbolic)
        add_method(neg_class,"init",lc_neg_init,           1)

        # Class BinaryOp
        binary_op_class = lc_build_internal_class("BinaryOp",@@lc_symbolic)
        add_method(binary_op_class,"left",lc_binop_left,        0)
        add_method(binary_op_class,"right",lc_binop_right,      0)

        # Class Sum
        sum_class  = lc_build_internal_class("Sum",binary_op_class)
        add_method(sum_class,"init",lc_sum_init,           2)

        # Class Sub
        sub_class  = lc_build_internal_class("Sub",binary_op_class)
        add_method(sub_class,"init",lc_sub_init,           2)

        # Class Product
        prod_class  = lc_build_internal_class("Product",binary_op_class)
        add_method(prod_class,"init",lc_product_init,      2)
    
        # Class Division
        div_class  = lc_build_internal_class("Division",binary_op_class)
        add_method(div_class,"init",lc_division_init,      2)

        # Class Power
        pow_class  = lc_build_internal_class("Power",binary_op_class)
        add_method(pow_class,"init",lc_power_init,         2)

        # Class Function
        fun_class = lc_build_internal_class("Function",@@lc_symbolic)
        add_method(fun_class,"argument",lc_sfunc_arg, 0)

        # Class Log
        log_class = lc_build_internal_class("Log",fun_class)
        log_init  = LcProc.new { |args| next lc_sfunc_init(*lc_cast(args,T2),Log) }
        lc_add_internal(log_class,"init",log_init,           1)

        # Class Exp
        exp_class = lc_build_internal_class("Exp",fun_class)
        exp_init  = LcProc.new { |args| next lc_sfunc_init(*lc_cast(args,T2),Exp) }
        lc_add_internal(exp_class,"init",exp_init,           1)

        # Class Cos
        cos_class = lc_build_internal_class("Cos",fun_class)
        cos_init  = LcProc.new { |args| next lc_sfunc_init(*lc_cast(args,T2),Cos) }
        lc_add_internal(cos_class,"init",cos_init,           1)

        # Class Acos
        acos_class = lc_build_internal_class("Acos",fun_class)
        acos_init  = LcProc.new { |args| next lc_sfunc_init(*lc_cast(args,T2),Acos) }
        lc_add_internal(acos_class,"init",acos_init,          1)

        # Class Sin
        sin_class = lc_build_internal_class("Sin",fun_class)
        sin_init  = LcProc.new { |args| next lc_sfunc_init(*lc_cast(args,T2),Sin) }
        lc_add_internal(sin_class,"init",sin_init,            1)

        #Class Asin
        asin_class = lc_build_internal_class("Asin",fun_class)
        asin_init  = LcProc.new { |args| next lc_sfunc_init(*lc_cast(args,T2),Asin) }
        lc_add_internal(asin_class,"init",asin_init,          1)

        # Class Tan
        tan_class = lc_build_internal_class("Tan",fun_class)
        tan_init  = LcProc.new { |args| next lc_sfunc_init(*lc_cast(args,T2),Tan) }
        lc_add_internal(tan_class,"init",tan_init,            1)

        # Class Atan
        atan_class = lc_build_internal_class("Atan",fun_class)
        atan_init  = LcProc.new { |args| next lc_sfunc_init(*lc_cast(args,T2),Atan) }
        lc_add_internal(atan_class,"init",atan_init,          1)

        # Class Sqrt
        sqrt_class = lc_build_internal_class("Sqrt",fun_class)
        sqrt_init  = LcProc.new { |args| next lc_sfunc_init(*lc_cast(args,T2),Sqrt) }
        lc_add_internal(sqrt_class,"init",sqrt_init,          1)


        @@sym_dict = {
            Variable     => var_class,
            Snumber      => num_class,
            Constant     => const_class,
            E            => e_class,
            PI           => pi_class,
            PInfinity    => inf_class,
            NInfinity    => neginf_class,
            Nan          => nan_class,
            Negative     => neg_class,
            BinaryOp     => binary_op_class,
            Sum          => sum_class,
            Sub          => sub_class,
            Product      => prod_class,
            Division     => div_class,
            Power        => pow_class,
            Function     => fun_class,
            Cos          => cos_class,
            Acos         => acos_class,
            Sin          => sin_class,
            Asin         => asin_class,
            Tan          => tan_class,
            Atan         => atan_class,
            Log          => log_class,
            Exp          => exp_class,
            Sqrt         => sqrt_class
        }    
    end












    

    
    
end