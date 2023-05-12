
# Copyright (c) 2017-2022 Massimiliano Dal Mas
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

    macro wrap(name,argc)
      LcProc.new do |args|
        next {{name.id}}(*args.as(T{{argc.id}}))
      end
    end

    global(
      enum ObjectFlags
        NONE      = 0
        FROZEN    = 1 << 0
        FAKE      = 1 << 1
        SHARED    = 1 << 2
        REG_CLASS = 1 << 3
      end
    )

    # abstract struct BaseS
    #   @klass  = uninitialized LcClass
    #   @data   = uninitialized Data
    #   @id     = 0_u64
    #   @flags  : ObjectFlags = ObjectFlags::NONE
    #   property klass, data, id, flags
    # end

    # abstract class LcVal
    #   @klass  = uninitialized LcClass
    #   @data   = uninitialized Data
    #   @id     = 0_u64
    #   @flags  = uninitialized ObjectFlags
    #   property klass, data, id, flags
    # end

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

    ##
    # It forces the casting of an object.
    # Mainly used to cast LcArray to its wrapper Ary.
    # This is very unsafe. Use carefully
    macro lc_recast(obj, type)
      Pointer(Void).new({{obj}}.object_id).as({{type}})
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

    def self.lincas_obj_alloc_fake(type : LcVal.class,klass : LcClass,*args,**opt)
      tmp = lincas_obj_alloc(type,klass,*args,**opt)
      set_flag tmp, FAKE
      return tmp
    end

    def self.lincas_alloc(type, size)
      type.new(size)
    end

    def self.lincas_realloc(ptr, size)
      ptr.realloc size
    end

    def self.lincas_obj_alloc(type : LcVal.class,klass : LcClass, *args, **opt)
      tmp       = type.new(*args)
      tmp.klass = klass
      if id = opt[:id]?
        tmp.id = id.as(UInt64) 
      end
      tmp.data = opt[:data]? || IvarTable.new
      return tmp
    end

    def self.test(object :  LcVal)
      if object == Null || object == LcFalse
        return false 
      end 
      return true 
    end

    @[AlwaysInline]
    def self.struct_type(klass : LcClass,type : SType)
      klass.type == type
    end

    def self.lc_typeof(v :  LcVal)
      if v.is_a? LcClass 
        if type_of(v).includes? SType.flags(MODULE, PyMODULE)
          return "#{class_path(lc_cast(v, LcClass))}:Module"
        else 
          return "#{class_path(lc_cast(v, LcClass))}:Class"
        end 
      else 
        return class_path(class_of(v))
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

    @[AlwaysInline]
    def self.lc_make_shared_sym_tab(lc_table : LookUpTable)
      # if symTab.is_a? HybridSymT
      #   return HybridSymT.new(symTab.sym_tab,symTab.pyObj)
      # end
      # return SymTab.new(symTab.sym_tab)
      lc_table.clone
    end

    def self.lincas_init_lazy_const(const : LcVal,klass : LcClass)
      const.klass = klass 
      const.data  = IvarTable.new
    end


end