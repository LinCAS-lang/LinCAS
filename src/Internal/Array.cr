
# Copyright (c) 2017-2023 Massimiliano Dal Mas
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

require "set"

module LinCAS::Internal
  MIN_ARY_CAPA = 3u32
  MAX_ARY_CAPA = UInt32::MAX
  CAPACITY_THRESHOLD = 256u32

  class LcArray < LcBase
    def initialize
      @capacity   = 3i64
      @size       = 0i64
      @ptr        = Pointer(LcVal).malloc(3)
    end
    property capacity : Int64, size : Int64, ptr

    def size=(value : Int32)
      @size = value.to_i64
    end

    def capacity=(value : Int32)
      @capacity = value.to_i64
    end
  end

  macro ary_range_to_null(ary,from,to)
    ({{from}}...{{to}}).each do |i|
        ary_set_index({{ary}},i,Null)
    end
  end

  macro ptr(ary) 
    lc_cast({{ary}}, LcArray).ptr 
  end 

  macro set_ary_size(ary,size)
    lc_cast({{ary}}, LcArray).size = {{size}}
  end

  macro set_ary_total_size(ary,size)
    lc_cast({{ary}}, LcArray).total_size = {{size}}
  end

  macro ary_size(ary)
    lc_cast({{ary}}, LcArray).size
  end

  macro ary_capacity(ary)
    lc_cast({{ary}}, LcArray).capacity
  end

  macro ary_set_index(ary, index, value)
    lc_cast({{ary}}, LcArray).ptr[{{index}}] = {{value}}
  end

  macro ary_at_index(ary, i)
    lc_cast({{ary}}, LcArray).ptr[{{i}}]
  end

  def self.calculate_new_capa(current)
    if current.zero?
      return MIN_ARY_CAPA
    elsif current < CAPACITY_THRESHOLD
      return current * 2
    end
    return current + (current + 3 * CAPACITY_THRESHOLD) // 4
  end

  def self.calculate_new_capa(current, new)
    capa = current
    while capa < new
      capa = calculate_new_capa(capa)
    end
    return capa
  end

  # It blindly resizes an array to the given capacity.
  # Ensuring consistency is the user of this function's
  # responsibility.
  def self.resize_array(ary : LcArray, capacity)
    ary.ptr = lincas_realloc(ary.ptr, capacity)
    ary.capacity = capacity.to_u32
  end

  def self.check_capacity(ary : LcArray)
    if ary.size == ary.capacity
      resize_array ary, calculate_new_capa(ary.capacity)
    end
  end

  def self.check_capacity(ary : LcArray, elem_to_insert)
    new_size = ary.size + elem_to_insert
    remaining_capa = ary.capacity - ary.size
    if elem_to_insert > remaining_capa
      resize_array ary, calculate_new_capa(ary.capacity, new_size)
    end 
  end

  def self.check_capacity2(ary : LcArray, new_capa)
    if ary.capacity < new_capa
      resize_array ary, calculate_new_capa(ary.capacity, new_capa)
    end
  end

  def self.to_array(obj : LcVal)
    if !obj.is_a? LcArray
      id = "to_a"
      if lc_obj_responds_to? obj, id
        obj = Exec.lc_call_fun obj, id
      end
    end
    if !obj.is_a? LcArray
      lc_raise(lc_type_err, "No implict conversion of #{lc_typeof(obj)} into array")
    end 
    return lc_cast(obj, LcArray)
  end

  def self.tuple2array(*values :  LcVal)
    ary = new_array_size(values.size).as(LcArray)
    values.each_with_index do |v, i|
      ary.ptr[i] = v 
    end
    return ary.as( LcVal)
  end

  # This function converts a LinCAS array to a Python list.
  # It takes as argument a LinCAS Object (array) and returns a
  # Python object reference (PyObject).
  # No check is performed on the passed argument (ary), so
  # be sure of what you're doing
  def self.ary2py(ary :  LcVal)
    size  = ary_size(ary)
    pyary = pyary_new(size)
    size.times do |i|
      item = ary_at_index(ary,i)
      res  = pyary_set_item(pyary,i,obj2py(item, ref: true).not_nil!)
      if res != 0 || pyerr_occurred
        lc_raise_py_error
      end
    end
    return pyary
  end

  # This functions converts a Python list to a LinCAS array.
  # It takes as argument a reference to a Python object and
  # it returns a LinCAS one.
  # Python object count reference is decreased.
  # No check is performed on the passed python object
  def self.pyary2ary(pyary : PyObject)
    ary  = new_array
    size = pyary_size(pyary)
    size.times do |i|
      item = pyary_get_item(pyary,i)
      lc_ary_push(ary,pyobj2lc(item, borrowed_ref: true))
    end
    pyobj_decref(pyary)
    return ary
  end

  def self.new_ary_wrapper
    ary = lincas_obj_alloc Ary, @@lc_array
    ary.flags |= ObjectFlags::FAKE
    return ary
  end


  def self.new_array
    return new_array_with_capa MIN_ARY_CAPA
  end

  def self.new_array_with_capa(capacity)
    ary = lc_ary_allocate @@lc_array
    check_capacity lc_cast(ary, LcArray), capacity
    return ary
  end

  def self.new_array_size(size)
    ary = lc_ary_allocate @@lc_array
    check_capacity lc_cast(ary, LcArray), size
    ary_range_to_null(ary, 0, size)
    set_ary_size(ary, size)
    return ary
  end

  def self.lc_ary_allocate(klass : LcVal)
    return lincas_obj_alloc LcArray, klass.as(LcClass)
  end

  def self.lc_ary_init(ary :  LcVal, size :  LcVal)
    x = lc_num_to_cr_i(size)
    check_capacity(lc_cast(ary, LcArray), x)
    ary_range_to_null(ary, 0, x)
    set_ary_size(ary, x)
    Null
  end

  def self.lc_ary_push(ary :  LcVal, value :  LcVal)
    check_capacity lc_cast(ary, LcArray)
    size = ary_size ary
    ary_set_index ary, size, value 
    set_ary_size ary,  size + 1
    return value
  end

  def self.lc_ary_pop(ary :  LcVal)
    size = ary_size ary
    if size == 0
      return Null 
    end 
    tmp = ptr(ary)[size - 1]
    set_ary_size ary, size - 1
    return tmp 
  end

  @[AlwaysInline]
  protected def self.ary_subseq(ary : LcVal, start, len)
    tmp = new_array_size len
    ptr(tmp).copy_from (ptr(ary) + start), len
    return tmp
  end

  def self.lc_ary_get(ary : LcVal, index : LcVal)
    if index.is_a? LcRange
      start, len = range_start_and_len index, ary_size(ary), true
      return ary_subseq(ary, start, len)
    else
      i = lc_num_to_cr_i(index)
      if i < 0
        i += ary_size ary
      end
      return (0 <= i < ary_size(ary)) ? ary_at_index(ary,i) : Null
    end
  end

  def self.lc_ary_set(ary : LcVal, index : LcVal, value : LcVal)
    ary = lc_cast(ary, LcArray)
    i = lc_num_to_cr_i(index)
    check_capacity2(ary, i)
    size = ary_size ary
    capacity = ary_capacity ary
    i += size if i < 0
    if i < 0
      lc_raise(lc_index_err, "(Index #{i} out of bounds)")
    end
    if i < size
      ary_set_index(ary, i, value)
    else
      ary_range_to_null(ary, size, i)
      ary_set_index(ary, i, value)
      set_ary_size(ary, i + 1)
    end
    return value
  end

  private def self.ary_iterate(ary :  LcVal)
    ary_p = 
    size  = ary_size(ary)
    (0...size).each do |i|
      yield(ptr(ary)[i])
      i += 1
    end
  end

  private def self.ary_iterate_with_index(ary :  LcVal)
    ary_p = ptr(ary)
    size  = ary_size(ary)
    (0...size).each do |i|
      yield(ary_p[i], i)
      i += 1
    end
  end

  private def self.ary_iterate_with_index(ary :  LcVal, index : Int64)
    ary_p = ptr(ary)
    size  = ary_size(ary)
    (index...size).each do |i|
      yield(ary_p[i],i)
      i += 1
    end
  end

  def self.lc_ary_include(ary :  LcVal, value :  LcVal)
    ary_iterate(ary) do |el|
      if test Exec.lc_call_fun(el, "==", value)
        return lctrue 
      end 
    end
    return lcfalse 
  end

  def self.lc_ary_clone(ary :  LcVal)
    size = ary_size(ary)
    capacity = ary_capacity(ary)
    ary2     = new_array_with_capa(capacity)
    ptr(ary2).copy_from(ptr(ary), size)
    set_ary_size(ary2, size)
    return ary2 
  end

  def self.lc_ary_concat(ary1 : LcVal, ary2 : LcVal)
    ary1 = lc_cast(ary1, LcArray)
    ary2 = to_array ary2
    check_capacity(ary1, ary_size(ary2))
    (ary1.ptr + ary1.size).copy_from ptr(ary2), ary_size(ary2)
    ary1.size += ary_size(ary2)
    return lc_cast(ary1, LcVal)
  end

  def self.lc_ary_add(ary1 : LcVal, ary2 : LcVal)
    ary2 = to_array ary2
    size1 = ary_size(ary1)
    size2 = ary_size(ary2)
    new_ary = new_array_with_capa size1 + size2
    ptr(new_ary).copy_from ptr(ary1), size1
    (ptr(new_ary) + size1).copy_from ptr(ary2), size2
    set_ary_size(new_ary, size1 + size2)
    return lc_cast(new_ary, LcVal)
  end

  @[AlwaysInline]
  def self.lc_ary_first(ary :  LcVal)
    if ary_size(ary) > 0
      return ary_at_index(ary,0)
    end
    return Null
  end 
  
  @[AlwaysInline]
  def self.lc_ary_last(ary :  LcVal)
    if ary_size(ary) > 0
      return ptr(ary)[ary_size(ary) - 1]
    end
    return Null
  end

  @[AlwaysInline]
  def self.lc_ary_size(ary :  LcVal)
    return num2int(ary_size(ary))
  end

  @[AlwaysInline]
  def self.lc_ary_empty(ary :  LcVal)
    return val2bool(ary_size(ary).zero?)
  end

  def self.ary_to_s_recursive(buffer, ary : LcArray, previous = [] of UInt64)
    if previous.includes? ary.object_id
      buffer << "[...]"
    else
      previous << ary.object_id
      buffer << '['
      size = ary_size(ary) - 1
      ary_iterate_with_index ary do |value, i|
        if !value.is_a? LcArray
          str = Exec.lc_call_fun(value, "to_s")
          buffer.write_string(pointer_of(str).to_slice(str_size(str)))
        else
          ary_to_s_recursive(buffer, value, previous)
        end
        unless i == size
          buffer << ',' << ' '
        end
      end
      buffer << ']'
    end
  end
  
  def self.lc_ary_to_s(ary :  LcVal)
    string = String::Builder.build do |buffer|
      ary_to_s_recursive(buffer, lc_cast(ary, LcArray))
    end
    return build_string string
  end

  def self.lc_ary_each(ary :  LcVal)
    arylen = ary_size(ary) 
    arylen.times do |i|
      Exec.lc_yield(ary_at_index(ary, i))
    end
    Null 
  end

  def self.lc_ary_each_with_index(ary :  LcVal)
    ary_size(ary).times do |i|
      Exec.lc_yield(ary_at_index(ary, i), num2int(i))
    end
    return Null 
  end

  def self.lc_ary_map(ary :  LcVal)
    arylen = ary_size(ary)
    tmp    = new_array_size arylen
    arylen.times do |i|
      ary_set_index(tmp, i, Exec.lc_yield(ary_at_index(ary, i)))
    end
    return tmp 
  end

  def self.lc_ary_map!(ary :  LcVal)
    ary_size(ary).times do |i|
      ary_set_index(ary,i,Exec.lc_yield(ary_at_index(ary,i)))
    end
    return ary 
  end 

  def self.lc_ary_map_with_index(ary :  LcVal)
    size = ary_size(ary)
    tmp  = new_array_size(size)
    size.times do |i|
      value = Exec.lc_yield(ary_at_index(ary, i), num2int(i)).as( LcVal)
      ary_set_index(tmp, i, value)
    end
    return tmp
  end 

  def self.lc_ary_map_with_index!(ary :  LcVal)
    size = ary_size(ary)
    ptr(ary).map_with_index!(size) do |value, i|
      next Exec.lc_yield(value, num2int(i))
    end
    return ary 
  end

  record FlatEntry,
    array : LcVal,
    index : Int64

  def self.lc_ary_flatten(ary :  LcVal)
    guard = Set(UInt64).new
    result = new_array_with_capa(ary_size(ary))
    stack = Array(FlatEntry).new
    current = ary
    i       = 0i64
    guard << ary.object_id
    loop do
      while i < ary_size(current)
        tmp = ary_at_index(current, i)
        i += 1
        if !tmp.is_a? LcArray
          lc_ary_push(result, tmp)
        else
          if !guard.includes? tmp.object_id
            stack.push FlatEntry.new current, i
            current = tmp
            i = 0i64
            guard << tmp.object_id
          else
            lc_raise(lc_arg_err, "Tried to flatten recursive array")
          end
        end
      end
      
      break if stack.empty?

      guard.delete current.object_id

      entry = stack.pop
      current = entry.array
      i = entry.index
    end
    return result
  end

  def self.lc_ary_flatten!(ary :  LcVal)
    tmp = lc_ary_flatten ary
    lc_cast(ary, LcArray).ptr = ptr(tmp)
    set_ary_size(ary, ary_size(tmp))
    return ary
  end

  def self.lc_ary_insert(ary :  LcVal, argv :  LcVal)
    argv = lc_cast(argv, Ary)
    i = lc_num_to_cr_i(argv[0])
    size = ary_size(ary)
    n = argv.size - 1 # we don't count the index
    if i < 0
      i += size
    end

    unless 0 <= i <= size
      lc_raise(lc_index_err, "(Index #{i} out of bounds)")
    end

    check_capacity lc_cast(ary, LcArray), n
    buffer = ptr(ary)
    (buffer + i + n).move_from (buffer + i), size - i
    (buffer + i).copy_from (argv.ptr + 1), n
    set_ary_size(ary, size + n)

    return ary
  end

  def self.lc_ary_eq(ary1 :  LcVal, ary2 :  LcVal)
    return lcfalse unless ary2.is_a? LcArray
    return lcfalse if ary_size(ary1) != ary_size(ary2)
    return lctrue if ary1.object_id == ary2.object_id
    arylen = ary_size(ary1)
    arylen.times do |i|
      return lcfalse unless lc_obj_compare(
        ary_at_index(ary1,i),
        ary_at_index(ary2,i)
      ) == lctrue 
    end
    return lctrue 
  end

  def self.lc_ary_swap(ary :  LcVal, i1 :  LcVal, i2 :  LcVal)
    x = lc_num_to_cr_i(i1)
    y = lc_num_to_cr_i(i2)
    size = ary_size(ary)
    unless 0 <= x < size && 0 <= x < size
      lc_raise(lc_index_err, "(Indexes out of bounds)")
    end 
    ptr = ptr(ary)
    ptr.swap(x, y)
    return Null 
  end 

  private def self.internal_ary_sort(ary :  LcVal*, size)
  end

  private def self.compare_with_block(a : LcVal, b : LcVal)
    return lc_cmpint(Exec.lc_yield(a, b), a, b)
  end

  private def self.compare(a : LcVal, b : LcVal)
    if a.is_a?(NumType) && b.is_a? NumType
      res = lincas_int_or_flo_cmp a, b
    elsif a.is_a?(LcString) && b.is_a? LcString 
      res = lincas_str_cmp(a, b)
    else
      res = lc_cmpint Exec.lc_call_fun(a, "<=>", b), a, b
    end
    return res
  end

  def self.lc_ary_sort(ary :  LcVal)
    tmp = lc_ary_clone ary
    lc_ary_sort! tmp
  end

  def self.lc_ary_sort!(ary :  LcVal)
    comp = Exec.block_given? ? ->compare_with_block(LcVal, LcVal) : ->compare(LcVal, LcVal)
    lc_heap_sort ptr(ary), ary_size(ary), &comp
    return ary
  end

  def self.lc_ary_reverse(ary : LcVal)
    tmp = lc_ary_clone ary
    return lc_ary_reverse! tmp
  end

  def self.lc_ary_reverse!(ary :  LcVal)
    size  = ary_size(ary)
    ptr   = ptr(ary)
    (size // 2).times do |i|
      ptr.swap(i, size - i - 1)
    end
    return ary 
  end

  def self.init_array
    @@lc_array = internal.lc_build_internal_class("Array")
    define_allocator(@@lc_array,lc_ary_allocate)
    
    define_protected_method(@@lc_array, "initialize", lc_ary_init,      1)
    define_method(@@lc_array, "+",              lc_ary_add,             1)
    define_method(@@lc_array, "push",           lc_ary_push,            1)
    alias_method_str(@@lc_array, "push","<<"                             )
    define_method(@@lc_array, "pop",            lc_ary_pop,             0)
    define_method(@@lc_array, "[]",             lc_ary_get,             1)
    define_method(@@lc_array, "[]=",            lc_ary_set,             2)
    define_method(@@lc_array, "include?",       lc_ary_include,         1)
    define_method(@@lc_array, "clone",          lc_ary_clone,           0)
    define_method(@@lc_array, "first",          lc_ary_first,           0)
    define_method(@@lc_array, "last",           lc_ary_last,            0)
    define_method(@@lc_array, "size",           lc_ary_size,            0)
    alias_method_str(@@lc_array, "size", "length"                        )
    define_method(@@lc_array, "empty?",         lc_ary_empty,           0)
    define_method(@@lc_array, "to_s",           lc_ary_to_s,            0)
    alias_method_str(@@lc_array, "to_s", "inspect"                       )
    define_method(@@lc_array,"each",           lc_ary_each,             0)
    define_method(@@lc_array,"each_with_index",lc_ary_each_with_index,  0)
    define_method(@@lc_array,"map",            lc_ary_map,              0)
    define_method(@@lc_array,"map!",           lc_ary_map!,             0)
    define_method(@@lc_array,"map_with_index", lc_ary_map_with_index,   0)
    define_method(@@lc_array,"map_with_index!",lc_ary_map_with_index!,  0)
    define_method(@@lc_array,"flatten",        lc_ary_flatten,          0)
    define_method(@@lc_array,"flatten!",        lc_ary_flatten!,        0)
    define_method(@@lc_array,"insert",         lc_ary_insert,          -3)
    define_method(@@lc_array,"==",             lc_ary_eq,               1)
    define_method(@@lc_array,"swap",           lc_ary_swap,             2)
    define_method(@@lc_array,"sort",           lc_ary_sort,             0)
    define_method(@@lc_array,"sort!",          lc_ary_sort!,            0)
    define_method(@@lc_array,"reverse",        lc_ary_reverse,          0)
    define_method(@@lc_array,"reverse!",       lc_ary_reverse!,         0)

    #lc_define_const(@@lc_kernel,"ARGV",define_argv)
  end
end

require "./Wrappers/LcArray"