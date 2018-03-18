
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

    struct LcNull < BaseS
        def to_s
            return "null"
        end
    end

    def self.lc_build_null
        null  = LcNull.new
        null.klass = NullClass
        null.data  = NullClass.data.clone
        null.frozen= true
        return null.as(Value)
    end

    def self.lc_null_and(v1 : Value, v2 : Value)
        return v1
    end 

    null_and = LcProc.new do |args|
        next Null
    end

    def self.lc_null_or(v1 : Value, v2 : Value)
        return v2 
    end 

    null_or = LcProc.new do |args|
        next args.as(T2)[1]
    end

    def self.lc_null_not(v1 : Value)
        next lctrue 
    end

    null_not = LcProc.new do |args|
        next lctrue
    end

    @[AlwaysInline]
    def self.lc_null_to_s(arg = Null)
        return build_string("null")
    end

    null_to_s = LcProc.new do |args|
        next internal.lc_null_to_s
    end

    null_eq = LcProc.new do |args|
        value = args.as(T2)[1]
        if value.is_a? LcNull
            next lctrue 
        end
        next lcfalse
    end

    null_ne = LcProc.new do |args|
        value = args.as(T2)[1]
        if value.is_a? LcNull
            next lcfalse
        end
        next lctrue
    end

    null_clone = LcProc.new do |args|
        next args.as(T1)[0]
    end

    NullClass = internal.lc_build_internal_class("NullClass")
    internal.lc_set_parent_class(NullClass,Obj)
    internal.lc_undef_allocator(NullClass)

    internal.lc_remove_internal(NullClass,"defrost")

    internal.lc_add_internal(NullClass,"&&",null_and,      1)
    internal.lc_add_internal(NullClass,"||",null_or,       1)
    internal.lc_add_internal(NullClass,"!",null_not,       0)
    internal.lc_add_internal(NullClass,"==",null_eq,       1)
    internal.lc_add_internal(NullClass,"!=",null_ne,       1)
    internal.lc_add_internal(NullClass,"to_s",null_to_s,   0)
    internal.lc_add_internal(NullClass,"inspect",null_to_s,0)
    internal.lc_add_internal(NullClass,"clone",null_clone, 0)

    Null = lc_build_null
    
end
