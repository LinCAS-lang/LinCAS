
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

  REQUIRED = [] of String

  {%for name in %w|dirlib ext sep|%}
    @@{{name.id}} = uninitialized LcVal
  {% end %}

  ParserAbort = Parser::ParserAbort

  def self.check_required(path : String)
    return REQUIRED.includes? path 
  end

  def self.require_file(path :  LcVal,opt :  LcVal? = nil)
    path = String.new(file_expand_path(path,opt))
    if !file_exist(path)
      lc_raise(lc_load_err,"No such file '#{path}'")
    else
      if !check_required(path)
        REQUIRED << path 
      else
        return nil 
      end
      parser = Parser.new(path, File.read(path) )
      return Compiler.compile(parser.parse)
    end
    return nil
  end

  def self.lc_require_file(unused,path :  LcVal)
    str_check(path)
    iseq = require_file(path)
    if iseq 
      VM.run(iseq)
      return lctrue
    end
    return lcfalse
  end

  def self.lc_import_file(unused,path :  LcVal)
    str_check(path)
    lc_str_concat(path,[@@sep,lc_str_clone(path),@@ext])
    iseq = require_file(path,@@dirlib)
    if iseq 
      VM.run(iseq)
      return lctrue
    end
    return lcfalse
  end

  def self.lc_require_relative(unused,path :  LcVal)
    str_check(path)
    dir  = current_filedir
    dir  = build_string(dir)
    iseq = require_file(path,dir)
    if iseq
      VM.run(iseq)
      return lctrue
    end 
    return lcfalse
  end

  def self.init_load
    @@dirlib   = build_string(ENV["libDir"])
    @@ext      = build_string(".lc")
    @@sep      = build_string("/")
    define_method(@@lc_kernel,"require", lc_require_file,              1)
    define_method(@@lc_kernel,"import", lc_import_file,                1)
    define_method(@@lc_kernel,"require_relative", lc_require_relative, 1)
  end

end