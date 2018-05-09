
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

    alias Symbolic_t = Symbolic | Value

    class LcFunction < BaseC
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
        lc_cast({{obj}},LcFunction).func = {{func}}
    end

    macro get_function(obj)
        lc_cast({{obj}},LcFunction).func
    end

    private def self.to_symbolic(*values) : Array(Symbolic)
        tmp = [] of Symbolic
        values.each do |el|
            if el.is_a? LcFunction
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

    def self.function_allocate(klass : LcClass)
        tmp = LcFunction.new
        tmp.klass = klass 
        tmp.data  = klass.data.clone 
        tmp.id    = tmp.object_id 
        return lc_cast(tmp,Value)
    end

    function_allocator = LcProc.new do |args|
        args = lc_cast(args,T1)
        next function_allocate(lc_cast(args[0],LcClass))
    end

    def self.build_function
        return function_allocate(SymbolicClass)
    end

    def self.build_function(func : Symbolic)
        tmp = function_allocate(SymDict[func.class])
        set_function(tmp,func)
        return tmp
    end

    def self.lc_func_to_s(obj : Value)
        return build_string_recycle(get_function(obj).to_s.to_s)
    end

    func_to_s = LcProc.new do |args|
        next lc_func_to_s(*lc_cast(args,T1))
    end

    {% for name in %w|sum sub prod div power|%}
        def self.lc_func_{{name.id}}(f1 : Value, f2 : Value)
            check_fun(f2)
            return build_function(s_{{name.id}}(get_function(f1),get_function(f2)))
        end
    {% end %}

    func_sum = LcProc.new do |args|
        next lc_func_sum(*lc_cast(args,T2))
    end

    func_sub = LcProc.new do |args|
        next lc_func_sub(*lc_cast(args,T2))
    end

    func_prod = LcProc.new do |args|
        next lc_func_prod(*lc_cast(args,T2))
    end

    func_div = LcProc.new do |args|
        next lc_func_div(*lc_cast(args,T2))
    end

    func_power = LcProc.new do |args|
        next lc_func_power(*lc_cast(args,T2))
    end

    def self.lc_func_uminus(f : Value)
        return build_function(-get_function(f))
    end

    func_uminus = LcProc.new do |args|
        next lc_func_uminus(*lc_cast(args,T1))
    end

    def self.lc_func_diff(f : Value, var : Value)
        check_fun(var)
        ensure_var(var)
        func = get_function(f)
        v    = get_function(var)
        return build_function(func.diff(v))
    end

    func_diff = LcProc.new do |args|
        next lc_func_diff(*lc_cast(args,T2))
    end

    def self.lc_func_eval(f : Value, dict : Value)
        hash_check(dict)
        tmp = get_function(f).eval(lc_cast(dict,LcHash))
        return num_auto(tmp)
    end

    func_eval = LcProc.new do |args|
        next lc_func_eval(*lc_cast(args,T2))
    end

    def self.lc_func_params(f : Value)
        func = get_function(f)
        tmp  = [] of Variable
        ary  = build_ary_new
        func.get_params(tmp)
        tmp.each do |param|
            lc_ary_push(ary,build_function(param))
        end
        return ary 
    end

    func_params = LcProc.new do |args|
        next lc_func_params(*lc_cast(args,T1))
    end

    def self.lc_func_integrate(f : Value, a : Value, b : Value)
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

    func_integrate = LcProc.new do |args|
        next lc_func_integrate(*lc_cast(args,T3))
    end

    def self.lc_var_init(f : Value, string : Value)
        check_string(string)
        str = string2cr(string).as(String)
        v   = Variable.new(str)
        set_function(f,v)
        return f 
    end

    var_init = LcProc.new do |args|
        next lc_var_init(*lc_cast(args,T2))
    end

    def self.lc_var_name(func : Value)
        func = get_function(func)
        return build_string(lc_cast(func,Variable).name)
    end

    var_name = LcProc.new do |args|
        next internal.lc_var_name(*lc_cast(args,T1))
    end

    def self.lc_snum_init(f : Value, value : Value)
        if !(value.is_a? Value)
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

    def self.lc_val_get_v(func : Value)
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

    def self.lc_const_init(f : Value,value : Symbolic)
        set_function(f,value)
        return f
    end

    const_e_init = LcProc.new do |args|
        next lc_const_init(*lc_cast(args,T1),EC)
    end

    const_pi_init = LcProc.new do |args|
        next lc_const_init(*lc_cast(args,T1),PiC)
    end

    const_inf_init = LcProc.new do |args|
        next lc_const_init(*lc_cast(args,T1),PinfinityC)
    end
    
    const_ninf_init = LcProc.new do |args|
        next lc_const_init(*lc_cast(args,T1),NinfinityC)
    end

    const_nan_init = LcProc.new do |args|
        next lc_const_init(*lc_cast(args,T1),NanC)
    end

    def self.lc_neg_init(f : Value,value : Value)
        check_fun(value)
        neg = Negative.create(get_function(value))
        set_function(f,neg)
        return f
    end

    neg_init = LcProc.new do |args|
        next lc_neg_init(*lc_cast(args,T2))
    end

    def self.lc_binary_op_init(f : Value,left : Value,right : Value,type : Class)
        check_fun(left)
        check_fun(right)
        lft = get_function(left)
        rht = get_function(right)
        tmp = type.new(lft,rht)
        set_function(f,tmp)
        return f
    end

    sum_init = LcProc.new do |args|
        next lc_binary_op_init(*lc_cast(args,T3),Sum)
    end

    sub_init = LcProc.new do |args|
        next lc_binary_op_init(*lc_cast(args,T3),Sub)
    end

    product_init = LcProc.new do |args|
        next lc_binary_op_init(*lc_cast(args,T3),Product)
    end

    division_init = LcProc.new do |args|
        next lc_binary_op_init(*lc_cast(args,T3),Division)
    end

    power_init = LcProc.new do |args|
        next lc_binary_op_init(*lc_cast(args,T3),Power)
    end

    def self.lc_sfunc_init(f : Value, arg : Value,type)
        check_fun(arg)
        tmp = type.new(get_function(arg))
        set_function(f,tmp)
        return f
    end

    cos_init = LcProc.new do |args|
        next lc_sfunc_init(*lc_cast(args,T2),Cos)
    end

    sin_init = LcProc.new do |args|
        next lc_sfunc_init(*lc_cast(args,T2),Sin)
    end

    acos_init = LcProc.new do |args|
        next lc_sfunc_init(*lc_cast(args,T2),Acos)
    end

    asin_init = LcProc.new do |args|
        next lc_sfunc_init(*lc_cast(args,T2),Asin)
    end

    tan_init = LcProc.new do |args|
        next lc_sfunc_init(*lc_cast(args,T2),Tan)
    end

    atan_init = LcProc.new do |args|
        next lc_sfunc_init(*lc_cast(args,T2),Atan)
    end

    log_init = LcProc.new do |args|
        next lc_sfunc_init(*lc_cast(args,T2),Log)
    end

    exp_init = LcProc.new do |args|
        next lc_sfunc_init(*lc_cast(args,T2),Exp)
    end

    sqrt_init = LcProc.new do |args|
        next lc_sfunc_init(*lc_cast(args,T2),Sqrt)
    end

    def self.lc_sfunc_arg(f : Value)
        tmp = get_function(f).as(Function).value 
        return build_function(tmp)
    end

    sfunc_arg = LcProc.new do |args|
        next lc_sfunc_arg(*lc_cast(args,T1))
    end

    def self.lc_binop_left(f : Value)
        func = get_function(f)
        return Null if func == NanC
        return build_function(lc_cast(func,BinaryOp).left)
    end

    binop_left = LcProc.new do |args|
        next lc_binop_left(*lc_cast(args,T1))
    end

    def self.lc_binop_right(f : Value)
        func = get_function(f)
        return Null if func == NanC
        return build_function(lc_cast(func,BinaryOp).right)
    end

    binop_right = LcProc.new do |args|
        next lc_binop_right(*lc_cast(args,T1))
    end

    SymbolicClass = internal.lc_build_internal_class("Symbolic")

    internal.lc_set_allocator(SymbolicClass,function_allocator)

    internal.lc_add_internal(SymbolicClass,"to_s",func_to_s,     0)
    internal.lc_add_internal(SymbolicClass,"inspect",func_to_s,  0)
    internal.lc_add_internal(SymbolicClass,"+",func_sum,         1)
    internal.lc_add_internal(SymbolicClass,"-",func_sub,         1)
    internal.lc_add_internal(SymbolicClass,"*",func_prod,        1)
    internal.lc_add_internal(SymbolicClass,"/",func_div,         1)
    internal.lc_add_internal(SymbolicClass,"\\",func_div,        1)
    internal.lc_add_internal(SymbolicClass,"^",func_power,       1)
    internal.lc_add_internal(SymbolicClass,"-@",func_uminus,     0)
    internal.lc_add_internal(SymbolicClass,"diff",func_diff,     1)
    internal.lc_add_internal(SymbolicClass,"eval",func_eval,     1)
    internal.lc_add_internal(SymbolicClass,"params",func_params, 0)
    internal.lc_add_internal(SymbolicClass,"integrate",func_integrate, 2)

    VarClass = internal.lc_build_internal_class("Variable",SymbolicClass)

    internal.lc_add_internal(VarClass,"init",var_init,           1)
    internal.lc_add_internal(VarClass,"name",var_name,           0)

    SnumClass = internal.lc_build_internal_class("Value",SymbolicClass)

    internal.lc_add_internal(SnumClass,"init",snum_init,         1)
    internal.lc_add_internal(SnumClass,"value",val_get_v,        0)

    ConstClass = internal.lc_build_internal_class("Constant",SymbolicClass)
    internal.lc_add_internal(ConstClass,"value",val_get_v,       0)

    EClass  = internal.lc_build_internal_class("EClass",ConstClass)
    PiClass = internal.lc_build_internal_class("PiClass",ConstClass)

    internal.lc_add_internal(EClass,"init",const_e_init,         0)
    internal.lc_add_internal(PiClass,"init",const_pi_init,       0)

    InfClass    = internal.lc_build_internal_class("Infinity",ConstClass)
    NegInfClass = internal.lc_build_internal_class("NegInfinity",InfClass)
    NanClass    = internal.lc_build_internal_class("NanClass",ConstClass)

    internal.lc_add_internal(InfClass,"init",const_inf_init,     0)
    internal.lc_add_internal(NegInfClass,"init",const_ninf_init, 0)
    internal.lc_add_internal(NanClass,"init",const_nan_init,     0)

    NegClass = internal.lc_build_internal_class("Negative",SymbolicClass)
    internal.lc_add_internal(NegClass,"init",neg_init,           1)

    BinaryOpC = internal.lc_build_internal_class("BinaryOp",SymbolicClass)
    internal.lc_add_internal(BinaryOpC,"left",binop_left,        0)
    internal.lc_add_internal(BinaryOpC,"right",binop_right,      0)

    SumClass  = internal.lc_build_internal_class("Sum",BinaryOpC)
    internal.lc_add_internal(SumClass,"init",sum_init,           2)

    SubClass  = internal.lc_build_internal_class("Sub",BinaryOpC)
    internal.lc_add_internal(SubClass,"init",sub_init,           2)

    ProdClass  = internal.lc_build_internal_class("Product",BinaryOpC)
    internal.lc_add_internal(ProdClass,"init",product_init,      2)

    DivClass  = internal.lc_build_internal_class("Division",BinaryOpC)
    internal.lc_add_internal(DivClass,"init",division_init,      2)

    PowClass  = internal.lc_build_internal_class("Power",BinaryOpC)
    internal.lc_add_internal(PowClass,"init",power_init,         2)

    FunctionClass = internal.lc_build_internal_class("Function",SymbolicClass)
    internal.lc_add_internal(FunctionClass,"argument",sfunc_arg, 0)

    LogClass = internal.lc_build_internal_class("Log",FunctionClass)
    internal.lc_add_internal(LogClass,"init",log_init,           1)

    ExpClass = internal.lc_build_internal_class("Exp",FunctionClass)
    internal.lc_add_internal(ExpClass,"init",exp_init,           1)

    CosClass = internal.lc_build_internal_class("Cos",FunctionClass)
    internal.lc_add_internal(CosClass,"init",cos_init,           1)

    AcosClass = internal.lc_build_internal_class("Acos",FunctionClass)
    internal.lc_add_internal(AcosClass,"init",acos_init,          1)

    SinClass = internal.lc_build_internal_class("Sin",FunctionClass)
    internal.lc_add_internal(SinClass,"init",sin_init,            1)

    AsinClass = internal.lc_build_internal_class("Asin",FunctionClass)
    internal.lc_add_internal(AsinClass,"init",asin_init,          1)

    TanClass = internal.lc_build_internal_class("Tan",FunctionClass)
    internal.lc_add_internal(TanClass,"init",tan_init,            1)

    AtanClass = internal.lc_build_internal_class("Atan",FunctionClass)
    internal.lc_add_internal(AtanClass,"init",atan_init,          1)

    SqrtClass = internal.lc_build_internal_class("Sqrt",FunctionClass)
    internal.lc_add_internal(SqrtClass,"init",sqrt_init,          1)




    SymDict = {
        Variable     => VarClass,
        Snumber      => SnumClass,
        Constant     => ConstClass,
        E            => EClass,
        PI           => PiClass,
        PInfinity    => InfClass,
        NInfinity    => NegInfClass,
        Nan          => NanClass,
        Negative     => NegClass,
        BinaryOp     => BinaryOpC,
        Sum          => SumClass,
        Sub          => SubClass,
        Product      => ProdClass,
        Division     => DivClass,
        Power        => PowClass,
        Function     => FunctionClass,
        Cos          => CosClass,
        Acos         => AcosClass,
        Sin          => SinClass,
        Asin         => AsinClass,
        Tan          => TanClass,
        Atan         => AtanClass,
        Log          => LogClass,
        Exp          => ExpClass,
        Sqrt         => SqrtClass
    }












    

    
    
end