
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

    struct LcNull < BaseS
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
        return build_string("")
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

    global Null = Internal.lc_build_null
    
end
