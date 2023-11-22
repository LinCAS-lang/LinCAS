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

module LinCAS::Internal

  MATCH_DATA_HEADER = "#<MatchData:"
  MATCH_DATA_TAIL   = '>'

  class LcMatchData < LcBase
    include Regex::Engine::LcMatchData
  end

  def self.new_match_data(regex : LcRegexp, *match_info)
    return lincas_obj_alloc(LcMatchData, @@lc_match_data,
                regex, *match_info).as(LcVal)
  end

  def self.init_match_data
    @@lc_match_data = internal.lc_build_internal_class("MatchData")

    lc_undef_allocator(@@lc_match_data)
  end

end