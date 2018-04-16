
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
    DirLib   = build_string(ENV["libDir"])
    Ext      = build_string(".lc")

    def self.check_required(path : String)
        return REQUIRED.includes? path 
    end

    def self.require_file(path : Value,opt : Value? = nil)
        path   = String.new(file_expand_path(path,opt))
        if !file_exist(path)
            lc_raise(LcLoadError,"No such file '#{path}'")
            return nil 
        else
            if !check_required(path)
                REQUIRED << path 
            else
                return nil 
            end
            parser = FFactory.makeParser(path)
            parser.singleErrOutput
            parser.noSummary
            ast    = parser.parse
            if !(parser.errCount > 0) && ast
                iseq = Compile.compile(ast,Code::LEAVE)
                return iseq 
            else 
                Exec.print_end_backtrace
            end
        end
        return nil
    end

    def self.lc_require_file(path : Value)
        str_check(path)
        iseq = require_file(path)
        if iseq 
            Exec.run(iseq)
            return lctrue
        end
        return lcfalse
    end

    require_file_ = LcProc.new do |args|
        next lc_require_file(lc_cast(args,T2)[1])
    end

    def self.lc_import_file(path : Value)
        str_check(path)
        lc_str_concat(path,[Ext])
        iseq = require_file(path,DirLib)
        if iseq 
            Exec.run(iseq)
            return lctrue
        end
        return lcfalse
    end

    import_file = LcProc.new do |args|
        next lc_import_file(lc_cast(args,T2)[1])
    end

    def self.lc_require_relative(path : Value)
        str_check(path)
        dir  = current_filedir
        dir  = build_string(dir)
        iseq = require_file(path,dir)
        if iseq
            Exec.run(iseq)
            return lctrue
        end 
        return lcfalse
    end

    require_relative = LcProc.new do |args|
        next lc_require_relative(lc_cast(args,T2)[1])
    end

    internal.lc_module_add_internal(LKernel,"require",require_file_,                 1)
    internal.lc_module_add_internal(LKernel,"import",import_file,                    1)
    internal.lc_module_add_internal(LKernel,"require_relative",require_relative,     1)

end