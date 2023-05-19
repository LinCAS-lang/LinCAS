
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

  alias NumType = LcInt | LcFloat

  macro positive_num(v)
    ({{v}}.as(LcNum).val > 0)
  end

  macro num2num(v)
    {{v}}.as(LcNum).val 
  end

  macro check_num(v)
    if !({{v}}.is_a? LcNum)
      lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof({{v}})} into Number")
    end
  end

  abstract class LcNum < LcBase
  end

  class LcNumI < LcNum
    def initialize(@val = 0.as(Num)); end
    property val 
  end

  @[AlwaysInline]
  protected def self.num_append(buffer : String_buffer,value :  LcVal)
    buffer_append(buffer,num2num(value).to_s)
  end

  @[AlwaysInline]
  protected def self.num_auto(value : Num)
    if value.is_a? Float 
      return num2float(value)
    end
    return num2int(value)
  end

  def self.new_number(klass :  LcVal)
    klass = klass.as(LcClass)
    num   = lincas_obj_alloc LcNumI, lc_cast(klass, LcClass)
    return lc_obj_freeze(num)
  end

  @[AlwaysInline]
  def self.lc_number_allocate(klass : LcVal)
    return new_number(klass)
  end

  def self.do_coerce(v1 :  LcVal, v2 :  LcVal, error : Bool)
    if !lc_obj_responds_to? v2, "coerce"
      if error
        lc_raise(lc_type_err, "Cant't coerce #{lc_typeof(v2)} into ,#{lc_typeof(v1)}")
      end
      return nil
    end
    ary = Exec.lc_call_fun(v2, "coerce", v1)
    
    if !error && ary == Null
      return nil
    end
    if !(ary.is_a? LcArray) || !(ary_size(ary) == 2)
      lc_raise(lc_type_err,"Coerce must return [x,y]")
    end
    return ary
  end 

  def self.lc_num_coerce_bin(v1 :  LcVal, v2 :  LcVal, method : String)
    if v1.is_a? NumType && v2.is_a? NumType
      v1 = num2float(num2num(v1).to_f)
      v2 = num2float(num2num(v2).to_f)
      return Exec.lc_call_fun(v1, method, v2)
    end
    # We can safely use #not_nil! because `do_coerce` raises
    # an exception instead of returning `nil` in this case
    c = do_coerce(v1, v2, true).not_nil!
    return Exec.lc_call_fun(
      lc_ary_get(c, num2int(0)),
      method,
      lc_ary_get(c, num2int(1))
    )
  end

  def self.lc_num_coerce_cmp(v1 :  LcVal, v2 :  LcVal, method : String)
    if (c = do_coerce(v1, v2, false))
      return Exec.lc_call_fun(
        lc_ary_get(c, num2int(0)),
        method,
        lc_ary_get(c, num2int(1))
      )
    end
    return Null
  end

  def self.lc_num_coerce_rel_op(v1 : LcVal, v2 : LcVal, method : String)
    if !(c = do_coerce(v1, v2, false))
      lc_comp_err(v1, v2)
    else
      ensure_cmp(
        Exec.lc_call_fun(
          lc_ary_get(c, num2int(0)), 
          method, 
          lc_ary_get(c, num2int(2))
        ), 
        v1, 
        v2
      )
    end
  end

  @[AlwaysInline]
  def self.lc_comp_err(v1 : LcVal, v2 : LcVal)
    lc_raise(lc_arg_err, "Comparison between #{lc_typeof(v1)} and #{lc_typeof(v2)} failed")
  end

  @[AlwaysInline]
  def self.ensure_cmp(res : LcVal, v1 : LcVal, v2 : LcVal)
    if res == Null
      lc_comp_err(v1, v2)
    end
    return res
  end

  def self.lc_cmpint(value : LcVal, v1 : LcVal, v2 : LcVal)
    if value == Null
      lc_comp_err(v1, v2)
    end
    if value.is_a? NumType
      t = num2num(value)
      return t > 0 ? 1 : t == 0 ? 0 : -1
    else
      return 1 if test(Exec.lc_call_fun(value, ">", num2int(0)))
      return -1 if test(Exec.lc_call_fun(value, "<", num2int(0)))
      return 0
    end
  end

  def self.float_step_size(a : Float64, b : Float64, step : Float64, inclusive : Bool)
    if step == 0
      return @@lc_infinity
    end
    n = (b - a) / step
    error = (a.abs + b.abs + (b - a).abs) / step.abs * Float64::EPSILON
    if step.infinite?
      val = step > 0 ? (a <= b ? 1 : 0 ) : (a >= b ? 1 : 0)
      return num2float(val)
    end
    error = 0.5 if error > 0.5
    if !inclusive
      return num2float 0.0 if n <= 0
      if n < 1
        n = 0.0
      else
        n = (n - error).floor
      end
    else
      return num2float 0.0 if n < 0
      n = (n + error).floor
    end
    return num2float n + 1
  end

  def self.lincas_num_interval_step_size(a : LcVal, b : LcVal, step : LcVal, inclusive : Bool)
    if a.is_a?(LcInt) && b.is_a?(LcInt) && step.is_a?(LcInt)
      st = int2num(step)
      if st.zero?
        return @@lc_infinity
      end
      delta = int2num(b) - int2num(a)
      if st < 0
        st = -st
        delta = -delta
      end
      delta -= 1 if !inclusive
      return num2int(0) if delta < 0
      return num2int(delta // st + 1)
    elsif a.is_a?(LcFloat) || b.is_a?(LcFloat) || step.is_a?(LcFloat)
      a = lc_num_to_float a
      b = lc_num_to_float b
      step = lc_num_to_float step
      return float_step_size a, b, step, inclusive
    else
      cmp = ">"
      case lc_cmpint(lc_num_coerce_cmp(step, num2int(0), cmp), step, num2int(0))
      when 0 then return @@lc_infinity
      when -1 then cmp = "<"
      end

      return num2int(0) if test(Exec.lc_call_fun(a, cmp, b))
      r = Exec.lc_call_fun(Exec.lc_call_fun(b, "-", a), "/", step)

      # if inclusive || ((a + r * step) cmp b)
      if inclusive || test(Exec.lc_call_fun(Exec.lc_call_fun(a, "+", Exec.lc_call_fun(r, "*", step)), cmp, b))
        r = Exec.lc_call_fun(r, "+", num2int(1))
      end
      return r
    end
  end

  @[AlwaysInline]
  def self.lc_num_hash(n :  LcVal)
    return num2int(num2num(n).hash.to_i64)
  end

  def self.lincas_int_or_flo_cmp(n : LcVal, obj : LcVal)
    return lc_cmpint ensure_cmp(lc_int_or_flo_cmp(n, obj), n, obj), n, obj
  end

  # :call-seq:
  #   number <=> other -> -1, 0, +1 or `null`
  # It returns -1, 0, +1 according to whether
  # `number` is less, equal or greated than `other`.
  #
  # It returns `null` if the two entities are incomparable
  def self.lc_int_or_flo_cmp(n : LcVal, obj : LcVal)
    if obj.is_a? NumType
      x = num2num(n)
      y = num2num(obj)
      if x == y
        return num2int(0)
      elsif x > y
        return num2int(1)
      end
      return num2int(-1)
    else
      return lc_num_coerce_cmp(n, obj, "<=>")
    end
  end

  # :call-seq:
  #   number > other -> true or false
  # It returns true if and only if `float` is greater
  # than `other`.
  def self.lc_num_gr(n1 :  LcVal, n2 :  LcVal)
    if n1.is_a? NumType && n2.is_a? NumType
      return val2bool(num2num(n1) > num2num(n2))
    else 
      return lc_num_coerce_rel_op(n1, n2, ">")
    end
  end

  # :call-seq:
  #   number < other -> true or false
  # It returns true if and only if `float` is less
  # than `other`.
  def self.lc_num_sm(n1 :  LcVal, n2 :  LcVal)
    if n1.is_a? NumType && n2.is_a? NumType
      return val2bool(num2num(n1) < num2num(n2))
    else 
      return lc_num_coerce_rel_op(n1, n2, "<")
    end
  end

  # :call-seq:
  #   number >= other -> true or false
  # It returns true if and only if `float` is greater
  # than or equal to `other`.
  def self.lc_num_ge(n1 :  LcVal, n2 :  LcVal)
    if n1.is_a? NumType && n2.is_a? NumType  
      return val2bool(num2num(n1) >= num2num(n2))
    else 
      return lc_num_coerce_rel_op(n1, n2, ">=")
    end
  end

  # :call-seq:
  #   number <= other -> true or false
  # It returns true if and only if `float` is less
  # than or equal to `other`.
  def self.lc_num_se(n1 :  LcVal, n2 :  LcVal)
    if n1.is_a? NumType && n2.is_a? NumType
      return val2bool(num2num(n1) <= num2num(n2))
    else 
      return lc_num_coerce_rel_op(n1, n2, "<=)")
    end
  end

  # :call-seq:
  #   zero? -> true or false
  # It returns true if and only if `float` zero.
  @[AlwaysInline]
  def self.lc_num_is_zero(num :  LcVal)
    return lcfalse unless num.is_a? NumType
    return val2bool(num2num(num) == 0)
  end

  # :call-seq:
  #   coerce(numeric) -> Array
  # It returns an array with `numeric` and `float`
  # converted to a Float object
  # ```
  # 3.6.coerce(8) #=> [8.0, 3.6]
  # 3.6.coerce(8.1) #=> [8.1, 3.6]
  # ```
  def self.lc_num_coerce(n1 :  LcVal, n2 :  LcVal)
    tmp = num2int(0)
    v1  = lc_num_to_cr_f(n1)
    v2  = lc_num_to_cr_f(n2)
    return tuple2array(num2float(v2), num2float(v1))
  end

  def self.init_number
    @@lc_number = lc_build_internal_class("Number")
    define_allocator(@@lc_number,lc_number_allocate)

    lc_undef_method(@@lc_number,"defrost")

    define_method(@@lc_number,">",lc_num_gr,            1)
    define_method(@@lc_number,"<",lc_num_sm,            1)
    define_method(@@lc_number,">=",lc_num_ge,           1)
    define_method(@@lc_number,"<=",lc_num_se,           1)
    define_method(@@lc_number,"zero?",lc_num_is_zero,   0)
    define_method(@@lc_number,"coerce",lc_num_coerce,   1)
    define_method(@@lc_number,"hash",lc_num_hash,       0)
  end

  
end