
# Copyright (c) 2017 Massimiliano Dal Mas
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

    enum ObjType
        STRING LCINT LCFLOAT OBJECT ARRAY MATRIX SYMBOLIC
        TRUE FALSE NULL RANGE 
    end

    macro string 
        ObjType::STRING
    end 

    macro int 
        ObjType::LCINT 
    end

    macro float 
        ObjType::LCFLOAT 
    end 

    macro object 
        ObjType::OBJECT
    end 

    macro array 
        ObjType::ARRAY 
    end 

    macro matrix 
        ObjType::MATRIX 
    end

    macro symbolic 
        ObjType::SYMBOLIC
    end

    macro true_type
        ObjType::TRUE 
    end 

    macro false_type
        ObjType::FALSE 
    end

    macro null_type
        ObjType::NULL
    end

    macro range
        ObjType::RANGE 
    end

    alias Value  = LcObject | LcObject*
    alias Hidden = LcString | Intnum | Floatnum

    abstract struct Base
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
    struct LcObject < Base
        @type   : ObjType = ObjType::OBJECT
        @hidden : Hidden? = nil
        setter hidden 
        getter hidden 
        setter type 
        getter type 
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

    macro obj_of(str_ptr)
        {{str_ptr}}.as(LcObject*).value
    end

    @[AlwaysInline]
    def self.lc_typeof(value)
        if value.is_a? LcObject
            return value.type
        elsif value.is_a? LcObject*
            return obj_of(value).type
        end
        return nil
    end

    def self.clone_val(obj)
        if obj.is_a? LcString*
            return internal.lc_str_clone(obj)
        else
            return obj
        end
    end

end