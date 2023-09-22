
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
# limitations under the License.WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module LinCAS::Internal

    class LcRange < LcBase
      @left  : LcVal = Null
      @right : LcVal = Null
      @inclusive = true
      property left, right, inclusive
    end    

    macro r_left(range)
      {{range}}.as(LcRange).left
    end 

    macro r_right(range)
      {{range}}.as(LcRange).right
    end

    macro check_range(range)
      if !({{range}}.is_a? LcRange)
        lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof({{range}})} into Range")
      end
    end

    macro inclusive(range)
      {{range}}.as(LcRange).inclusive 
    end

    @[AlwaysInline]
    def self.range_size(range)
      size = lc_range_size range
      if size != Null && size != @@lc_infinity
        return lc_num_to_cr_i size
      else
        return 0
      end
    end

    def self.range_start_and_len(range, len, error)
      raise_ = false
      inc = inclusive(range) ? 1 : 0
      beg = lc_num_to_cr_i(r_left(range))
      end_ = lc_num_to_cr_i(r_right(range)) + inc
      if beg < 0
        beg += len
        raise_ = true if beg < 0
      end
      end_ += len if end_ < 0
      if error
        raise_ = true if beg > len
        end_ = len if end_ > len
      end
      size = end_ - beg
      size = 0i64 if size < 0
      if error && raise_
        lc_raise(@@lc_range_err, "#{beg}..#{inc ? "" : '.'}#{end_} out of range")
      end
      return {beg, size}
    end

    @[AlwaysInline]
    def self.range2py(range :  LcVal)
      lft = lc_num_to_cr_i r_left(range)
      rht = lc_num_to_cr_i r_right(range)
      if lft.is_a? BigInt || rht.is_a? BigInt 
        lc_raise(lc_not_impl_err,"No conversion of BigInt to python yet")
        return nil 
      end
      inc = inclusive(range) ? 0 : -1
      rht = rht + inc
      lft = int2py(lft)
      rht = int2py(rht)
      tmp = pyslice_new(lft,rht + inc)
      pyobj_decref_n(lft,rht)
      return tmp
    end

    def self.lc_range_allocate(klass :  LcVal)
      klass = klass.as(LcClass)
      range = lincas_obj_alloc LcRange, klass
      return range.as( LcVal)
    end

    def self.new_range
      range = lincas_obj_alloc LcRange, @@lc_range
      return range 
    end

    @[AlwaysInline] 
    def self.new_range(v1 : Num, v2 : Num, inclusive = true)
      return new_range num_auto(v1), num_auto(v2)
    end

    @[AlwaysInline]
    def self.assert_valid_range(v1 : LcVal, v2 : LcVal)
      if VM.lc_call_fun(v1, "<=>", v2) == Null
        lc_raise(lc_type_err, "Bad range type")
      end
    end

    def self.new_range(v1 :  LcVal, v2 :  LcVal, inclusive : Bool)
      assert_valid_range v1, v2
      range       = new_range
      range.left  = v1
      range.right = v2
      range.inclusive = inclusive
      return range.as(LcVal)
    end

    def self.lc_range_initialize(range : LcVal, argv : LcVal)
      argv = argv.as(Ary)
      range = lc_cast(range, LcRange)
      _beg = argv[0]
      _end = argv[1]
      assert_valid_range _beg, _end
      range.left  = _beg
      range.right = _end
      if argv.size == 3
        inclusive = test(argv[2])
      else
        inclusive = true
      end
      range.inclusive = inclusive
      return range
    end

    @[AlwaysInline]
    def self.lc_range_beg(range : LcVal)
      return r_left range
    end

    @[AlwaysInline]
    def self.lc_range_end(range : LcVal)
      return r_right range
    end

    @[AlwaysInline]
    def self.lc_range_inclusive(range : LcVal)
      return val2bool(inclusive(range))
    end

    def self.lc_cover(range : LcVal, _beg : LcVal, _end : LcVal, item : LcVal)
      if _beg == Null || compare(_beg, item) <= 0
        inclusive = inclusive(range) ? 0 : -1
        if _end == Null || compare(item, _end) <= inclusive
          return lctrue
        end
      end
      return lcfalse
    end

    def self.lc_compare_single(a : LcVal, b : LcVal)
      v = VM.lc_call_fun(a, "<=>", b)
      return lcfalse if v == Null
      if v != Null && yield lc_cmpint(v, a, b)
        return lctrue
      end
      return lcfalse
    end

    def self.lc_range_include(range :  LcVal, item :  LcVal)
      lft = r_left(range)
      rht = r_right(range)
      if lft.is_a?(NumType) && rht.is_a?(NumType)
        return lc_cover(range, lft, rht, item)
      elsif lft.is_a?(LcString) && rht.is_a?(LcString)
        return lc_cover(range, lft, rht, item)
      end
      comp = ->(v : Int32) { inclusive(range) ? v <= 0 : v < 0 }
      if lft != Null && rht != Null
        if bool2val(lc_compare_single(lft, item, &.<=(0)))
          return lc_compare_single(item, rht, &comp)
        end
      else
        if lft == Null
          return lc_compare_single(item, rht, &comp)
        else rht == Null
          return lc_compare_single(lft, item, &.<=(0))
        end  
      end
      return lcfalse
    end

    def self.lc_range_to_s(range :  LcVal)
      lft = r_left(range)
      rht = r_right(range)
      string = String.build do |io|
        str = lc_obj_any_to_s(lft)
        io.write_string(pointer_of(str).to_slice(str_size(str)))

        io << (inclusive(range) ? ".." : "...")
        
        str = lc_obj_any_to_s(rht)
        io.write_string(pointer_of(str).to_slice(str_size(str)))
      end
      return build_string(string)
    end

    def self.lc_range_size(range)
      lft = r_left(range)
      rht = r_right(range)
      if lft.is_a? LcNum
        if rht.is_a? LcNum
          return lincas_num_interval_step_size(lft, rht, num2int(1), inclusive(range))
        end
        if rht == Null
          return @@lc_infinity
        end
      elsif lft == Null
        return @@lc_infinity
      end
      return Null
    end

    @[AlwaysInline]   
    def self.discrete_obj(obj : LcVal)
      return lc_obj_responds_to? obj, "succ"
    end

    def self.lincas_infinite_num_each(num : NumType)
      i = num
      while true
        yield i
        # We need to take care of the overflow
        i = i.is_a?(LcFloat) ? lc_float_sum(i, num2int(1)) : lc_int_sum(i, num2int(1))
      end
    end

    def self.lincas_num_each(_beg : NumType, _end : NumType, inclusive : Bool)
      cmp = inclusive ? ->lc_num_se(LcVal, LcVal) : ->lc_num_sm(LcVal, LcVal)
      i = _beg
      while test(cmp.call(i, _end))
        yield i
        # We need to take care of the overflow
        i = i.is_a?(Float) ? lc_float_sum(i, num2int(1)) : lc_int_sum(i, num2int(1))
      end
    end

    def self.lincas_range_any_each(_beg : LcVal, _end : LcVal, inclusive : Bool)
      comp = inclusive ? 1 : 0
      i = _beg
      while (c = compare(i, _end)) < comp
        yield i
        break if inclusive && c.zero?
        i = VM.lc_call_fun(i, "succ")
      end
    end

    def self.lincas_range_each(range : LcVal, &block : LcVal ->)
      lft = r_left(range)
      rht = r_right(range)
      if lft.is_a? NumType && rht == Null
        lincas_infinite_num_each lft, &block
      elsif lft.is_a?(NumType) && rht.is_a? NumType
        lincas_num_each lft, rht, inclusive(range), &block
      else
        if !discrete_obj(lft)
          lc_raise(lc_type_err, "Can't iterate from #{lc_typeof(lft)}")
        end
        if rht != Null
          lincas_range_any_each lft, rht, inclusive(range), &block
        else
          beg = lft
          while beg
            yield beg
            beg = VM.lc_call_fun(beg, "succ")
          end
        end
      end
    end

    def self.lc_range_each(range : LcVal)
      lincas_range_each(range) do |value|
        VM.lc_yield value
      end
      return range
    end

    def self.lc_range_map(range)
      ary = new_array
      lincas_range_each range do |value|
        lc_ary_push ary, VM.lc_yield value
      end
      return ary
    end

    def self.lc_range_eq(range1 :  LcVal,range2 :  LcVal)
      return lcfalse unless range2.is_a? LcRange
      return lctrue if test(lc_obj_compare(r_left(range1), r_left(range2))) &&
                       test(lc_obj_compare(r_right(range1), r_right(range2))) &&
                       inclusive(range1) == inclusive(range2)
      return lcfalse 
    end

    
    def self.lc_range_hash(range :  LcVal)
      inc = inclusive(range)
      h   = inc.hash(HASHER)
      h   = r_left(range).object_id.hash(h) # This needs some fixing!
      h   = r_right(range).object_id.hash(h)
      return num2int(h.result.to_i64)
    end


    def self.init_range
      @@lc_range = internal.lc_build_internal_class("Range")
      define_allocator(@@lc_range,lc_range_allocate)
  
      define_protected_method(@@lc_range, "initialize", lc_range_initialize, -3)

      define_method(@@lc_range,"begin",lc_range_beg,         0)
      define_method(@@lc_range,"end",lc_range_end,           0)
      define_method(@@lc_range,"inclusive?",lc_range_inclusive,0)
      define_method(@@lc_range,"include?",lc_range_include,  1)
      define_method(@@lc_range,"to_s",lc_range_to_s,         0)
      define_method(@@lc_range,"size",lc_range_size,         0)
      alias_method_str(@@lc_range,"size", "length",           )
      define_method(@@lc_range,"each",lc_range_each,         0)
      define_method(@@lc_range,"map",lc_range_map,           0)
      define_method(@@lc_range,"==",lc_range_eq,             1)
      define_method(@@lc_range,"hash",lc_range_hash,         0)
    end


end
