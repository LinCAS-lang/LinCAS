
# Copyright (c) 2017-2019 Massimiliano Dal Mas
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
    end

    class_getter lc_object

    @[AlwaysInline]
    def self.compare_by_type?(obj1 :  LcVal, obj2 :  LcVal)
        return obj1.is_a? NumType && obj2.is_a? NumType
    end

    def self.lc_compare(obj1 :  LcVal, obj2 :  LcVal)
        if compare_by_type?(obj1,obj2)
            return val2bool(num2num(obj1) == num2num(obj2))
        end
        if (lc_obj_has_internal_m? obj2,"==") == 1
            return Exec.lc_call_fun(obj2,"==",obj1)
        end
        return lcfalse
    end

    def self.lc_obj_match(obj1 :  LcVal,obj2 :  LcVal)
        cmp_result = Exec.lc_call_fun(obj1,"==",obj2)
        if cmp_result == lctrue
            return cmp_result
        else
            return lc_obj_eq(obj1,obj2)
        end 
    end

    @[AlwaysInline]
    def self.boot_main_object
        return internal.lc_obj_allocate(@@lc_object)
    end

    def self.obj2py(obj :  LcVal, ref = false)
        if obj.is_a? LcInt 
            value = int2num(obj)
            {%if !flag?(:fast_m)%}
                if value.is_a? BigInt 
                    lc_raise(LcNotImplError,"No conversion of big ints to python yet")
                    return nil 
                end
            {% end %}
            return int2py(value)
        elsif obj.is_a? LcFloat 
            return float2py(float2num(obj))
        elsif obj.is_a? LcString
            return str2py(obj)
        elsif obj.is_a? LcClass
            if is_pyembedded(obj)
                return obj.symTab.as(HybridSymT).pyObj 
            else
                lc_raise(LcNotImplError,"No conversion of #{lc_typeof(obj)} to python yet")
                return nil
            end
        elsif obj.is_a? LcArray
            ary2py(obj)
        elsif obj.is_a? LcPyObject
            tmp =  pyobj_get_obj(obj)
            pyobj_incref(tmp) if ref 
            return tmp
        elsif obj == Null 
            return_pynone
        elsif obj.is_a? Method 
            return method_to_py(obj)
        elsif obj.is_a? LcRange
            return range2py(obj)
        else
            lc_raise(LcNotImplError,"No conversion of #{lc_typeof(obj)} to python yet")
            return nil 
        end
    end

    def self.lc_new_object(klass :  LcVal)
        klass = klass.as(LcClass)
        if klass.type == SType::PyCLASS
            return build_pyobj(klass)
        end
        allocator = lc_find_allocator(klass)
        if allocator == Allocator::UNDEF
            lc_raise(LcInstanceErr,"Can't instantiate %s" % klass.name)
            return Null 
        end
        if allocator.is_a? LcProc
            return allocator.call(klass).as( LcVal)
        end
        lc_raise(LcInstanceErr,"Undefined allocator for %s" % klass.path.to_s)
        return Null
    end

    def self.lc_obj_allocate(klass :  LcVal)
        klass  = klass.as(LcClass)
        obj    = lincas_obj_alloc(LcObject,klass, data: klass.data.clone)
        obj.id = pointerof(obj).address
        return obj.as( LcVal) 
    end

    @[AlwaysInline]
    def self.lc_obj_init(obj :  LcVal)
        return obj 
    end

    @[AlwaysInline]
    def self.lc_obj_self(obj : LcVal)
        return obj 
    end

    def self.lincas_obj_to_s(obj :  LcVal)
        string = String.build do |io|
            lc_obj_to_s(obj,io)
        end
        return string
    end

    def self.lc_obj_to_s(obj :  LcVal)
        return build_string(lincas_obj_to_s(obj))
    end

    def self.lc_obj_to_s(obj :  LcVal, io)
        io << '<'
        if obj.is_a? LcClass 
            klass = obj.as(LcClass)
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

    def self.lc_obj_compare(obj1 :  LcVal, obj2 :  LcVal)
        return lctrue if obj1.id == obj2.id
        return lc_compare(obj1,obj2)
    end

    def self.lc_obj_eq(obj1 :  LcVal, obj2 :  LcVal)
        return lcfalse unless obj1.class == obj2.class
        if obj1.is_a? LcClass
            return lc_class_eq(obj1,obj2)
        else
            return lctrue if obj1.id == obj2.id
        end 
        return lcfalse
    end

    def self.lc_obj_freeze(obj :  LcVal)
        set_flag obj, FROZEN 
        return obj 
    end

    @[AlwaysInline]
    def self.lc_obj_frozen(obj : LcVal)
        if obj.flags & ObjectFlags::FROZEN != 0
            return lctrue 
        end 
        return lcfalse
    end

    @[AlwaysInline]
    def self.lc_obj_null(obj : LcVal)
        return lctrue if obj == Null
        return lcfalse
    end

    def self.lc_obj_to_m(obj : LcVal)
        mx = internal.build_matrix(1,1)
        set_matrix_index(mx,0,0,obj)
        return mx
    end

    @[AlwaysInline]
    def self.lc_obj_defrost(obj :  LcVal)
        obj.flags &= ~ObjectFlags::FROZEN 
        return obj
    end

    def self.lc_obj_responds_to(obj :  LcVal,name :  LcVal)
        sname = id2string(name)
        return Null unless sname
        return val2bool(lc_obj_responds_to?(obj,sname))
    end
    
    @[AlwaysInline]
    def self.lc_obj_to_a(obj :  LcVal)
        return tuple2array(obj)
    end

    @[AlwaysInline]
    def self.lc_obj_hash(obj :  LcVal)
       return num2int(obj.id.hash.to_i64!)
    end

    @[AlwaysInline]
    def self.lc_obj_send(obj :  LcVal, argv : LcVal)
        argv = lc_cast(argv,Ary)
        method = lc_get_method(obj,argv[0])
        if test(method)
            return Exec.call_method(method.as(Method),argv.shifted_copy)
        else
            return method 
        end
    end

    def self.init_object
        @@lc_object = internal.lc_build_internal_class("Object",@@lc_class)
        define_allocator(@@lc_object,lc_obj_allocate)

        add_method(@@lc_object,"init",lc_obj_init,     0)
        add_method(@@lc_object,"==",lc_obj_eq,         1)

        obj_ne = LcProc.new do |args|
            res = fast_compare(*args.as(T2))
            next val2bool(!res)
        end

        lc_add_internal(@@lc_object,"!=",obj_ne,           1)
        add_method(@@lc_object,"freeze",lc_obj_freeze,  0)
        add_method(@@lc_object,"frozen?",lc_obj_frozen, 0)
        add_method(@@lc_object,"is_null",lc_obj_null,   0)
        add_method(@@lc_object,"inspect",lc_obj_to_s,   0)
        alias_method_str(@@lc_object,"inspect","to_s"       )
        add_method(@@lc_object,"to_m",lc_obj_to_m,      0)

        obj_and = LcProc.new do |args|
            next args.as(T2)[1]
        end
    
        obj_or = LcProc.new do |args|
            next args.as(T2)[0]
        end
    
        obj_not = LcProc.new do |args|
            next lcfalse
        end

        lc_add_internal(@@lc_object,"||",obj_or,           1)
        lc_add_internal(@@lc_object,"&&",obj_and,          1)
        lc_add_internal(@@lc_object,"!",obj_not,           0)
        add_method(@@lc_object,"to_a",lc_obj_to_a,    0)

        add_static_method(@@lc_class,"freeze",lc_obj_freeze,   0)
        add_static_method(@@lc_class,"defrost",lc_obj_defrost, 0)
        add_static_method(@@lc_class,"frozen?",lc_obj_frozen,  0)
        add_static_method(@@lc_class,"null?",lc_obj_null,      0)
        add_static_method(@@lc_class,"to_a",lc_obj_to_a,       0)
        lc_add_static(@@lc_class,"||",obj_or,              1)
        lc_add_static(@@lc_class,"&&",obj_and,             1)
        lc_add_static(@@lc_class,"!",obj_not,              0)

        lc_class_add_method(@@lc_class,"respond_to?",wrap(lc_obj_responds_to,2), 1)
        lc_class_add_method(@@lc_class,"hash",wrap(lc_obj_hash,1),               0)
        lc_class_add_method(@@lc_class,"send",wrap(lc_obj_send,2),              -3)
    end

end