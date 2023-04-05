
# Copyright (c) 2017-2023 Massimiliano Dal Mas
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

  class LcCmx < LcBase
    def initialize(@cmx : LibComplex::Gsl_cpx)
    end
    getter cmx 
  end

  macro set_complex(cpx,cmx)
    lc_cast({{cpx}},LcCmx).cmx = {{cmx}}
    complex_is_alloc({{cpx}})
  end

  macro get_complex(cpx)
    lc_cast({{cpx}},LcCmx).cmx
  end

  macro complex_compute(cpx,v,name, method)
    if {{v}}.is_a? LcCmx
      return {{name.id}}({{cpx}},{{v}})
    elsif {{v}}.is_a? LcNum
      return {{name.id}}_num({{cpx}},{{v}})
    end
    return lc_num_coerce_bin {{cpx}}, {{v}}, {{method}}
  end

  def self.complex_allocate(cmx : LibComplex::Gsl_cpx)
    cmx = lincas_obj_alloc LcCmx, @@lc_complex, cmx
    lc_obj_freeze(cmx)
    return lc_cast(cmx, LcVal)
  end

  @[AlwaysInline]
  def self.new_complex(cmx : LibComplex::Gsl_cpx)
    return complex_allocate cmx
  end

  @[AlwaysInline]
  def self.new_complex(real : Floatnum, complex : Floatnum)
    cpx = LibComplex.gsl_complex_rect(real,complex)
    return new_complex(cpx)
  end

  def self.lc_complex_rect(klass :  LcVal, real :  LcVal, img :  LcVal)
    real,img = float2cr(real,img) 
    cpx      = LibComplex.gsl_complex_rect(real,img)
    return new_complex(cpx)
  end

  def self.lc_complex_polar(cmx :  LcVal, r :  LcVal, th :  LcVal)
    r,th = float2cr(r,th) 
    cpx      = LibComplex.gsl_complex_polar(r,th)
    return new_complex(cpx)
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
    cpx  = get_complex(cpx)
    real = cpx.dat[0]
    img  = cpx.dat[1]
    sign = img < 0 ? '-' : '+'
    buffer = string_buffer_new
    buffer_append_n(buffer,real.to_s,' ',sign,' ',img.abs.to_s,'i')
    buffer_trunc(buffer)
    return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
  end

  {% for name in %w(add sub mul div pow)%}

    private def self.complex_{{name.id}}(v1 :  LcVal, v2 :  LcVal)
      v1  = get_complex(v1)
      v2  = get_complex(v2)
      tmp = LibComplex.gsl_complex_{{name.id}}(v1, v2)
      return new_complex(tmp)
    end

    private def self.complex_{{name.id}}_num(cpx :  LcVal, n :  LcVal)
      cpx = get_complex(cpx)
      n   = lc_num_to_cr_f(n)
      tmp = LibComplex.gsl_complex_{{name.id}}_real(cpx, n)
      return new_complex(tmp)
    end
  {% end %}

  def self.lc_complex_sum(cpx :  LcVal, v :  LcVal)
    complex_compute(cpx, v, complex_add, "+")
  end

  def self.lc_complex_sub(cpx :  LcVal, v :  LcVal)
    complex_compute(cpx, v, complex_sub, "-")
  end

  def self.lc_complex_prod(cpx :  LcVal, v :  LcVal)
    complex_compute(cpx, v, complex_mul, "*")
  end

  def self.lc_complex_div(cpx :  LcVal, v :  LcVal)
    complex_compute(cpx, v, complex_div, "/")
  end

  def self.lc_complex_pow(cpx :  LcVal, v :  LcVal)
    complex_compute(cpx, v, complex_pow, "**")
  end

  def self.lc_complex_conj(cpx :  LcVal)
    cpx = get_complex(cpx)
    cpx = LibComplex.gsl_complex_conjugate(cpx)
    return new_complex(cpx)
  end

  def self.lc_complex_inv(cpx :  LcVal)
    cpx = get_complex(cpx)
    cpx = LibComplex.gsl_complex_inverse(cpx)
    return new_complex(cpx)
  end

  def self.lc_complex_minus(cpx :  LcVal)
    cpx = get_complex(cpx)
    cpx = LibComplex.gsl_complex_negative(cpx)
    return new_complex(cpx)
  end

  private def self.complex_sqrt(cpx :  LcVal)
    cpx = get_complex(cpx)
    tmp = LibComplex.gsl_complex_sqrt(cpx)
    return new_complex(tmp)
  end

  @[AlwaysInline]
  private def self.complex_sqrt_num(n : Floatnum)
    tmp = LibComplex.gsl_complex_sqrt_real(n)
    return new_complex(tmp)
  end

  private def self.complex_sqrt_num(n :  LcVal)
    n   = lc_num_to_cr_f(n)
    return Null unless n
    return complex_sqrt_num(n)
  end

  {% for name in %w|exp sin cos tan log arcsin arccos arctan sinh cosh tanh arcsinh arccosh arctanh| %}
    private def self.complex_{{name.id}}(cpx :  LcVal)
      cpx = get_complex(cpx)
      tmp = LibComplex.gsl_complex_{{name.id}}(cpx)
      return new_complex(tmp)
    end
  {% end %}

  def self.lc_complex_coerce(n1 : LcVal, n2 : LcVal)
    if n2.is_a? LcCmx
      return tuple2array(n2, n1)
    elsif n2.is_a? NumType
      return tuple2array(new_complex(lc_num_to_cr_f(n2), 0f64), n1)
    end
    lc_raise(lc_type_err, "Cant't coerce #{lc_typeof(n2)} into ,#{lc_typeof(n2)}")
  end


  def self.init_complex
    @@lc_complex = lc_build_internal_class("Complex",@@lc_number)
    lc_undef_allocator(@@lc_complex)

    define_singleton_method(@@lc_complex,"rect",lc_complex_rect,    2)
    define_singleton_method(@@lc_complex,"polar",lc_complex_polar,  2)

    define_method(@@lc_complex,"arg",lc_complex_arg,             0)
    define_method(@@lc_complex,"abs",lc_complex_abs,             0)
    define_method(@@lc_complex,"abs2",lc_complex_abs2,           0)
    define_method(@@lc_complex,"logabs",lc_complex_logabs,       0)
    define_method(@@lc_complex,"inspect",lc_complex_inspect,     0)
    define_method(@@lc_complex,"coerce",lc_complex_coerce,       1)
    alias_method_str(@@lc_complex,"inspect","to_s"                )  
    define_method(@@lc_complex,"+",lc_complex_sum,               1)
    define_method(@@lc_complex,"-",lc_complex_sub,               1)
    define_method(@@lc_complex,"*",lc_complex_prod,              1)
    define_method(@@lc_complex,"/",lc_complex_div,               1)
    define_method(@@lc_complex,"**",lc_complex_pow,              1)
    define_method(@@lc_complex,"conjg",lc_complex_conj,          0)
    define_method(@@lc_complex,"inverse",lc_complex_inv,         0)
    define_method(@@lc_complex,"-@",lc_complex_minus,            0)
  end


end