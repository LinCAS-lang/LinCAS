
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

    
    struct Gls_cpx
        dat : Double[2]
    end
  
    fun gsl_complex_rect(x : Double, y : Double)   : Gls_cpx
    fun gsl_complex_polar(r : Double, th : Double) : Gls_cpx
    fun gsl_complex_arg(z : Gls_cpx)               : Double
    fun gsl_complex_abs(z : Gls_cpx)               : Double
    fun gsl_complex_abs2(z : Gls_cpx)              : Double
    fun gsl_complex_logabs(z : Gls_cpx)            : Double
    
    fun gsl_complex_add(a : Gls_cpx, b : Gls_cpx)     : Gls_cpx
    fun gsl_complex_sub(a : Gls_cpx, b : Gls_cpx)     : Gls_cpx
    fun gsl_complex_mul(a : Gls_cpx, b : Gls_cpx)     : Gls_cpx
    fun gsl_complex_div(a : Gls_cpx, b : Gls_cpx)     : Gls_cpx
    fun gsl_complex_add_real(a : Gls_cpx, b : Double) : Gls_cpx
    fun gsl_complex_sub_real(a : Gls_cpx, b : Double) : Gls_cpx
    fun gsl_complex_mul_real(a : Gls_cpx, b : Double) : Gls_cpx
    fun gsl_complex_div_real(a : Gls_cpx, b : Double) : Gls_cpx

end