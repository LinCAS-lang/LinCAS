
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
        cmx.klass  = @@lc_complex
        cmx.data   = @@lc_complex.data.clone 
        cmx.id     = pointerof(cmx).hash
        lc_obj_freeze(cmx)
        return lc_cast(cmx, LcVal)
    end

    def self.build_complex(cmx : LibComplex::Gsl_cpx)
        tmp = complex_allocate
        set_complex(tmp,cmx)
        return tmp 
    end

    def self.lc_complex_rect(klass :  LcVal, real :  LcVal, img :  LcVal)
        nums = float2cr(real,img)
        return Null unless nums 
        real,img = nums 
        cpx      = LibComplex.gsl_complex_rect(real,img)
        return build_complex(cpx)
    end

    def self.lc_complex_polar(cmx :  LcVal, r :  LcVal, th :  LcVal)
        nums = float2cr(r,th)
        return Null unless nums 
        r,th = nums 
        cpx      = LibComplex.gsl_complex_polar(r,th)
        return build_complex(cpx)
    end

    def self.lc_complex_arg(cmx :  LcVal)
        return num2float(
            LibComplex.gsl_complex_arg(get_complex(cmx))
        )
    end

    def self.lc_complex_abs(cmx :  LcVal)
        return num2float(
            LibComplex.gsl_complex_abs(get_complex(cmx))
        )
    end

    def self.lc_complex_abs2(cmx :  LcVal)
        return num2float(
            LibComplex.gsl_complex_abs2(get_complex(cmx))
        )
    end

    def self.lc_complex_logabs(cmx :  LcVal)
        return num2float(
            LibComplex.gsl_complex_logabs(get_complex(cmx))
        )
    end

    def self.lc_complex_inspect(cpx :  LcVal)
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

    private def self.complex_add(v1 :  LcVal, v2 :  LcVal)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_add(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_add_num(cpx :  LcVal, n :  LcVal)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        n   = num2num(n).to_f64
        tmp = LibComplex.gsl_complex_add_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_sum(cpx :  LcVal, v :  LcVal)
        complex_compute(cpx,v,complex_add)
    end

    private def self.complex_sub(v1 :  LcVal, v2 :  LcVal)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_sub(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_sub_num(cpx :  LcVal, n :  LcVal)
        complex_check2(cpx)
        cpx  = get_complex(cpx)
        n    = num2num(n).to_f64
        tmp  = LibComplex.gsl_complex_sub_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_sub(cpx :  LcVal, v :  LcVal)
        complex_compute(cpx,v,complex_sub)
    end

    private def self.complex_mul(v1 :  LcVal, v2 :  LcVal)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_mul(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_mul_num(cpx :  LcVal, n :  LcVal)
        complex_check2(cpx)
        cpx  = get_complex(cpx)
        n    = num2num(n).to_f64
        tmp  = LibComplex.gsl_complex_mul_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_prod(cpx :  LcVal, v :  LcVal)
        complex_compute(cpx,v,complex_mul)
    end

    private def self.complex_div(v1 :  LcVal, v2 :  LcVal)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_div(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_div_num(cpx :  LcVal, n :  LcVal)
        complex_check2(cpx)
        cpx  = get_complex(cpx)
        n    = num2num(n).to_f64
        tmp  = LibComplex.gsl_complex_div_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_div(cpx :  LcVal, v :  LcVal)
        complex_compute(cpx,v,complex_div)
    end

    private def self.complex_pow(v1 :  LcVal, v2 :  LcVal)
        complex_check2(v1)
        complex_check2(v1)
        v1  = get_complex(v1)
        v2  = get_complex(v2)
        tmp = LibComplex.gsl_complex_pow(v1,v2)
        return build_complex(tmp)
    end

    private def self.complex_pow_num(cpx :  LcVal, n :  LcVal)
        complex_check2(cpx)
        cpx  = get_complex(cpx)
        n    = num2num(n).to_f64
        tmp  = LibComplex.gsl_complex_pow_real(cpx,n)
        return build_complex(tmp)
    end

    def self.lc_complex_pow(cpx :  LcVal, v :  LcVal)
        complex_compute(cpx,v,complex_pow)
    end

    def self.lc_complex_conj(cpx :  LcVal)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        cpx = LibComplex.gsl_complex_conjugate(cpx)
        return build_complex(cpx)
    end

    def self.lc_complex_inv(cpx :  LcVal)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        cpx = LibComplex.gsl_complex_inverse(cpx)
        return build_complex(cpx)
    end

    def self.lc_complex_neg(cpx :  LcVal)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        cpx = LibComplex.gsl_complex_negative(cpx)
        return build_complex(cpx)
    end

    private def self.complex_sqrt(cpx :  LcVal)
        complex_check2(cpx)
        cpx = get_complex(cpx)
        tmp = LibComplex.gsl_complex_sqrt(cpx)
        return build_complex(tmp)
    end

    @[AlwaysInline]
    private def self.complex_sqrt_num(n : Floatnum)
        tmp = LibComplex.gsl_complex_sqrt_real(n)
        return build_complex(tmp)
    end

    private def self.complex_sqrt_num(n :  LcVal)
        n   = lc_num_to_cr_f(n)
        return Null unless n
        return complex_sqrt_num(n)
    end

    {% for name in %w|exp sin cos tan log arcsin arccos arctan sinh cosh tanh arcsinh arccosh arctanh| %}
        private def self.complex_{{name.id}}(cpx :  LcVal)
            complex_check2(cpx)
            cpx = get_complex(cpx)
            tmp = LibComplex.gsl_complex_{{name.id}}(cpx)
            return build_complex(tmp)
        end
    {% end %}


    def init_complex
        @@lc_complex = lc_build_internal_class("Complex",@@lc_number)
        lc_undef_allocator(@@lc_complex)

        add_static_method(@@lc_complex,"rect",lc_complex_rect,    2)
        add_static_method(@@lc_complex,"polar",lc_complex_polar,  2)

        add_method(@@lc_complex,"arg",lc_complex_arg,             0)
        add_method(@@lc_complex,"abs",lc_complex_abs,             0)
        add_method(@@lc_complex,"abs2",lc_complex_abs2,           0)
        add_method(@@lc_complex,"logabs",lc_complex_logabs,       0)
        add_method(@@lc_complex,"inspect",lc_complex_inspect,     0)
        alias_method_str(@@lc_complex,"inspect","to_s"                )  
        add_method(@@lc_complex,"+",lc_complex_sum,               1)
        add_method(@@lc_complex,"-",lc_complex_sub,               1)
        add_method(@@lc_complex,"*",lc_complex_prod,              1)
        add_method(@@lc_complex,"/",lc_complex_div,               1)
        add_method(@@lc_complex,"**",lc_complex_pow,              1)
        add_method(@@lc_complex,"conjg",lc_complex_conj,          0)
        add_method(@@lc_complex,"inverse",lc_complex_inv,         0)
        add_method(@@lc_complex,"-@",lc_complex_neg,              0)
    end


end