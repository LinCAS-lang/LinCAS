
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

    struct LcCmx < BaseS
        @cmx   = uninitialized LibComplex::Gsl_cpx
        @alloc = false
        property cmx, alloc 
    end

    macro complex_is_alloc(cpx)
        lc_cast({{cpx}},LcCmx).alloc = true 
    end

    macro complex_allocated?(cpx)
        lc_cast({{cpx}},LcCmx).alloc
    end

    macro set_complex(cpx,cmx)
        lc_cast({{cpx}},LcCmx).cmx = {{cmx}}
        complex_is_alloc({{cpx}})
    end

    macro get_complex(cpx)
        lc_cast({{cpx}},LcCmx).cmx
    end

    macro complex_check2(cpx)
        if !complex_is_alloc({{cpx}})
            lc_raise(LcTypeError,"Uninitialized complex")
            return Null 
        end
    end

    macro complex_compute(cpx,v,name)
        if {{v}}.is_a? LcCmx
            return {{name.id}}({{cpx}},{{v}})
        elsif {{v}}.is_a? LcNum
            return {{name.id}}_num({{cpx}},{{v}})
        end
        lc_raise(LcTypeError,"Expecting complex or Number (#{lc_typeof({{v}})} given)")
        return Null
    end

    def self.complex_allocate
        cmx        = LcCmx.new
        cmx.klass  = ComplexClass
        cmx.data   = ComplexClass.data.clone 
        cmx.id     = pointerof(cmx).hash
        lc_obj_freeze(cmx)
        return lc_cast(cmx,Value)
    end

    def self.build_complex(cmx : LibComplex::Gsl_cpx)
        tmp = complex_allocate
        set_complex(tmp,cmx)
        return tmp 
    end

    def self.lc_complex_rect(klass : Value, real : Value, img : Value)
        nums = float2cr(real,img)
        return Null unless nums 
        real,img = nums 
        cpx      = LibComplex.gsl_complex_rect(real,img)
        return build_complex(cpx)
    end

    complex_rect = LcProc.new do |args|
        next lc_complex_rect(*lc_cast(args,T3))
    end

    def self.lc_complex_polar(cmx : Value, r : Value, th : Value)
        nums = float2cr(r,th)
        return Null unless nums 
        r,th = nums 
        cpx      = LibComplex.gsl_complex_polar(r,th)
        return build_complex(cpx)
    end

    complex_polar = LcProc.new do |args|
        next lc_complex_polar(*lc_cast(args,T3))
    end

    def self.lc_complex_arg(cmx : Value)
        return num2float(
            LibComplex.gsl_complex_arg(get_complex(cmx))
        )
    end

    complex_arg = LcProc.new do |args|
        next lc_complex_arg(*lc_cast(args,T1))
    end

    def self.lc_complex_abs(cmx : Value)
        return num2float(
            LibComplex.gsl_complex_abs(get_complex(cmx))
        )
    end

    complex_abs = LcProc.new do |args|
        next lc_complex_abs(*lc_cast(args,T1))
    end

    def self.lc_complex_abs2(cmx : Value)
        return num2float(
            LibComplex.gsl_complex_abs2(get_complex(cmx))
        )
    end

    complex_abs2 = LcProc.new do |args|
        next lc_complex_abs2(*lc_cast(args,T1))
    end

    def self.lc_complex_logabs(cmx : Value)
        return num2float(
            LibComplex.gsl_complex_logabs(get_complex(cmx))
        )
    end

    complex_logabs = LcProc.new do |args|
        next lc_complex_logabs(*lc_cast(args,T1))
    end

    def self.lc_complex_inspect(cpx : Value)
        complex_check2(cpx)
        cpx  = get_complex(cpx)
        real = cpx.dat[0]
        img  = cpx.dat[1]
        sign = img < 0 ? '-' : '+'
        buffer = string_buffer_new
        buffer_append_n(buffer,real.to_s,' ',sign,' ',img.abs.to_s,'i')
        buffer_trunc(buffer)
        return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
    end

    complex_inspect = LcProc.new do |args|
        next lc_complex_inspect(*lc_cast(args,T1))
    end

    private def self.complex_add(v1 : Value, v2 : Value)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_add(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_add_num(cpx : Value, n : Value)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        n   = num2num(n).to_f64
        tmp = LibComplex.gsl_complex_add_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_sum(cpx : Value, v : Value)
        complex_compute(cpx,v,complex_add)
    end

    complex_sum = LcProc.new do |args|
        next lc_complex_sum(*lc_cast(args,T2))
    end

    private def self.complex_sub(v1 : Value, v2 : Value)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_sub(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_sub_num(cpx : Value, n : Value)
        complex_check2(cpx)
        cpx  = get_complex(cpx)
        n    = num2num(n).to_f64
        tmp  = LibComplex.gsl_complex_sub_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_sub(cpx : Value, v : Value)
        complex_compute(cpx,v,complex_sub)
    end

    complex_sub_ = LcProc.new do |args|
        next lc_complex_sub(*lc_cast(args,T2))
    end

    private def self.complex_mul(v1 : Value, v2 : Value)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_mul(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_mul_num(cpx : Value, n : Value)
        complex_check2(cpx)
        cpx  = get_complex(cpx)
        n    = num2num(n).to_f64
        tmp  = LibComplex.gsl_complex_mul_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_prod(cpx : Value, v : Value)
        complex_compute(cpx,v,complex_mul)
    end

    complex_prod = LcProc.new do |args|
        next lc_complex_prod(*lc_cast(args,T2))
    end

    private def self.complex_div(v1 : Value, v2 : Value)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_div(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_div_num(cpx : Value, n : Value)
        complex_check2(cpx)
        cpx  = get_complex(cpx)
        n    = num2num(n).to_f64
        tmp  = LibComplex.gsl_complex_div_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_div(cpx : Value, v : Value)
        complex_compute(cpx,v,complex_div)
    end

    complex_div_ = LcProc.new do |args|
        next lc_complex_div(*lc_cast(args,T2))
    end

    private def self.complex_pow(v1 : Value, v2 : Value)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_pow(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_pow_num(cpx : Value, n : Value)
        complex_check2(cpx)
        cpx  = get_complex(cpx)
        n    = num2num(n).to_f64
        tmp  = LibComplex.gsl_complex_pow_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_pow(cpx : Value, v : Value)
        complex_compute(cpx,v,complex_pow)
    end

    complex_pow_ = LcProc.new do |args|
        next lc_complex_pow(*lc_cast(args,T2))
    end

    def self.lc_complex_conj(cpx : Value)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        cpx = LibComplex.gsl_complex_conjugate(cpx)
        return build_complex(cpx)
    end

    complex_conj = LcProc.new do |args|
        next lc_complex_conj(*lc_cast(args,T1))
    end

    def self.lc_complex_inv(cpx : Value)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        cpx = LibComplex.gsl_complex_inverse(cpx)
        return build_complex(cpx)
    end

    complex_inv = LcProc.new do |args|
        next lc_complex_inv(*lc_cast(args,T1))
    end

    def self.lc_complex_neg(cpx : Value)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        cpx = LibComplex.gsl_complex_negative(cpx)
        return build_complex(cpx)
    end

    complex_neg = LcProc.new do |args|
        next lc_complex_neg(*lc_cast(args,T1))
    end

    private def self.complex_sqrt(cpx : Value)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        tmp = LibComplex.gsl_complex_sqrt(cpx)
        return build_complex(tmp)
    end

    private def self.complex_sqrt_num(n : Value)
        n   = num_to_cr_f(n)
        return Null unless n
        tmp = LibComplex.gsl_complex_sqrt_real(n)
        return build_complex(tmp)
    end

    {% for name in %w|exp sin cos tan log arcsin arccos arctan sinh cosh tanh arcsinh arccosh arctanh| %}
        private def self.complex_{{name.id}}(cpx : Value)
            complex_check2(cpx)
            cpx = get_complex(cpx)
            tmp = LibComplex.gsl_complex_{{name.id}}(cpx)
            return build_complex(tmp)
        end
    {% end %}


    ComplexClass = lc_build_internal_class("Complex",NumClass)
    lc_undef_allocator(ComplexClass)

    lc_add_static(ComplexClass,"rect",complex_rect,           2)
    lc_add_static(ComplexClass,"polar",complex_polar,         2)

    lc_add_internal(ComplexClass,"arg",complex_arg,           0)
    lc_add_internal(ComplexClass,"abs",complex_abs,           0)
    lc_add_internal(ComplexClass,"abs2",complex_abs2,         0)
    lc_add_internal(ComplexClass,"logabs",complex_logabs,     0)
    lc_add_internal(ComplexClass,"inspect",complex_inspect,   0)
    alias_method_str(ComplexClass,"inspect","to_s")
    lc_add_internal(ComplexClass,"+",complex_sum,             1)
    lc_add_internal(ComplexClass,"-",complex_sub_,            1)
    lc_add_internal(ComplexClass,"*",complex_prod,            1)
    lc_add_internal(ComplexClass,"/",complex_div_,            1)
    lc_add_internal(ComplexClass,"**",complex_pow_,           1)
    lc_add_internal(ComplexClass,"conjg",complex_conj,        0)
    lc_add_internal(ComplexClass,"inverse",complex_inv,       0)
    lc_add_internal(ComplexClass,"-@",complex_neg,            0)


end