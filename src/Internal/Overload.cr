
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

macro expand_for_int
  {% for sign in {"+", "-", "*", "/", "**"} %}
    def {{sign.id}}(other : BigInt)
      return BigInt.new(self) {{sign.id}} other 
    end
  {% end %}
end

struct Int32
  expand_for_int
end

struct Crystal::Hasher
  def reset
    @a = @@seed[0]
    @b = @@seed[1]
  end
end 

class Object
  def lc_bug(msg : String)
    print "Bug: ".colorize(:red)
    puts "#{msg}\n"
    runtime_bt = VM.get_backtrace
    puts "Internal backtrace".colorize :yellow
    puts runtime_bt.split('\n').join("   \n").colorize :yellow
    puts
    backtrace = caller
    backtrace.shift
    backtrace.each do |location|
      print "    "
      puts location
    end
    puts "An internal error occourred.\n\
    Please open an issue and report the code which caused this message".colorize(:yellow)
    exit 1
  end

  def lc_warn(msg : String)
    puts "Warning: #{msg}\n"
  end

  def lincas_exit(status = 0)
    LinCAS::Internal.invoke_at_exit_procs status
    exit status
  end

  class FrozenError < Exception; end

  macro has_flag(obj,flag)
    ({{obj}}.flags & ObjectFlags::{{flag.id}} != ObjectFlags::NONE)
  end

  macro set_flag(obj, flag)
    ({{obj}}.flags ||= ObjectFlags::{{flag.id}})
  end

end

module Regex::PCRE2
  private def match_impl(str : LinCAS::Internal::LcString, byte_index, options)
    _match_impl(str, byte_index, options) { |tpl| tpl[1..-1] }
  end

  private def match_impl(str, byte_index, options)
    _match_impl(str, byte_index, options) { |tpl| ::Regex::MatchData.new *tpl }
  end

  @[AlwaysInline]
  private def _match_impl(str, byte_index, options)
    match_data = match_data(str, byte_index, options) || return

    ovector_count = LibPCRE2.get_ovector_count(match_data)
    ovector = Slice.new(LibPCRE2.get_ovector_pointer(match_data), ovector_count &* 2)

    # We need to dup the ovector because `match_data` is re-used for subsequent
    # matches (see `@match_data`).
    # Dup brings the ovector data into the realm of the GC.
    ovector = ovector.dup

    yield({self, @re, str, byte_index, ovector.to_unsafe, ovector_count.to_i32 &- 1})
  end

  private def match_data(str : LinCAS::Internal::LcString, byte_index, options)
    match_data = self.match_data
    match_count = LibPCRE2.match(@re, str.str_ptr, str.size, byte_index, pcre2_options(options) | LibPCRE2::NO_UTF_CHECK, match_data, PCRE2.match_context)

    if match_count < 0
      case error = LibPCRE2::Error.new(match_count)
      when .nomatch?
        return
      else
        LinCAS::Internal.lc_raise(LinCAS::Internal.lc_error, "Regex match error: #{error}")
      end
    end

    match_data
  end

  private def pcre2_options(options)
    flag = 0
    Regex::Options.each do |option|
      if options.includes?(option)
        flag |= case option
                when .ignore_case?   then LibPCRE2::CASELESS
                when .multiline?     then LibPCRE2::DOTALL | LibPCRE2::MULTILINE
                when .extended?      then LibPCRE2::EXTENDED
                when .anchored?      then LibPCRE2::ANCHORED
                when .utf_8?         then LibPCRE2::UTF
                when .no_utf8_check? then LibPCRE2::NO_UTF_CHECK
                when .dupnames?      then LibPCRE2::DUPNAMES
                when .ucp?           then LibPCRE2::UCP
                else
                  lc_bug "unreachable"
                end
        options &= ~option
      end
    end
    unless options.none?
      LinCAS::Internal.lc_raise(LinCAS::Internal.lc_arg_err, "Unknown regexp option value: #{options}")
    end
    flag
  end

  module LcMatchData
    def initialize(
      @regex : LinCAS::Internal::LcRegexp, 
      @code : LibPCRE2::Code*, 
      @string : LinCAS::Internal::LcString, 
      @pos : Int32, 
      @ovector : LibC::SizeT*, 
      @group_size : Int32
    )
    end
  end
end

module Regex::PCRE

  module LcMatchData
    def initialize(
      @regex : LinCAS::Internal::LcRegexp, 
      @code : LibPCRE::Pcre, 
      @string : LinCAS::Internal::LcString, 
      @pos : Int32, 
      @ovector : Int32*, 
      @group_size : Int32
    )
    end
  end
end

class Regex
  alias LcString = LinCAS::Internal::LcString
  def match(str : LinCAS::Internal::LcString, pos, options = Regex::Options::None)
    match_at_byte_index(str, pos, options)
  end

  def match_at_byte_index(str : LinCAS::Internal::LcString, pos, options = Regex::Options::None)
    if pos > LinCAS::Internal.str_size(str)
      nil
    else
      match_impl(str, pos, options)
    end
  end
end
