
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

    macro global(exp)
        module ::LinCAS
            {{exp}}
        end
    end

    global(
        enum ObjectFlags
            NONE   = 0
            FROZEN = 1 << 0
            FAKE   = 1 << 1
            SHARED = 1 << 2
        end

    )

    abstract struct BaseS
        @klass  = uninitialized LcClass
        @data   = uninitialized Data
        @id     = 0_u64
        @flags  : ObjectFlags = ObjectFlags::NONE
        property klass, data, id, flags
    end

    abstract class BaseC
        @klass  = uninitialized LcClass
        @data   = uninitialized Data
        @id     = 0_u64
        @flags  = uninitialized ObjectFlags
        property klass, data, id, flags
    end

    global alias Value  = Internal::BaseS | Internal::BaseC | Structure
    global alias ValueR = Internal::BaseS | Internal::BaseC
    
    macro internal 
        self 
    end

    macro lcfalse
        LcFalse
    end

    macro lctrue
        LcTrue
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

    macro current_filedir
        Exec.get_current_filedir 
    end

    macro current_file 
        Exec.get_current_filename 
    end

    macro current_call_line
        Exec.get_current_call_line
    end

    def self.test(object : Value)
        if object == Null || object == LcFalse
            return false 
        end 
        return true 
    end

    def self.lc_finalize
        PyGC.clear_all
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

    def self.lc_make_shared_sym_tab(symTab : SymTab_t)
        if symTab.is_a? HybridSymT
            return HybridSymT.new(symTab.sym_tab,symTab.pyObj)
        end
        return SymTab.new(symTab.sym_tab)
    end


end