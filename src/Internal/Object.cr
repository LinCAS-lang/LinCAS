
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
    end

    def self.boot_main_object
        return internal.lc_obj_new(MainClass)
    end

    def self.lc_obj_new(klass : Value)
        klass = klass.as(ClassEntry)
        obj = LcObject.new
        obj.klass = klass
        obj.data  = klass.data.clone
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
            lc_obj_inspect(obj,io)
        end 
        return build_string(string)
    ensure
        GC.free(Box.box(string))
        GC.collect 
    end

    def self.lc_obj_to_s(obj : Value, io)
        io << '<'
        if obj.is_a? Structure 
            io << obj.as(Structure).path.to_s
            io << ((obj.is_a? ClassEntry) ? " : class" : " : module")
        else
            io << obj.as(ValueR).klass.path.to_s
            io << " : object"
        end
        io << " @0x"
        pointerof(obj).address.to_s(16,io)
        io << '>'
    end

    Obj       = internal.lc_build_class_only("Object")
    MainClass = Id_Tab.getRoot.as(ClassEntry)
    internal.lc_set_parent_class(Obj,LcClass)
    internal.lc_set_parent_class(MainClass,Obj)

    internal.lc_add_static(Obj,"new",obj_new,    0)
    internal.lc_add_internal(Obj,"init",obj_init,0)

end