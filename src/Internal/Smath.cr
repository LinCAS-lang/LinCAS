
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

    # smath_cos = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     check_fun(arg,false)
    #     next build_function(Cos.create(get_function(arg)))
    # end

    # smath_acos = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     check_fun(arg,false)
    #     next build_function(Acos.create(get_function(arg)))
    # end

    # smath_sin = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     check_fun(arg,false)
    #     next build_function(Sin.create(get_function(arg)))
    # end

    # smath_asin = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     check_fun(arg,false)
    #     next build_function(Asin.create(get_function(arg)))
    # end

    # smath_tan = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     check_fun(arg,false)
    #     next build_function(Tan.create(get_function(arg)))
    # end

    # smath_atan = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     check_fun(arg,false)
    #     next build_function(Atan.create(get_function(arg)))
    # end

    # smath_exp = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     check_fun(arg,false)
    #     next build_function(Exp.create(get_function(arg)))
    # end

    # smath_log = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     check_fun(arg,false)
    #     next build_function(Log.create(get_function(arg)))
    # end

    # smath_sqrt = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     check_fun(arg,false)
    #     next build_function(Sqrt.create(get_function(arg)))
    # end

    # smath_variable = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     str = string2cr(arg)
    #     if str 
    #         next build_function(Variable.new(str))
    #     else
    #         next Null
    #     end
    # end

    # smath_const = LcProc.new do |args|
    #     arg = lc_cast(args,T2)[1]
    #     if arg.is_a? LcNum 
    #         v = num2num(arg)
    #         if v.is_a? Float 
    #             lc_warn("Symbolic floats not supported yiet")
    #             v = v.round(0).to_i 
    #         end
    #         if v < 0 
    #             if v.is_a? BigInt
    #                 lc_warn("Symbolic BigInt not supported yiet")
    #                 next build_function(NinfinityC) 
    #             end
    #             next build_function(Negative.new(Snumber.new(v.abs)))
    #         else
    #             next build_function(PinfinityC) if v.is_a? BigInt
    #             next build_function(Snumber.new(v))
    #         end
    #     else
    #         lc_raise(lc_type_err,"Expecting number (#{lc_typeof(arg)} given)")
    #         next Null 
    #     end
    # end

    #SmathM = internal.lc_build_internal_module("Smath")
    
    # internal.lc_module_add_internal(SmathM,"s_cos",smath_cos,          1)
    # internal.lc_module_add_internal(SmathM,"s_acos",smath_acos,        1)
    # internal.lc_module_add_internal(SmathM,"s_sin",smath_sin,          1)
    # internal.lc_module_add_internal(SmathM,"s_asin",smath_asin,        1)
    # internal.lc_module_add_internal(SmathM,"s_tan",smath_tan,          1)
    # internal.lc_module_add_internal(SmathM,"s_atan",smath_atan,        1)
    # internal.lc_module_add_internal(SmathM,"s_cos",smath_cos,          1)
    # internal.lc_module_add_internal(SmathM,"s_exp",smath_exp,          1)
    # internal.lc_module_add_internal(SmathM,"s_log",smath_log,          1)
    # internal.lc_module_add_internal(SmathM,"s_sqrt",smath_sqrt,        1)
    # internal.lc_module_add_internal(SmathM,"variable",smath_variable,  1)
    # internal.lc_module_add_internal(SmathM,"constant",smath_const,     1)

    # internal.lc_define_const(SmathM,"S_NAN",     build_function(NanC)        )
    # internal.lc_define_const(SmathM,"S_PI",      build_function(PiC)         )
    # internal.lc_define_const(SmathM,"S_E",       build_function(EC)          )
    # internal.lc_define_const(SmathM,"S_INFINITY",build_function(PinfinityC)  )

    
end