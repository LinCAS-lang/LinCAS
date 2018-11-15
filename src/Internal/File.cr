
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

    F_OK = LibC::F_OK
    R_OK = LibC::R_OK
    W_OK = LibC::W_OK
    X_OK = LibC::X_OK

    Tilde = '~'.ord.to_u8

    private def self.file_accessible(file :  LcVal,flag)
        return LibC.access(pointer_of(file),flag) == 0
    end
    private def self.file_accessible(file : String,flag)
        return LibC.access(file,flag) == 0
    end

    private def self.file_exist(file :  LcVal)
        return file_accessible(file,F_OK)
    end

    private def self.file_exist(file : String)
        return file_accessible(file,F_OK)
    end

    def self.lc_file_exist(file :  LcVal)
        str_check(file)
        return val2bool(file_exist(file))
    end

    private def self.file_expand_path(file :  LcVal,dir :  LcVal? = nil)
        slash = SLASH.ord.to_u8
        tmp_s = build_string(SLASH.to_s)
        path  = string_buffer_new
        p     = pointer_of(file)
        if string_starts_with(file,Tilde)
            home   = ENV["HOME"]
            home   = home.chomp('/') unless home == slash
            strlen = str_size(file)
            if strlen >= 2 && str_char_at(file,1) == slash
                f = str_index_range(lc_cast(file,LcString),1,strlen,false)
                p = pointer_of(f)
                buffer_append_n(path,home,p)
            elsif strlen < 2
                return home.to_unsafe
            end
        end
        if !string_starts_with(file,slash)
            dir = dir ? file_expand_path(dir) : dir_current
            buffer_append_n(path,dir,SLASH,p)
        end
        if buffer_empty(path)
            buffer_append(path,lc_cast(file,LcString))
        end
        buffer_trunc(path)
        path_  = build_string_with_ptr(buff_ptr(path),buff_size(path))
        pieces = lc_str_split(path_,tmp_s)
        elem   = build_ary_new
        ary_iterate(pieces) do |e|
            e_ptr = pointer_of(e)
            if strcmp(e_ptr,"..") == 0
                lc_ary_pop(elem)
            elsif strcmp(e_ptr,".") == 0 || e_ptr.null?
            else
                lc_ary_push(elem,e)
            end
        end
        buffer_flush(path)
        buffer_append(path,slash)
        arylen = ary_size(elem) - 1
        ary_iterate_with_index(elem) do |e,i|
            buffer_append(path,lc_cast(e,LcString))
            buffer_append(path,slash) if i < arylen
        end
        buffer_trunc(path)
        return buff_ptr(path)
    end

    def self.lc_file_expand_path(file :  LcVal, argv : LcVal)
        argv = argv.as(Ary)
        str_check(file)
        str_check(argv[0]) unless argv.empty? 
        return build_string_with_ptr(file_expand_path(file,argv.empty? ? nil : argv[0]))
    end

    def self.init_file
        @@lc_file = internal.lc_build_internal_class("File")
        lc_undef_allocator(@@lc_file)
   
        define_method(@@lc_file,"exist?", lc_file_exist,             1)
        define_method(@@lc_file,"expand_path",lc_file_expand_path,  -1)
    end
    

end