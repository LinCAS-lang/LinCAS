
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

    class LcObject < BaseC
        def to_s 
            return Internal.lc_obj_to_s(self)
        end
    end

    struct VirtualObj < BaseS
    end

    def self.boot_main_object
        return internal.lc_obj_new(MainClass)
    end

    def self.lc_obj_new(klass : Value)
        klass = klass.as(ClassEntry)
        obj = LcObject.new
        obj.klass = klass
        obj.data  = klass.data.clone
        obj.id    = pointerof(obj).address
        return obj.as(Value) 
    end

    obj_new = LcProc.new do |args|
        next internal.lc_obj_new(*args.as(T1))
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
            io << obj.as(Structure).path.to_s
            io << ((obj.is_a? ClassEntry) ? " : class" : " : module")
        else
            io << obj.as(ValueR).klass.path.to_s
        end
        io << ":@0x"
        pointerof(obj).address.to_s(16,io)
        io << '>'
    end

    def self.lc_obj_compare(obj1 : Value, obj2 : Value)
        return lcfalse unless obj1.class == obj2.class 
        return lctrue if obj1.id == obj2.id
        case obj1.class 
            when LcString
                return lc_str_compare(obj1,obj2)
            when LcNum
                return lc_num_eq(obj1,obj2)
            when LcBool
                return lc_bool_eq(obj1,obj2)
            when LcRange 
                return lc_range_eq(obj1,obj2)
            when LcNull 
                return lctrue 
            when Structure
                return lc_class_eq(obj1,obj2)
            when LcArray
                return lc_ary_eq(obj1,obj2)
            else 
                if lc_obj_responds_to? obj1,"=="
                    return Exec.lc_call_fun(obj1,"==",obj2)
                elsif lc_obj_responds_to? obj1,"!="
                    return lc_bool_invert(Exec.lc_call_fun(obj1,"==",obj2))
                end
                return lcfalse 
        end 
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


<<<<<<< HEAD
    Obj       = internal.lc_build_class_only("Object")
    MainClass = Id_Tab.getRoot.as(ClassEntry)
    internal.lc_set_parent_class(Obj,LcClass)
    internal.lc_set_parent_class(MainClass,Obj)
=======
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
>>>>>>> lc-vm

    internal.lc_add_static(Obj,"new",obj_new,         0)
    internal.lc_add_internal(Obj,"init",obj_init,     0)
    internal.lc_add_internal(Obj,"==",obj_eq,         1)
    internal.lc_add_internal(Obj,"!=",obj_eq,         1)
    internal.lc_add_internal(Obj,"freeze",obj_freeze, 0)
<<<<<<< HEAD
    internal.lc_add_internal(Obj,"frozen",obj_frozen, 0)
=======
    internal.lc_add_internal(Obj,"frozen?",obj_frozen,0)
>>>>>>> lc-vm
    internal.lc_add_internal(Obj,"is_null",obj_null,  0)
    internal.lc_add_internal(Obj,"to_s",obj_to_s,     0)
    internal.lc_add_internal(Obj,"to_m",obj_to_m,     0)
    internal.lc_add_internal(Obj,"inspect",obj_to_s,  0)
    internal.lc_add_internal(Obj,"inspect",obj_to_s,  0)
    internal.lc_add_internal(Obj,"||",obj_or,         1)
    internal.lc_add_internal(Obj,"&&",obj_and,        1)
    internal.lc_add_internal(Obj,"!",obj_not,         0)
<<<<<<< HEAD

    internal.lc_add_static(LcClass,"freeze",obj_freeze,   0)
    internal.lc_add_static(LcClass,"defrost",obj_defrost, 0)
    internal.lc_add_static(LcClass,"frozen?",obj_frozen,  0)
    internal.lc_add_static(LcClass,"is_null",obj_null,    0)
=======
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
>>>>>>> lc-vm


end