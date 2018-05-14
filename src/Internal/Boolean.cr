
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

    struct LcBTrue  < BaseS
        def to_s 
            return "true"
        end
    end

    struct LcBFalse  < BaseS 
        def to_s 
            return "false"
        end
    end

    alias LcBool = LcBTrue | LcBFalse

    def self.build_true
        lcTrue       = LcBTrue.new
        klass         = Id_Tab.lookUp("Boolean")
        lcTrue.klass  = klass.as(ClassEntry)
        lcTrue.data   = klass.as(ClassEntry).data.clone
        lcTrue.frozen = true
        return lcTrue.as(Value)
    end

    def self.build_false
        lcFalse        = LcBFalse.new
        klass          = Id_Tab.lookUp("Boolean")
        lcFalse.klass  = klass.as(ClassEntry)
        lcFalse.data   = klass.as(ClassEntry).data.clone
        lcFalse.frozen = true
        return lcFalse.as(Value)
    end

    def self.lc_bool_invert(value)
        if value.is_a? LcBTrue
            return lcfalse
        elsif value.is_a? LcBFalse
            return lctrue
        else 
            #internal.raise()
            return Null
        end
    end

    bool_invert = LcProc.new do |args|
        args = args.as(T1)
        next internal.lc_bool_invert(args[0])
    end

    def self.lc_bool_eq(val1, val2)
        return lctrue if val1 == val2
        return lcfalse
    end

    bool_eq = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_bool_eq(args[0],args[1])
    end

    def self.lc_bool_gr(val1, val2)
        return lctrue if val1 == lctrue && val2 == lcfalse
        return lcfalse
    end 

    def self.lc_bool_sm(val1, val2)
        return lctrue if val1 == lcfalse && val2 == lctrue
        return lcfalse 
    end

    def self.lc_bool_ge(val1, val2)
        return internal.lc_bool_gr(val1,val2)
    end 

    def self.lc_bool_se(val1, val2)
        return internal.lc_bool_sm(val1,val2)
    end

    def self.lc_bool_ne(val1, val2)
        return internal.lc_bool_invert(
            internal.lc_bool_eq(val1,val2)
        )
    end

    bool_ne = LcProc.new do |args|
        next internal.lc_bool_ne(*args.as(T2))
    end

    def self.lc_bool_and(val1, val2)
        return lctrue if val1 == lctrue && val2 == lctrue
        return lcfalse
    end

    bool_and = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_bool_and(args[0],args[1])
    end

    def self.lc_bool_or(val1, val2)
        return lctrue if val1 == lctrue || val2 == lctrue
        return lcfalse 
    end

    bool_or = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_bool_or(args[0],args[1])
    end

<<<<<<< HEAD
    BoolClass = internal.lc_build_class_only("Boolean")
    internal.lc_set_parent_class(BoolClass, Obj)
=======
    BoolClass = internal.lc_build_internal_class("Boolean")
    internal.lc_undef_allocator(BoolClass)
>>>>>>> lc-vm

    internal.lc_remove_static(BoolClass,"new")
    internal.lc_remove_internal(BoolClass,"defrost")

    internal.lc_add_internal(BoolClass,"!", bool_invert,0)
    internal.lc_add_internal(BoolClass,"==",bool_eq,    1)
    internal.lc_add_internal(BoolClass,"!=",bool_ne,    1)
    internal.lc_add_internal(BoolClass,"&&",bool_and,   1)
    internal.lc_add_internal(BoolClass,"||",bool_or,    1)

    LcTrue  = internal.build_true
    LcFalse = internal.build_false

end