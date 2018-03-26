
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

lib LibC
    fun strstr(str1 : Char*, str2 : Char*) : Char*
    fun printf(format : Char*, ... ) : Int 
    fun toupper(str : Char*) : Char*
    fun strlwr(str : Char*) : Char*
    fun strlen(str : Char*) : SizeT
    fun strtok(str : Char*, delimiter : Char*) : Char*
    fun strtol(str : Char*, endptr : Char*, base : Int) : Int
    fun strtod(str : Char*, endptr : Char**) : Double
    fun strcmp(str1 : Char*, str2 : Char*) : Int
end

module LinCAS::Internal

    alias Value  = BaseS | BaseC | Structure
    alias ValueR = BaseS | BaseC

    abstract struct BaseS
        @klass  = uninitialized LcClass
        @data   = uninitialized Data
        @frozen = false
        @id     = 0_u64
        property klass, frozen, data, id
    end

    abstract class BaseC
        @klass  = uninitialized LcClass
        @data   = uninitialized Data
        @frozen = false
        @id     = 0_u64
        property klass, frozen, data, id
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
        LibC
    end

    macro convert(name)
        VM.convert({{name}})
    end

    @[AlwaysInline]
    def self.struct_type(klass : Structure,type : SType)
        klass.type == type
    end

    def self.coerce(v1 : Value, v2 : Value)
        if internal.lc_obj_responds_to? v2,"coerce"
            return Exec.lc_call_fun(v2,"coerce",v1)
        else 
            lc_raise(LcTypeError,convert(:no_coerce) % {lc_typeof(v2),lc_typeof(v1)})
            return Null
        end 
    end 

    def self.lc_typeof(v : Value)
        if v.is_a? Structure 
            if struct_type(v,SType::MODULE)
                return "#{v.as(LcModule).name} : Module"
            else 
                return "#{v.as(LcClass).name} : Class"
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

    def self.lc_make_shared_sym_tab(symTab : SymTab)
        return SymTab.new(symTab.sym_tab)
    end


end