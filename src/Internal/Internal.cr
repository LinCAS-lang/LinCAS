
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

    alias Value  = BaseS | BaseC | Structure
    alias ValueR = BaseS | BaseC

    abstract struct BaseS
        @klass  = uninitialized ClassEntry
        @data   = uninitialized Data
        @frozen = false
        setter klass
        setter frozen
        setter data
        getter klass 
        getter frozen
        getter data
    end

    abstract class BaseC
        @klass  = uninitialized ClassEntry
        @data   = uninitialized Data
        @frozen = false
        setter klass
        setter frozen
        setter data
        getter klass 
        getter frozen
        getter data
    end

    lib LibC
        fun strstr(str1 : Char*, str2 : Char*) : Char*
    end
    
    macro internal 
        self 
    end

    macro lcfalse
        Internal::LcFalse
    end

    macro lctrue
        Internal::LcTrue
    end

    macro libc 
        Internal::LibC
    end

    macro convert(name)
        Eval.convert({{name}})
    end

    def self.coerce(v1 : Value, v2 : Value)
        if internal.lc_obj_responds_to? v1,"coerce"
            return Exec.lc_call_fun(v2,"coerce",v1)
        else 
            lc_raise(LcTypeError,convert(:no_coerce) % {lc_typeof(v2),lc_typeof(v1)})
            return Null
        end 
    end 

    def self.lc_typeof(v : Value)
        if v.is_a? Structure 
            if v.is_a? ModuleEntry
                return "#{v.as(ModuleEntry).name} : Module"
            else 
                return "#{v.as(ClassEntry).name} : Class"
            end 
        else 
            return v.as(ValueR).klass.name
        end 
        # Should never get here
        ""
    end

    def self.clone_val(obj)
        if obj.is_a? LcString
            return internal.lc_str_clone(obj)
        else
            return obj
        end
    end

end