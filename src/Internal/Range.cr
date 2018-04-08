
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
# limitations under the License.WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module LinCAS::Internal

    class LcRange < BaseC
        @left  : Intnum = 0
        @right : Intnum = 0
        @inclusive = true
        property left,right,inclusive
        def to_s
            return "#{@left}#{@inclusive ? ".." : "..."}#{@right}"
        end
    end    

    macro left(range)
        {{range}}.as(LcRange).left
    end 

    macro right(range)
        {{range}}.as(LcRange).right
    end

    @[AlwaysInline]
    def self.range_size(range)
        lft = left(range)
        rht = right(range)
        inc = inclusive(range) ? 1 : 0
        if lft > rht
            return lft - rht + inc 
        else 
            return rht - lft + inc 
        end
    end

    macro inclusive(range)
        {{range}}.as(LcRange).inclusive 
    end

    def self.lc_range_allocate(klass : Value)
        klass = klass.as(LcClass)
        range       = LcRange.new 
        range.klass = klass 
        range.data  = klass.data.clone 
        return range.as(Value)
    end
    
    range_allocator = LcProc.new do |args|
        next lc_range_allocate(*args.as(T1))
    end

    def self.range_new
        range       = LcRange.new 
        range.klass = RangeClass 
        range.data  = RangeClass.data.clone 
        return range 
    end

    def self.build_range(v1 : Num, v2 : Num, inclusive = true)
        range       = range_new 
        range.left  = v1.to_i 
        range.right = v2.to_i
        range.inclusive = inclusive
        return range.as(Value)
    end

    def self.build_range(v1 : Value, v2 : Value, inclusive : Bool)
        n1 = lc_num_to_cr_i(v1)
        n2 = lc_num_to_cr_i(v2)
        return Null unless n1 && n2
        return build_range(n1,n2,inclusive)
    end

    def self.lc_range_include(range : Value, item : Value)
        return lcfalse unless item.is_a? LcNum 
        lft = left(range)
        rht = right(range)
        if lft > rht 
            lft,rht = rht,lft 
        end
        itemv = num2num(item)
        if lft <= itemv && itemv <= rht 
            return lctrue 
        end 
        return lcfalse
    end

    range_include = LcProc.new do |args|
        next internal.lc_range_include(*args.as(T2))
    end

    def self.lc_range_to_s(range : Value)
        lft = left(range)
        rht = right(range)
        string = String.build do |io|
            io << lft 
            io << (inclusive(range) ? ".." : "...")
        end
        return build_string(string)
    ensure 
        GC.free(Box.box(string))
        GC.collect 
    end

    range_to_s = LcProc.new do |args|
        next internal.lc_range_to_s(*args.as(T1))
    end

    def self.lc_range_size(range)
        return num2int(range_size(range))
    end

    range_size = LcProc.new do |args|
        next num2int(range_size(*args.as(T1)))
    end

    def self.lc_range_each(range)
        lft = left(range)
        rht = right(range)
        if lft > rht 
            rht += 1 unless inclusive(range)
            lft.downto rht do |i|
                Exec.lc_yield(num2int(i))
            end
        else 
            rht -= 1 unless inclusive(range)
            (lft..rht).each do |i|
                Exec.lc_yield(num2int(i))
            end
        end
        Null
    end

    range_each = LcProc.new do |args|
        next internal.lc_range_each(*args.as(T1))
    end

    def self.lc_range_map(range)
        ary = build_ary_new
        lft = left(range)
        rht = right(range)
        lft,rht = rht,lft unless lft < rht
        rht -= 1 unless inclusive(range)
        (lft..rht).each do |i|
            lc_ary_push(ary,Exec.lc_yield(num2int(i)))
        end
        return ary
    end

    range_map = LcProc.new do |args|
        next internal.lc_range_map(*args.as(T1))
    end

    def self.lc_range_eq(range1 : Value,range2 : Value)
        return lcfalse unless range2.is_a? LcRange
        return lctrue if left(range1) == left(range2) &&
                         right(range1) == right(range2) &&
                         inclusive(range1) == inclusive(range2)
        return lcfalse 
    end

    range_eq = LcProc.new do |args|
        next internal.lc_range_eq(*args.as(T2))
    end

    range_defrost = LcProc.new do |args|
        range = args.as(T1)[0]
        range.frozen = false
        next range
    end


    RangeClass = internal.lc_build_internal_class("Range")
    internal.lc_set_parent_class(RangeClass,Obj)
    internal.lc_set_allocator(RangeClass,range_allocator)
    
    internal.lc_add_internal(RangeClass,"include?",range_include,  1)
    internal.lc_add_internal(RangeClass,"to_s",range_to_s,         0)
    internal.lc_add_internal(RangeClass,"size",range_size,         0)
    internal.lc_add_internal(RangeClass,"length",range_size,       0)
    internal.lc_add_internal(RangeClass,"each",range_each,         0)
    internal.lc_add_internal(RangeClass,"map",range_map,           0)
    internal.lc_add_internal(RangeClass,"==",range_eq,             1)
    internal.lc_add_internal(RangeClass,"defrost",range_defrost,   0)


end
