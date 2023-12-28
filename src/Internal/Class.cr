
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

  macro type_of(obj)
    {{obj}}.as(LcClass).type
  end

  macro class_name(klass)
    {{klass}}.as(LcClass).name 
  end

  def self.metaclass_of(klass : LcClass)
    m_class = klass.klass 
    if !type_of(m_class).metaclass?
      return lc_attach_metaclass(klass).klass
    end 
    return m_class
  end

  def self.class_of(obj : LcVal)
    klass = obj.klass
    while klass && type_of(klass).metaclass?
      klass = klass.parent
    end
    return klass.not_nil!
  end 

  @[AlwaysInline]
  def self.lc_build_metaclass(klass : LcClass, parent : LcClass?)
    metaclass = LcClass.new(SType::METACLASS, "#<Class:#{class_path(klass)}>", parent)
    metaclass.klass = @@lc_class
    return metaclass
  end

  @[AlwaysInline]
  def self.lc_build_metaclass(klass : LcClass, py_obj : PyObject*, parent : LcClass?)
    metaclass = LcClass.new(SType.flags(METACLASS, PyEMBEDDED), "#<Class:#{class_path(klass)}>", py_obj, parent)
    metaclass.klass = @@lc_class
    return metaclass
  end

  ##
  # This method attaches a metaclass to a class `k`.
  # The class of the metaclass is `Class`, and its
  # superclass is the class of superclass of `k`
  def self.lc_attach_metaclass(klass : LcClass)
    # This is a temporary solution. There must be
    # a check that ensures consistency between metaclasses
    if parent = klass.parent # klass.parent is not nil
      parent = parent.klass
    else
      parent = @@lc_class
    end
    klass.klass = if !klass.type.py_embedded?
      lc_build_metaclass(klass, parent)
    else
      lc_build_metaclass(klass, klass.namespace.py_obj, parent)
    end
    return klass
  end

  @[AlwaysInline]
  def self.lc_build_class(name : String, namespace : NameTable, parent : LcClass)
    klass = LcClass.new(SType::CLASS, name, parent)
    klass.namespace.parent = namespace # upper lexical scope
    namespace[name] = klass
    return lc_attach_metaclass(klass)
  end

  ##
  # Used only to create the instance of `Class`
  # in its initialiser
  def self.lc_build_class_class
    klass     = LcClass.new(SType::CLASS, "Class", nil)
    metaclass = LcClass.new(SType::METACLASS, "#<Class:Class>", nil)
    metaclass.klass = klass
    klass.klass = metaclass
    return klass
  end

  @[AlwaysInline]
  def self.lc_build_user_class(name : String, namespace : NameTable, parent : LcClass = @@lc_object)
    klass = lc_build_class(name, namespace, parent)
    return klass
  end

  @[AlwaysInline]
  def self.lc_build_internal_class(name, parent : LcClass = @@lc_object)
    return lc_build_user_class(name, @@lc_object.namespace, parent)
  end

  # Wraps special class builder methods for doc generation
  # purposes.
  @[AlwaysInline]
  def self.lc_build_internal_class(name, parent = nil)
    yield
  end

  def self.lc_build_pyclass(name : String, obj : PyObject*, context : NameTable? = nil)
    if obj.null?
      lc_bug("Null python object received for class (#{name})")
    end
    if !(klass = IMPORTED_PYCLASSES[obj]?)
      klass = LcClass.new(SType.flags(CLASS, PyEMBEDDED), name, obj, @@lc_pyobject)
      lc_attach_metaclass(klass)
      IMPORTED_PYCLASSES[obj] = klass
    else
      Python.decref obj # assumes always new reference
    end
    if context && !klass.namespace.parent
      klass.namespace.parent = context
      context[name] = klass
    end
    return klass
  end

  @[AlwaysInline]
  def self.lc_set_parent_class(klass : LcClass,parent : LcClass)
    klass.parent = parent
  end

  def self.lc_define_const(klass : LcClass, name : String, const :  LcVal)
    klass.namespace[name] = const
  end

  @[AlwaysInline]
  def self.lc_set_allocator(klass : LcClass,allocator : Caller)
    klass.allocator = allocator 
  end

  @[AlwaysInline]
  def self.lc_undef_allocator(klass : LcClass)
    klass.allocator = Allocator::UNDEF 
  end

  macro define_allocator(klass, f_name)
    lc_set_allocator(
      {{klass}},
      Caller.new do |args|
        {{f_name}}(*args.as(T1))
      end
    )
  end

  ##
  # Not to be used directly
  def self.seek_const_in_scope(scp : NameTable,name : String) :  LcVal?
    while scp 
      const = scp.find(name, const: true)
      if const
        return const 
      end
      scp = scp.parent
    end 
    return nil
  end 

  def self.lc_seek_const(str : LcClass, name : String, exclude = false, recurse = true)
    return str if str.name == name
    parent = str
    while parent
      break if exclude && parent == @@lc_object && str != @@lc_object
      const = parent.namespace.find(name, const: true)
      if const
        return const
      end
      break unless recurse
      parent = parent.parent
    end
    return !exclude ? seek_const_in_scope(str.namespace,name) : nil
  end

  def self.lc_find_allocator(klass : LcClass)
    alloc = klass.allocator 
    return alloc if alloc
    klass = klass.parent
    while klass
      alloc = klass.allocator 
      return alloc if alloc
      klass = klass.parent
    end 
    return nil 
  end

  # @[AlwaysInline]
  # private def self.fetch_pystruct(name : String)
  #   name = "_#{name}"
  #   tmp = @@lc_object.namespace.find(name)
  #   if !tmp || !(tmp.is_a? LcClass)
  #     lc_bug("Previously declared Python Class/Module not found") 
  #   end
  #   return tmp.as(LcClass)
  # end

  ######################################
  #  ____ _____ ____    _     _ _      #
  # / ___|_   _|  _ \  | |   (_) |__   #
  # \___ \ | | | | | | | |   | | '_ \  #
  #  ___) || | | |_| | | |___| | |_) | #
  # |____/ |_| |____/  |_____|_|_.__/  #
  ######################################

  @[AlwaysInline]
  def self.lincas_class_compare(klass1 :  LcVal, klass2 :  LcVal)
    return klass2.is_a?(LcClass) && 
            ((lc_cast(klass1,LcClass).methods == lc_cast(klass2, LcClass).methods || 
            (klass1.object_id == klass2.object_id)))
  end

  def self.class_search_ancestor(cl : LcClass, c : LcVal)
    while cl
      if lincas_class_compare(cl, c)
        return  cl
      end
      cl = cl.parent
    end
    return nil
  end
  
  def self.lincas_obj_is_a(obj : LcVal, c : LcVal)
    if !(c.is_a? LcClass)
      lc_raise(lc_arg_err,"Argument must be a class or a module")
    end
    return !!class_search_ancestor(obj.klass, c)
  end
  
  @[AlwaysInline]
  def self.lc_is_a(obj :  LcVal, c :  LcVal)
    return val2bool(lincas_obj_is_a(obj, c))
  end

  def self.lc_class_real(klass : LcVal)
    return class_of(klass)
  end

  def self.lc_class_defrost(klass :  LcVal)
    klass.flags &= ~ObjectFlags::FROZEN 
    return klass 
  end 

  # TO BE TESTED
  def self.class_path(klass : LcClass)
    path     = [klass.name] of String
    id_table = klass.namespace.parent
    while id_table 
      super_id_table = id_table.parent 
      if super_id_table
        super_id_table.each do |k, v|
          if v.is_a?(LcClass) && v.namespace.object_id == id_table.object_id
            path << v.name
            break
          end
        end
      else 
        break # We reached the top level scope
      end
      id_table = super_id_table
    end 
    return path.reverse!.join("::")
  end

  def self.lc_class_inspect(klass : LcVal)
    tmp = String.build do |io|
        io << '"'
        klass = klass.as(LcClass)
        io << class_path(klass)
        io << '"'
    end
    return internal.build_string(tmp)
  end

  def self.lc_class_to_s(klass : LcVal)
    klass = lc_cast(klass,LcClass)
    name = class_path(klass)
    return build_string(name)
  end

  def self.lc_class_parent(klass :  LcVal)
    s_klass = lc_cast(klass, LcClass).parent
    return s_klass if s_klass
    return Null 
  end

  def self.alias_method_str(klass : LcClass, m_name : String, new_name : String)
    cc = seek_method(klass, m_name, explicit: false)
    if method = cc.method
      lc_add_method(klass,new_name,method)
    elsif cc.m_missing_status == 1
      lc_raise(lc_nomet_err,"Cannot alias protected methods")
      return false
    else
      lc_raise(lc_nomet_err, "Undefined method #{m_name} for #{class_path(klass)}")
      return false
    end
    return true
  end

  def self.lc_alias_method(klass :  LcVal, name :  LcVal, new_name :  LcVal)
    name = id2string(name)
    return lcfalse unless name 
    new_name = id2string(new_name)
    return lcfalse unless new_name
    if klass.is_a? LcClass
      return val2bool(alias_method_str(klass,name,new_name))
    else
      return val2bool(alias_method_str(class_of(klass),name,new_name))
    end
  end

  def self.lc_get_method(obj :  LcVal,name :  LcVal)
    name = id2string(name)
    return Null unless name 
    cc = seek_method(obj.klass,name, explicit: false, ignore_visib: true)
    unless cc.method 
      lc_raise(lc_nomet_err,"Undefined method `#{name}' for #{lc_typeof(obj)}")
      return Null 
    end
    return build_method(obj,cc.method.not_nil!)
  end

  def self.lc_instance_method(klass :  LcVal, name :  LcVal)
    name   = id2string(name)
    return Null unless name
    cc = seek_method(klass.klass, name, explicit: false, ignore_visib: true)
    unless cc.method
      lc_raise(lc_nomet_err,"Undefined method `#{name}' for #{lc_typeof(klass)}")
      return Null 
    end
    return build_unbound_method(cc.method.not_nil!)
  end


  def self.init_class
    @@lc_class  = lc_build_internal_class("Class", @@lc_module) { lc_build_class_class }
    define_method(@@lc_class,"parent",lc_class_parent,    0)
  end

end
