# Copyright (c) 2017-2024 Massimiliano Dal Mas
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

  MATCH_DATA_HEADER = "#<MatchData:"
  MATCH_DATA_TAIL   = '>'

  class LcMatchData < LcBase
    include Regex::Engine::LcMatchData

    getter string, regex, group_size

    def size
      @group_size + 1
    end
  end

  def self.new_match_data(regex : LcRegexp, *match_info)
    return lincas_obj_alloc(LcMatchData, @@lc_match_data,
                regex, *match_info).as(LcVal)
  end

  # This version takes mixed parameters (lincas & crystal style)
  # and outputs crystal objects. It can return either a slice or
  # nil.
  @[AlwaysInline]
  def self.match_data_index_raw(mdata : LcMatchData, index : Int)
    range = mdata.byte_range(index) { return nil }
    return mdata.string.to_slice[range]?
  end
  
  @[AlwaysInline]
  def self.lincas_match_data_index(mdata : LcMatchData, index : Int)
    range = mdata.byte_range(index) { return Null }
    return str_index_range(mdata.string, range.begin, range.end, inclusive: false)
  end

  def self.lc_match_data_index(mdata : LcVal, index : LcVal)
    mdata = lc_cast(mdata, LcMatchData)
    case index
    when LcString
      return mdata.fetch_impl(index) { |exists|
        if !exists
          lc_raise(lc_index_err, "Undefined group name reference: #{index}")
        else
          return Null
        end
      }
    when LcNum
      index = lc_num_to_cr_i2 index
      return lincas_match_data_index mdata, index
    else
      lc_raise(lc_type_err, "No implicit conversion of #{lc_typeof(index)} into Integer")
    end

    # Unreachable
    return Null
  end

  def self.lc_match_data_to_s(mdata : LcVal)
    return lincas_match_data_index lc_cast(mdata, LcMatchData), 0
  end

  def self.lc_match_data_inspect(mdata : LcVal)
    mdata = lc_cast(mdata, LcMatchData)
    name_table = mdata.regex.regexp.name_table

    str = String.build do |io|
      io << "#<MatchData "
      mdata.size.times do |i|
        io << ' ' << name_table.fetch(i, i) << ':' if i > 0
        bytes = match_data_index_raw(mdata, i)
        io << '"'
        io.write bytes if bytes
        io << '"'
      end
      io << '>'
    end
    return build_string_recycle str
  end

  def self.lc_match_data_size(mdata : LcVal)
    return num2int(lc_cast(mdata, LcMatchData).group_size + 1)
  end

  def self.lc_match_data_group_size(mdata : LcVal)
    return num2int(lc_cast(mdata, LcMatchData).group_size)
  end

  def self.init_match_data
    @@lc_match_data = internal.lc_build_internal_class("MatchData")

    lc_undef_allocator(@@lc_match_data)

    define_method(@@lc_match_data, "to_s", lc_match_data_to_s,              0)
    define_method(@@lc_match_data, "inspect", lc_match_data_inspect,        0)
    define_method(@@lc_match_data, "size", lc_match_data_size,              0)
    define_method(@@lc_match_data, "group_size", lc_match_data_group_size,  0)
    define_method(@@lc_match_data, "[]", lc_match_data_index,               1)
  end

end