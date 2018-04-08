
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

    macro lc_cast(obj,type)
        {{obj}}.as({{type}})
    end

    def self.test(object : Value)
        if object == Null || object == LcFalse
            return false 
        end 
        return true 
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