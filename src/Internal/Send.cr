
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module LinCAS::Internal

    def self.send(name,args)
        args = args.to_a
        case name
            # Class `Class`
            when :lc_is_a
                return call_internal_1(:lc_is_a,args)
            when :lc_class_class
                return call_internal(:lc_class_class,args)
            when :lc_class_eq
                return call_internal_1(:lc_class_eq,args)
            when :lc_class_ne
                return call_internal_1(:lc_class_ne,args)

            # Class `Bool`
            when :lc_bool_invert
                return call_internal(:lc_bool_invert,args)
            when :lc_bool_eq
                return call_internal_1(:lc_bool_eq,args)
            when :lc_bool_and
                return call_internal_1(:lc_bool_and,args)
            when :lc_bool_or
                return call_internal_1(:lc_bool_or,args)
            
            # Class `String`
            when :lc_str_concat
                return call_internal_1(:lc_str_concat,args)
            when :lc_str_multiply
                return call_internal_1(:lc_str_multiply,args)
            
            # Class `Integer`
            when :lc_int_sum
                return call_internal_1(:lc_int_sum,args)
            when :lc_int_sub
                return call_internal_1(:lc_int_sub,args)
            when :lc_int_mult
                return call_internal_1(:lc_int_mult,args)
            when :lc_int_idiv
                return call_internal_1(:lc_int_idiv,args)
            when :lc_int_fdiv
                return call_internal_1(:lc_int_fdiv,args)
            when :lc_int_power
                return call_internal_1(:lc_int_power,args)
            when :lc_int_invert
                return call_internal(:lc_int_invert,args)
            when :lc_int_to_s
                return call_internal(:lc_int_to_s,args)
            when :lc_int_to_f
                return call_internal(:lc_int_to_f,args)

            # Number class
            when :lc_num_eq
                return call_internal_1(:lc_num_eq,args)
            when :lc_num_gr
                return call_internal_1(:lc_num_gr,args)
            when :lc_num_sm
                return call_internal_1(:lc_num_sm,args)
            when :lc_num_ge
                return call_internal_1(:lc_num_ge,args)
            when :lc_num_se
                return call_internal_1(:lc_num_se,args)

            # Class Float
            when :lc_float_sum 
                return call_internal_1(:lc_float_sum,args)
            when :lc_float_sub
                return call_internal_1(:lc_float_sub,args)
            when :lc_float_mult
                return call_internal_1(:lc_float_mult,args)
            when :lc_float_idiv
                return call_internal_1(:lc_float_idiv,args)
            when :lc_float_fdiv
                return call_internal_1(:lc_float_fdiv,args)
            when :lc_float_power
                return call_internal_1(:lc_float_power,args)
            when :lc_float_invert
                return call_internal(:lc_float_invert,args)
            when :lc_float_to_s
                return call_internal(:lc_float_to_s,args)
            when :lc_float_to_i
               return call_internal(:lc_float_to_i,args) 
               
            # Class Infinity
            when :lc_inf_to_s
                return call_internal(:lc_inf_to_s,args)
            when :lc_inf_sum
                return call_internal_1(:lc_inf_sum,args)
            when :lc_inf_sub
                return call_internal_1(:lc_inf_sub,args)
            when :lc_inf_mult
                return call_internal_1(:lc_inf_mult,args)
            when :lc_inf_div
                return call_internal_1(:lc_inf_div,args)
            when :lc_inf_power
                return call_internal_1(:lc_inf_power,args)
            when :lc_inf_invert
                return call_internal(:lc_inf_invert,args)
            when :lc_inf_coerce
                return call_internal_1(:lc_inf_coerce,args)

            
            # Class Nan
            when :lc_nan_to_s
                return call_internal(:lc_nan_to_s,args)

            # Class Object
            when :lc_obj_new
                return call_internal(:lc_obj_new,args)
            when :lc_obj_init
                return call_internal(:lc_obj_init,args)
            else
                return Null
        end
    end
end