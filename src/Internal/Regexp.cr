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


# Regexp class implementation
#
# The algorithm bases on https://github.com/crystal-lang/crystal/blob/master/src/regex.cr
module LinCAS
  module Internal

    SLASH    = '/'

    class LcRegexp < LcBase
      property regexp

      def initialize
        @regexp = Regex.new ""
      end

      def initialize(@regexp : Regex)
      end
    end

    def self.lc_new_regexp(regexp : Regex)
      lincas_obj_alloc LcRegexp, @@lc_regexp, regexp
    end

    def self.lc_new_regexp_literal()
    end

    def self.lc_regex_allocate(klass :  LcVal)
      klass = klass.as(LcClass)
      reg   = lincas_obj_alloc LcRegexp, klass
      return reg.as( LcVal)
    end

    def self.lc_regex_union(unused, other : LcVal)
      list = [] of (String | Regex)
      lc_cast(other, Ary).each do |v|
        list << (v.is_a?(LcRegexp) ? v.regexp : string2cr v)
      end
      return lc_new_regexp(Regex.union list)
    end

    def self.lc_regex_escape(unused, string :  LcVal)
      str_check(string)
      str = String.build do |io|
        string_char_iterate(lc_cast(string,LcString)) do |chr|
          {% begin %}
          case chr
          when {{*Regex::SPECIAL_CHARACTERS}}
            io << '\\' << chr
          else
            io << chr
          end
          {% end %}
        end
      end
      return build_string_recycle str
    end

    def self.lc_regex_union_part(unused,value :  LcVal)
      if value.is_a? LcString
        return lc_regex_escape(nil, value)
      elsif value.is_a? LcRegexp
        return lc_regexp_to_s(value)
      end 
      lc_raise(lc_type_err,"Argument must be Regexp or String (#{lc_typeof(value)} given)")
    end

    def self.lc_regex_error(unused, string :  LcVal)
      str_check(string)
      if error = Regex.error? pointer_of(string).to_slice str_size(string)
        return build_string_recycle error
      end
      Null
    end

    def self.lc_regex_initialize(regex :  LcVal, source :  LcVal)
      string = string2cr source # TODO: optimize regex creation without creating middle string
      lc_cast(regex, LcRegexp).regexp = Regex.new string
      return regex
    end

    def self.lc_regexp_to_s(regex : LcVal)
      return build_string_recycle lc_cast(regex, LcRegexp).regexp.to_s
    end

    def self.lc_regexp_origin(regex : LcVal)
      return build_string lc_cast(regex, LcRegexp).regexp.source
    end

    def self.lc_regex_inspect(regex :  LcVal)
      return build_string_recycle lc_cast(regex, LcRegexp).regexp.inspect
    end

    def self.regex_inspect(regex :  LcVal)
      return new_string lc_cast(regex, LcRegexp).regexp.inspect
    end

    def self.lc_regex_match(regex :  LcVal, argv : LcVal)
      regex  = lc_cast(regex, LcRegexp)
      argv   = lc_cast(argv, Ary)
      string = argv[0]
      pos    = argv.size > 1 ? lc_num_to_cr_i(argv[1], Int32) : 0
      check_string(string)
      match_info = regex.regexp.match string, pos
      if match_info
        return new_match_data(regex, *match_info)
      end
      Null
    end

    @[AlwaysInline]
    def self.lc_regex_sum(regex : LcVal, other : LcVal)
      o = other.is_a?(LcRegexp) ? other.regexp : string2cr other
      return lc_new_regexp(lc_cast(regex, LcRegexp).regexp + o)
    end

    def self.lc_regex_eq(regex :  LcVal, other :  LcVal)
      return val2bool(
        other.is_a?(LcRegexp) && 
        (regex.object_id == other.object_id || 
               lc_cast(regex, LcRegexp).regexp == other.regexp)
      )
    end

    def self.lc_regex_name_table(regex :  LcVal)
      return lc_cast(regex, LcRegexp).regexp.lc_name_table
    end

    def self.init_regexp
      @@lc_regexp = internal.lc_build_internal_class("Regexp")
      define_allocator(@@lc_regexp, lc_regex_allocate)

      define_singleton_method(@@lc_regexp, "union", lc_regex_union,          -1)
      define_singleton_method(@@lc_regexp, "escape", lc_regex_escape,         1)
      define_singleton_method(@@lc_regexp, "union_part", lc_regex_union_part, 1)
      define_singleton_method(@@lc_regexp, "error?", lc_regex_error,          1)

      define_protected_method(@@lc_regexp, "initialize", lc_regex_initialize, 1)
      define_method(@@lc_regexp, "to_s", lc_regexp_to_s,                      0)
      define_method(@@lc_regexp, "origin", lc_regexp_origin,                  0)
      define_method(@@lc_regexp, "inspect", lc_regex_inspect,                 0)
      define_method(@@lc_regexp, "match", lc_regex_match,                    -2)
      define_method(@@lc_regexp, "+", lc_regex_sum,                           1)
      define_method(@@lc_regexp, "==", lc_regex_eq,                           1)
      define_method(@@lc_regexp, "name_table", lc_regex_name_table,           0)
      define_method(@@lc_regexp, "clone", lc_obj_self,                        0)
    end

  end
end