
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

    class LcObject < BaseC
        def to_s 
            return Internal.lc_obj_to_s(self)
        end
    end

    @[AlwaysInline]
    def self.compare_by_type?(obj1 : Value, obj2 : Value)
        return obj1.is_a? NumType && obj2.is_a? NumType
    end

    def self.lc_compare(obj1 : Value, obj2 : Value)
        if compare_by_type?(obj1,obj2)
            return val2bool(num2num(obj1) == num2num(obj2))
        end
        if (lc_obj_has_internal_m? obj2,"==") == 1
            return Exec.lc_call_fun(obj2,"==",obj1)
        end
        return lcfalse
    end

    def self.lc_obj_match(obj1 : Value,obj2 : Value)
        cmp_result = Exec.lc_call_fun(obj1,"==",obj2)
        if cmp_result == lctrue
            return cmp_result
        else
            return lc_obj_eq(obj1,obj2)
        end 
    end

    @[AlwaysInline]
    def self.boot_main_object
        return internal.lc_obj_allocate(Obj)
    end

    def self.obj2py(obj : Value)
        if obj.is_a? LcInt 
            value = int2num(obj)
            {%if !flag?(:fast_m)%}
                if value.is_a? BigInt 
                    lc_raise(LcNotImplError,"No conversion of big ints to python yet")
                    return nil 
                end
            {% end %}
            return int2py(num2num(obj))
        elsif obj.is_a? LcFloat 
            return float2py(float2num(obj))
        elsif obj.is_a? LcString
            return str2py(obj)
        else
            lc_raise(LcNotImplError,"No conversion of #{lc_typeof(obj)} to python yet")
            return nil 
        end
    end

    def self.lc_new_object(klass : Value)
        klass = klass.as(LcClass)
        allocator = lc_find_allocator(klass)
        if allocator == Allocator::UNDEF
            lc_raise(LcInstanceErr,"Can't instantiate %s" % klass.path.to_s)
            return Null 
        end
        if allocator.is_a? LcProc
            return allocator.call(klass).as(Value)
        end
        lc_raise(LcInstanceErr,"Undefined allocator for %s" % klass.path.to_s)
        return Null
    end

    def self.lc_obj_allocate(klass : Value)
        klass     = klass.as(LcClass)
        obj       = LcObject.new
        obj.klass = klass
        obj.data  = klass.data.clone
        obj.id    = pointerof(obj).address
        return obj.as(Value) 
    end

    obj_allocator = LcProc.new do |args|
        next internal.lc_obj_allocate(*args.as(T1))
    end

    def self.lc_obj_init(obj : Value)
        return obj 
    end

    obj_init = LcProc.new do |args|
        next internal.lc_obj_init(*args.as(T1))
    end

    def self.lc_obj_to_s(obj : Value)
        string = String.build do |io|
            lc_obj_to_s(obj,io)
        end 
        return build_string(string)
    ensure
        GC.free(Box.box(string))
        GC.collect 
    end

    obj_to_s = LcProc.new do |args|
        next internal.lc_obj_to_s(*args.as(T1))
    end

    def self.lc_obj_to_s(obj : Value, io)
        io << '<'
        if obj.is_a? Structure 
            klass = obj.as(Structure)
            path  = klass.path
            if !path.empty?
                io << path.to_s
            else
                io << klass.name 
            end
            io << (struct_type(klass,SType::CLASS) ? " : class" : " : module")
        else
            klass = class_of(obj)
            path  = klass.path
            if !path.empty?
                io << path.to_s 
            else
                io << klass.name 
            end
        end
        io << ":@0x"
        obj.id.to_s(16,io)
        io << '>'
    end

    def self.lc_obj_compare(obj1 : Value, obj2 : Value)
        return lctrue if obj1.id == obj2.id
        return lc_compare(obj1,obj2)
    end

    def self.lc_obj_eq(obj1 : Value, obj2 : Value)
        return lcfalse unless obj1.class == obj2.class
        if obj1.is_a? Structure
            return lc_class_eq(obj1,obj2)
        else
            return lctrue if obj1.id == obj2.id
        end 
        return lcfalse
    end

    obj_eq = LcProc.new do |args|
        next internal.lc_obj_eq(*args.as(T2))
    end

    obj_ne = LcProc.new do |args|
        next lc_bool_invert(internal.lc_obj_eq(*args.as(T2)))
    end

    def self.lc_obj_freeze(obj : Value)
        obj.frozen = true 
        return obj 
    end

    obj_freeze = LcProc.new do |args|
        next internal.lc_obj_freeze(*args.as(T1))
    end

    obj_frozen = LcProc.new do |args|
        obj = args.as(T1)[0]
        if obj.frozen 
            next lctrue 
        end 
        next lcfalse
    end

    obj_null = LcProc.new do |args|
        obj = args.as(T1)[0]
        next lctrue if obj.is_a? LcNull
        next lcfalse
    end

    obj_to_m = LcProc.new do |args|
        mx = internal.build_matrix(1,1)
        set_matrix_index(mx,0,0,args.as(T1)[0])
        next mx
    end

    obj_and = LcProc.new do |args|
        next args.as(T2)[1]
    end

    obj_or = LcProc.new do |args|
        next args.as(T2)[0]
    end

    obj_not = LcProc.new do |args|
        next lcfalse
    end

    obj_defrost = LcProc.new do |args|
        obj = args.as(T1)[0]
        obj.frozen = false 
        next obj
    end

    def self.lc_obj_responds_to(obj : Value,name : Value)
        sname = id2string(name)
        return Null unless sname
        return val2bool(lc_obj_responds_to?(obj,sname))
    end

    obj_responds_to = LcProc.new do |args|
        next internal.lc_obj_responds_to(*args.as(T2))
    end
    
    @[AlwaysInline]
    def self.lc_obj_to_a(obj : Value)
        return tuple2array(obj)
    end

    obj_to_a = LcProc.new do |args|
        next internal.lc_obj_to_a(*args.as(T1))
    end


    Obj       = internal.lc_build_internal_class("Object",Lc_Class)
    internal.lc_set_allocator(Obj,obj_allocator)

    internal.lc_add_internal(Obj,"init",obj_init,     0)
    internal.lc_add_internal(Obj,"==",obj_eq,         1)
    internal.lc_add_internal(Obj,"!=",obj_eq,         1)
    internal.lc_add_internal(Obj,"freeze",obj_freeze, 0)
    internal.lc_add_internal(Obj,"frozen?",obj_frozen,0)
    internal.lc_add_internal(Obj,"is_null",obj_null,  0)
    internal.lc_add_internal(Obj,"inspect",obj_to_s,  0)
            alias_method_str(Obj,"inspect","to_s"      )
    internal.lc_add_internal(Obj,"to_m",obj_to_m,     0)
    internal.lc_add_internal(Obj,"||",obj_or,         1)
    internal.lc_add_internal(Obj,"&&",obj_and,        1)
    internal.lc_add_internal(Obj,"!",obj_not,         0)
    internal.lc_add_internal(Obj,"to_a",obj_to_a,     0)

    internal.lc_add_static(Lc_Class,"freeze",obj_freeze,   0)
    internal.lc_add_static(Lc_Class,"defrost",obj_defrost, 0)
    internal.lc_add_static(Lc_Class,"frozen?",obj_frozen,  0)
    internal.lc_add_static(Lc_Class,"null?",obj_null,      0)
    internal.lc_add_static(Lc_Class,"to_a",obj_to_a,       0)
    internal.lc_add_static(Lc_Class,"||",obj_or,           1)
    internal.lc_add_static(Lc_Class,"&&",obj_and,          1)
    internal.lc_add_static(Lc_Class,"!",obj_not,           0)

    internal.lc_class_add_method(Lc_Class,"respond_to?",obj_responds_to, 1)


end