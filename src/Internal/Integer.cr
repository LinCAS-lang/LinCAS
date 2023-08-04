
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

  LC_INT_FLAG = 0x01
  LC_INT_MAX = Int64::MAX << 1
  LC_INT_MIN = Int64::MIN << 1

  macro is_int_p(p)
    !({{p}} & LC_INT_FLAG).zero?
  end

  class LcInt < LcNum
    # from LcBase
    # @klass  : fixed with below getter
    # @id     : never used
    # @data   : never used (frozen object)
    # @flags  : Raises bug if accessed
    # @gc_ref : ?
    def initialize(@val : Int64 | BigInt)
    end

    def initialize(val : Int32)
      initialize(val.to_i64)
    end
    
    def val
      if Internal.is_int_p object_id
        return (object_id >> 1).to_i64
      end
      return @val
    end
    
    def klass : LcClass
      if Internal.is_int_p object_id
        Internal.lc_integer
      else
        @klass.not_nil!
      end
    end

    @[AlwaysInline]
    def flags
      lc_bug("Object flags used on optimized int")
    end

    @[AlwaysInline]
    def flags=(any)
      flags
    end
  end

  macro num2bigint(num)
    BigInt.new({{num}})
  end

  @[AlwaysInline]
  def self.big_int_power(v1, v2)
    #lc_warn()
    if v2 < 0
        return 0.0f64
    end 
    return Float64::INFINITY
  end

  # Converts a crystal integer to a lincas integer
  @[AlwaysInline]
  def self.num2int(num : Intnum)
    return new_int(num)
  end

  # Converts a lincas integer to a crystal integer
  # (could either be amn int64 or a bigint)
  @[AlwaysInline]
  def self.int2num(int :  LcVal)
    return lc_cast(int, LcInt).val
  end 

  # It safely converts a lincas number or float to a crystal
  # integer. It allows to specify the return type of
  # the converted integer. The default conversion is into
  # Int64. 
  def self.lc_num_to_cr_i(value, r_type = Int64)
    if !value.is_a? NumType
      lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof(value)} into Integer")
    end
    v = num2num(value)
    return i_to_t(v, r_type)
  end

  # It safely converts a lincas number or float to a crystal
  # integer. If `value` is a Float, it is converted into an 
  # Int64. Otherwise, the type is left unchanged.
  def self.lc_num_to_cr_i2(value)
    if !value.is_a? NumType
      lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof(value)} into Integer")
    end
    v = num2num(value)
    if v.is_a? Float
      return i_to_t v, Int64
    else
      return v
    end
  end

  def self.i_to_t(int, t : T.class) : T forall T
    if int.is_a? BigInt && t != BigInt && !(T::MIN <= int <= T::MAX)
      lc_raise(lc_type_err,"Can't convert #{int.class} into #{t} (value too big)")
    end
    return t.new(int)
  end

  @[AlwaysInline]
  def self.opt_int(value)
    return Pointer(Void).new((value.to_u64 << 1) | LC_INT_FLAG).as LcInt
  end

  # It creates a new lincas integer from a crystal integer
  # or bigint. There is a little optimization: if the int
  # fits between LC_INT_MIN and LC_INT_MAX, we can create
  # a pointer that has as address (int << 1 | LC_INT_FLAG).
  # In this way we avoid memory allocation for common ints.
  # This is unsafe as the pointer's address is actually invalid
  def self.new_int(value : Intnum)
    if LC_INT_MIN <= value <= LC_INT_MAX
      return opt_int(value)
    end
    int = lincas_obj_alloc LcInt, @@lc_integer, value
  end

  def self.build_fake_int(value : IntnumR)
    return new_int value
  end

  # It attempts to perform the operation passed in the block
  # that may potentially cause  overflow. It the overflow happens,
  # then the first number is converted to bigint and the operation
  # is attempted one more time. In case of failures, it causes a bug  
  def self.rescue_overflow_error(a, b)
    retry = true
    while true
      begin
        return yield a, b
      rescue OverflowError
        break unless retry
        a = BigInt.new(a)
        retry = false
      end
    end
    lc_bug("Lincas cannot resolve overflow error (#{a}, #{b})")
  end

  {% for name, op in {sum: '+', sub: '-', mult: '*'}%}

    def self.lc_int_{{name.id}}(n1 : LcVal, n2 : LcVal)
      if n2.is_a? LcInt 
        {% if flag?(:fast_math) %}
          return num2int(int2num(n1) &{{op.id}} int2num(n2))
        {% else %}
          v = rescue_overflow_error(int2num(n1), int2num(n2)) { |v1, v2| v1 {{op.id}} v2 }
          return num2int(v)
        {% end %}
      else
        return lc_num_coerce_bin(n1, n2, {{op.stringify}})
      end
      # Should never get here
      return Null
    end

  {% end %}

  # :call-seq: 
  #   int \ other_int -> Integer
  # It performs an integer division. It returns an
  # integer. If ´other_int´ is zero, it raises an exception
  # ```
  # 4 \ 2 #=> 2
  # 5 \ 2 #=> 2
  # 3 \ 5 #=> 0
  # 5 \ 0 #=> ZeroDivisionError
  # ```
  def self.lc_int_idiv(n1 :  LcVal, n2 :  LcVal)
    if n2.is_a? LcInt 
      if int2num(n2).zero?
        lc_raise(lc_zerodiv_err, "(Division by 0)")
      end
      return num2int(int2num(n1) // int2num(n2))
    else
      return lc_num_coerce_bin(n1,n2,"\\")
    end
    # Should never get here
    return Null
  end

  # :call-seq: 
  #   int / other_int -> Float
  # It performs an integer division. It returns a
  # float. If ´other_int´ is zero, it returns ±INFINITY
  # ```
  # 4 / 2 #=> 2.0
  # 5 / 2 #=> 2.5
  # 3 / 5 #=> 0.6
  # 3 / 0 #=> Infinity
  # -3 / 0 #=> -Infinity
  # ```
  def self.lc_int_fdiv(n1 : LcVal, n2 : LcVal)
    if n2.is_a? LcInt 
      if int2num(n1) == 0
        return positive_num(n1) ? @@lc_infinity : @@lc_ninfinity
      end
      return num2float((int2num(n1) / int2num(n2)).to_f64)
    else
      return lc_num_coerce_bin(n1, n2, "/")
    end
    # Should never get here
    return Null
  end

  # :call-seq: 
  #   int % other_int -> Integer
  # It performs modulo of ´int´. It returns an
  # int. If ´other_int´ is zero, it raises an exception
  # ```
  # 4 % 2 #=> 0
  # 3 % 5 #=> 3
  # -3 % 5 #=> 2
  # 3 % 0 #=> ZeroDivisionError
  # ```
  def self.lc_int_modulo(n1 : LcVal, n2 : LcVal)
    if n2.is_a? LcInt
      if (v2 = int2num(n2)) == 0
        lc_raise(lc_zerodiv_err, "(Division by 0)")
      else
        # This if statement is strange, but its purpose is just to
        # help the compiler dispatch the correct method for '%' operation
        return !v2.is_a?(BigInt) ? num2int(int2num(n1) % v2) : num2int(int2num(n1) % v2)
      end
    else
      return lc_num_coerce_bin(n1, n2, "%")
    end
  end

  # :call-seq: 
  #   int ** other_int -> Integer
  #   int ** -other_int -> Float
  # It performs the power between two integers.
  # ```
  # 4 ** 2 #=> 8
  # 3 ** 5 #=> 243
  # -3 ** 5 #=> -243
  # 6 ** -1 #=> 0.16666666666666666
  # ```
  def self.lc_int_power(n1 :  LcVal, n2 :  LcVal)
    if n2.is_a? LcInt 
      int = int2num(n1)
      exp = int2num(n2)
      if int.class == exp.class == Int64
        int = int.to_f64 if exp < 0
        {% if flag?(:fast_math) %}
          return num2int(int &** exp)
        {% else %}
          val = rescue_overflow_error(int, exp) { |v1, v2| v1 ** v2 }
          if val.is_a? Floatnum
            return num2float(val)
          end
          return num2int(val)
        {% end %}
      else
        num2float(big_int_power(int, exp))
      end
    else
      return lc_num_coerce_bin(n1,n2,"**")
    end
    # Should never get here
    return Null
  end

  # :call-seq: 
  #   int.odd? -> true / false
  # It returns true if ´int´ is odd
  def self.lc_int_odd(n :  LcVal)
    if int2num(n).odd? 
      return lctrue
    else 
      return lcfalse
    end 
  end

  # :call-seq: 
  #   int.even? -> true / false
  # It returns true if ´int´ is even
  @[AlwaysInline]
  def self.lc_int_even(n :  LcVal)
    return lc_bool_invert(lc_int_odd(n))
  end

  # :call-seq: 
  #   int.to_s -> String
  # It returns the string representation of ´int´
  @[AlwaysInline]
  def self.lc_int_to_s(n :  LcVal)
    return build_string(int2num(n).to_s)
  end

  # :call-seq: 
  #   int.to_f -> Float
  # It converts ´int´ into a float
  def self.lc_int_to_f(n :  LcVal)
    val = int2num(n)
    if val.is_a? BigInt
      return num2float(bigf2flo64(val.to_big_f))
    end
    return num2float(val.to_f64)
  end

  # :call-seq: 
  #   -int -> Integer
  # It applies unary minus to 'int'
  def self.lc_int_minus(n :  LcVal)
    return new_int( -int2num(n))
  end

  def self.lc_int_times(n :  LcVal)
    val = int2num(n)
    val.times do |i|
      Exec.lc_yield(num2int(i))
    end
    return Null
  end

  # :call-seq: 
  #   int.abs -> Integer
  # It returns the absolute value on ´int´
  @[AlwaysInline]
  def self.lc_int_abs(n : LcVal)
      val = int2num(n)
      return Null unless val 
      return num2int(val.abs)
  end

  def self.lc_int_eq(n :  LcVal, obj :  LcVal)
    if obj.is_a? LcInt
      return val2bool(int2num(n) == int2num(obj))
    else 
      return lc_compare(n, obj)
    end
  end

  @[AlwaysInline]
  def self.int_2_py(n : LcVal)
    int = lc_num_to_cr_i n
    Python.int_to_py int
  end
  
  # :call-seq: 
  #   int.to_py -> PyObject
  # It returns int converted to Python
  @[AlwaysInline]
  def self.lc_int_to_py(n : LcVal)
    return new_pyobj int_2_py n
  end
    
  def self.init_integer
    @@lc_integer = lc_build_internal_class("Integer",@@lc_number)
    lc_undef_allocator(@@lc_integer)

    define_method(@@lc_integer, "+",     lc_int_sum,        1)
    define_method(@@lc_integer, "-",     lc_int_sub,        1)
    define_method(@@lc_integer, "*",     lc_int_mult,       1)
    define_method(@@lc_integer, "\\",    lc_int_idiv,       1)
    define_method(@@lc_integer, "/",     lc_int_fdiv,       1)
    define_method(@@lc_integer, "%",     lc_int_modulo,     1)
    define_method(@@lc_integer, "**",    lc_int_power,      1)
    define_method(@@lc_integer, "==",    lc_int_eq,         1)
    define_method(@@lc_integer, "<=>",   lc_int_or_flo_cmp, 1)
    define_method(@@lc_number,  "odd?",  lc_int_odd,        0)
    define_method(@@lc_number,  "even?", lc_int_even,       0)
    define_method(@@lc_integer, "-@",    lc_int_minus,      0)
    define_method(@@lc_integer, "to_s",  lc_int_to_s,       0)
    alias_method_str(@@lc_integer, "to_s", "inspect")
    define_method(@@lc_integer, "to_f",  lc_int_to_f,       0)
    define_method(@@lc_integer, "to_i",  lc_obj_self,       0)
    define_method(@@lc_integer, "times", lc_int_times,      0)
    define_method(@@lc_integer, "abs",   lc_int_abs,        0)
    define_method(@@lc_integer, "to_py", lc_int_to_py,      0)
  end
    
end
