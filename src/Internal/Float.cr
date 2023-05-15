
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

require "./Number"
module LinCAS::Internal

  def self.lc_num_to_cr_f(num :  LcVal)
    unless num.is_a? LcInt || num.is_a? LcFloat
      lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof(num)} into Float")
    end 
    return num2num(num).to_f64
  end

  def self.float2cr(*values)
    tmp = [] of Float64 
    values.each do |v|
      tmp << lc_num_to_cr_i(v, Float64)
    end
    return tmp 
  end

    
  class LcFloat < LcNum
    def initialize(@val : Float64)
    end
    getter val
    def to_s 
      return @val.to_s 
    end
  end

  macro num2bigfloat(num)
    BigFloat.new({{num}})
  end

  macro bigf2flo64(num)
    ({{num}}.round(20)).to_f64
  end
    
  @[AlwaysInline]
  def self.num2float(num : Floatnum)
    return new_float(num)
  end

  @[AlwaysInline]
  def self.float2num(float : LcVal)
    return float.as(LcFloat).val 
  end

  def self.new_float(num : Floatnum)
    flo = lincas_obj_alloc LcFloat, @@lc_float, num.to_f64
    return lc_obj_freeze(flo)
  end

  # :call-seq: 
  #   float + other -> Float
  # It returns a new Float that is the sum between `float`
  # and `other`.
  # ```
  # 4.6 + 2.3 #=> 6.9
  # 5.55 + 2 #=> 7.55
  # ```
  def self.lc_float_sum(n1 :  LcVal, n2 :  LcVal)
    if n2.is_a? LcFloat
      return num2float(float2num(n1) + float2num(n2))
    else
      return lc_num_coerce_bin(n1, n2, "+")
    end
  end

  # :call-seq: 
  #   float - other -> Float
  # It returns a new Float that is the difference between `float`
  # and `other`.
  # ```
  # 4.6 - 2.3 #=> 2.3
  # 5.55 - 2 #=> 3.55
  # ```
  def self.lc_float_sub(n1 :  LcVal, n2 :  LcVal)
    if n2.is_a? LcFloat
      return num2float(float2num(n1) - float2num(n2))
    else
      return lc_num_coerce_bin(n1, n2, "-")
    end
    # Should never get here
    return Null
  end

  # :call-seq: 
  #   float * other -> Float
  # It returns a new Float that is the product between `float`
  # and `other`.
  def self.lc_float_mult(n1 :  LcVal, n2 :  LcVal)
    if n2.is_a? LcFloat
      return num2float(float2num(n1) * float2num(n2))
    else
      return lc_num_coerce_bin(n1, n2, "*")
    end
    # Should never get here
    return Null
  end

  # :call-seq: 
  #   float \ other -> Float
  # It returns a new Float that is the result of the integer
  # division between `float` and `other`. If other is `0` it
  # raises an error.
  # ```
  # 4.6 \ 2.3 #=> 2.0
  # 5.55 \ 2 #=> 3.0
  # 11.9 \ 0 #=> ZeroDivisionError
  # ```
  def self.lc_float_idiv(n1 :  LcVal, n2 :  LcVal)
    if n2.is_a? LcFloat
      if float2num(n2).zero?
        lc_raise(lc_zerodiv_err,"(Division by 0)")
      end
      return num2float(float2num(n1) // float2num(n2))
    else
      return lc_num_coerce_bin(n1, n2, "\\")
    end
    # Should never get here
    return Null
  end

  # :call-seq: 
  #   float / other -> Float
  # It returns a new Float that is the result of the
  # division between `float` and `other`.
  def self.lc_float_fdiv(n1 :  LcVal, n2 :  LcVal)
    if n2.is_a? LcFloat
      return num2float(float2num(n1) / float2num(n2))
    else
      return lc_num_coerce_bin(n1, n2, "/")
    end
    # Should never get here
    return Null
  end

  # :call-seq: 
  #   float % other -> Float
  # It returns a new Float that is the result of the
  # division between `float` and `other`.
  def self.lc_float_modulo(n1 : LcVal, n2 : LcVal)
    if n2.is_a? LcFloat
      if (v2 = float2num(n2)) == 0
        lc_raise(lc_zerodiv_err, "(Division by 0)")
      else
        return num2float(float2num(n1) % float2num(n2))
      end
    else
      return lc_num_coerce_bin(n1, n2, "%")
    end
  end

  # :call-seq: 
  #   float ** other -> Float
  # It raises `float` to the power of `other`.
  # ```
  # 2.0 ** 3 #=> 8.0
  # ```
  def self.lc_float_power(n1 :  LcVal, n2 :  LcVal)
    if n2.is_a? LcFloat
      return num2float(float2num(n1) ** float2num(n2))
    else
      return lc_num_coerce_bin(n1, n2, "**")
    end
    # Should never get here
    return Null
  end

  # :call-seq: 
  #   -float -> Float
  # It returns `float`, negated.
  def self.lc_float_minus(n :  LcVal)
    return new_float(- float2num(n))
  end

  # :call-seq: 
  #   to_s -> Float
  # It returns a string representation of `float`.
  def self.lc_float_to_s(n :  LcVal)
    return build_string(float2num(n).to_s)
  end

  # :call-seq: 
  #   to_i -> Integer
  # It returns `float` truncated to an integer.
  def self.lc_float_to_i(n :  LcVal)
    return num2int(float2num(n).to_i)
  end

  # :call-seq: 
  #   abs -> Float
  # It returns the absolute value of `float`.
  @[AlwaysInline]
  def self.lc_float_abs(n : LcVal)
    val = lc_num_to_cr_f(n)
    return num2float(val.abs)
  end

  # :call-seq: 
  #   round([digits]) -> Float
  # It rounds `float` to a given precision.
  # Default precision is 1.
  def self.lc_float_round(flo : LcVal, argv : LcVal)
    argv  = argv.as(Ary)
    float = float2num(flo)
    num   = argv.empty? ? 1i64 : argv[0]
    unless num.is_a? Intnum 
      num = lc_num_to_cr_i(num)
    end
    return num2float(float.round(num))
  end

  # :call-seq: 
  #   ceil -> Float
  def self.lc_float_ceil(n : LcVal)
    float = lc_num_to_cr_f(n)
    return num2float(LibM.ceil_f64(float))
  end

  # :call-seq: 
  #   floor -> Float
  @[AlwaysInline]
  def self.lc_float_floor(n : LcVal)
    float = lc_num_to_cr_f(n)
    return num2float(LibM.floor_f64(float))
  end

  # :call-seq: 
  #   trunc -> Float
  def self.lc_float_trunc(n : LcVal)
    float = internal.lc_num_to_cr_f(n) 
    return num2float(LibM.trunc_f64(float))
  end

  # :call-seq: 
  #   float == other -> true or false
  # it returns true if and only if `other` has the
  # same value of `self`.
  def self.lc_float_eq(n :  LcVal, obj :  LcVal)
    if obj.is_a? LcFloat
      return val2bool(float2num(n) == float2num(obj))
    else 
      return lc_compare(n,obj)
    end
  end

  @@lc_infinity  = uninitialized LcVal
  @@lc_ninfinity = uninitialized LcVal
  @@lc_nanobj    = uninitialized LcVal

  def self.init_float

    @@lc_float = internal.lc_build_internal_class("Float",@@lc_number)
    lc_undef_allocator(@@lc_float)

    @@lc_infinity  = num2float(Float64::INFINITY)
    @@lc_ninfinity = num2float(-Float64::INFINITY)
    @@lc_nanobj    = num2float(Float64::NAN)
    
    define_method(@@lc_float,"+",lc_float_sum,         1)
    define_method(@@lc_float,"-",lc_float_sub,         1)
    define_method(@@lc_float,"*",lc_float_mult,        1)
    define_method(@@lc_float,"\\",lc_float_idiv,       1)
    define_method(@@lc_float,"/",lc_float_fdiv,        1)
    define_method(@@lc_float,"%",lc_float_modulo,      1)
    define_method(@@lc_float,"**",lc_float_power,      1)
    define_method(@@lc_float,"-@",lc_float_minus,      0)
    define_method(@@lc_float,"to_s",lc_float_to_s,     0)
    define_method(@@lc_float,"to_i",lc_float_to_i,     0)
    define_method(@@lc_float,"to_f",lc_obj_self,       0)
    define_method(@@lc_float,"abs",lc_float_abs,       0)
    define_method(@@lc_float,"round",lc_float_round,  -1)
    define_method(@@lc_float,"floor",lc_float_floor,   0)
    define_method(@@lc_float,"ceil",lc_float_ceil,     0)
    define_method(@@lc_float,"trunc",lc_float_trunc,   0)
    define_method(@@lc_float, "<=>",lc_int_or_flo_cmp, 1)
    
    lc_define_const(@@lc_float,"INFINITY",@@lc_infinity)
    lc_define_const(@@lc_float,"NAN",@@lc_nanobj)
  end
end
