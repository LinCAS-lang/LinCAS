
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

@[Link("gsl")]
lib LibComplex

    alias CHAR   = LibC::Char
    alias INT    = LibC::Int
    alias Double = LibC::Double

    
    struct Gsl_cpx
        dat : Double[2]
    end
  
    fun gsl_complex_rect(x : Double, y : Double)   : Gsl_cpx
    fun gsl_complex_polar(r : Double, th : Double) : Gsl_cpx
    fun gsl_complex_arg(z : Gsl_cpx)               : Double
    fun gsl_complex_abs(z : Gsl_cpx)               : Double
    fun gsl_complex_abs2(z : Gsl_cpx)              : Double
    fun gsl_complex_logabs(z : Gsl_cpx)            : Double
    
    fun gsl_complex_add(a : Gsl_cpx, b : Gsl_cpx)     : Gsl_cpx
    fun gsl_complex_sub(a : Gsl_cpx, b : Gsl_cpx)     : Gsl_cpx
    fun gsl_complex_mul(a : Gsl_cpx, b : Gsl_cpx)     : Gsl_cpx
    fun gsl_complex_div(a : Gsl_cpx, b : Gsl_cpx)     : Gsl_cpx
    fun gsl_complex_add_real(a : Gsl_cpx, b : Double) : Gsl_cpx
    fun gsl_complex_sub_real(a : Gsl_cpx, b : Double) : Gsl_cpx
    fun gsl_complex_mul_real(a : Gsl_cpx, b : Double) : Gsl_cpx
    fun gsl_complex_div_real(a : Gsl_cpx, b : Double) : Gsl_cpx
    fun gsl_complex_pow(a : Gsl_cpx, b : Gsl_cpx)     : Gsl_cpx
    fun gsl_complex_pow_real(a : Gsl_cpx, b : Double) : Gsl_cpx

    fun gsl_complex_conjugate(z : Gsl_cpx) : Gsl_cpx
    fun gsl_complex_inverse(z : Gsl_cpx)   : Gsl_cpx
    fun gsl_complex_negative(z : Gsl_cpx)  : Gsl_cpx

    fun gsl_complex_sqrt(z : Gsl_cpx)      : Gsl_cpx
    fun gsl_complex_sqrt_real(n : Double)  : Gsl_cpx

    fun gsl_complex_exp(z : Gsl_cpx)                   : Gsl_cpx
    fun gsl_complex_log(z : Gsl_cpx)                   : Gsl_cpx
    fun gsl_complex_sin(z : Gsl_cpx)                   : Gsl_cpx
    fun gsl_complex_cos(z : Gsl_cpx)                   : Gsl_cpx
    fun gsl_complex_tan(z : Gsl_cpx)                   : Gsl_cpx
    fun gsl_complex_arcsin(z : Gsl_cpx)                : Gsl_cpx
    fun gsl_complex_arccos(z : Gsl_cpx)                : Gsl_cpx
    fun gsl_complex_arctan(z : Gsl_cpx)                : Gsl_cpx
    fun gsl_complex_sinh(z : Gsl_cpx)                  : Gsl_cpx
    fun gsl_complex_cosh(z : Gsl_cpx)                  : Gsl_cpx
    fun gsl_complex_tanh(z : Gsl_cpx)                  : Gsl_cpx
    fun gsl_complex_arcsinh(z : Gsl_cpx)               : Gsl_cpx
    fun gsl_complex_arccosh(z : Gsl_cpx)               : Gsl_cpx
    fun gsl_complex_arctanh(z : Gsl_cpx)               : Gsl_cpx


end