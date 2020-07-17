
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

    MIN_BUFFER_CAPA = 10

    class String_buffer
        @buffer = Pointer(LibC::Char).null 
        @size   = 0.as(IntnumR)
        @capa   = 0.as(IntnumR)
        property buffer,size,capa
    end

    macro set_buff_size(buffer,size)
        {{buffer}}.as(String_buffer).size = {{size}}
    end

    macro buff_size(buffer)
        {{buffer}}.as(String_buffer).size
    end

    macro set_buff_capa(buffer,capa)
        {{buffer}}.as(String_buffer).capa = {{capa}}
    end

    macro buff_capa(buffer)
        {{buffer}}.as(String_buffer).capa
    end

    macro buff_ptr(buffer)
        {{buffer}}.as(String_buffer).buffer
    end

    macro resize_buff_capa_default(buffer)
        capa = buff_capa({{buffer}})
        capa += MIN_BUFFER_CAPA
        {{buffer}}.buffer = buff_ptr({{buffer}}).realloc(capa)
        set_buff_capa({{buffer}},capa)
    end

    macro resize_buff_capa_0(buffer,new_capa)
        {{buffer}}.buffer = buff_ptr({{buffer}}).realloc({{new_capa}})
        set_buff_capa({{buffer}},{{new_capa}})
    end

    macro resize_buff_capa_1(buffer,length)
        capa = buff_capa({{buffer}})
        capa += {{length}}
        {{buffer}}.buffer = buff_ptr({{buffer}}).realloc(capa)
        set_buff_capa({{buffer}},capa)
    end

    macro set_buff_at(buffer,index,value)
        buff_ptr({{buffer}})[{{index}}] = {{value}}
    end

    def self.string_buffer_new
        buff = String_buffer.new 
        resize_buff_capa_default(buff)
        return buff
    end

    def self.buffer_append(buffer : String_buffer,string : LibC::Char*)
        length = libc.strlen(string).to_i64
        size   = buff_size(buffer)
        capa   = buff_capa(buffer)
        if size + length >= capa 
            if length >= MIN_BUFFER_CAPA
                resize_buff_capa_1(buffer,length)
            else
                resize_buff_capa_default(buffer)
            end
        end 
        ptr = buff_ptr(buffer) + size
        ptr.copy_from(string,length)
        set_buff_size(buffer,length + size)
    end

    def self.buffer_append(buffer : String_buffer,char : LibC::Char)
        size   = buff_size(buffer)
        capa   = buff_capa(buffer)
        if size >= capa
            resize_buff_capa_default(buffer)
        end
        set_buff_at(buffer,size,char)
        size += 1
        set_buff_size(buffer,size)
    end

    def self.buffer_append(buffer : String_buffer,string : String)
        buffer_append(buffer,string.to_unsafe)
    end

    def self.buffer_append(buffer : String_buffer,char : Char)
        buffer_append(buffer,char.ord.to_u8)
    end

    def self.buffer_append(buffer : String_buffer,string : LcString)
        buffer_append(buffer,pointer_of(string))
    end

    def self.buffer_append_n(buffer : String_buffer,*args)
        args.each do |arg|
            buffer_append(buffer,arg)
        end
    end

    def self.buffer_trunc(buffer : String_buffer)
        size = buff_size(buffer)
        resize_buff_capa_0(buffer,size + 1)
        buff_ptr(buffer)[size + 1] = END_CHR
    end

    def self.buffer_flush(buffer : String_buffer)
        resize_buff_capa_0(buffer,MIN_BUFFER_CAPA)
        set_buff_size(buffer,0)
    end

    def self.buffer_dispose(buffer : String_buffer)
        resize_buff_capa_0(buffer,0)
        set_buff_size(buffer,0)
    end

    def self.buffer_empty(buffer : String_buffer)
        return buff_size(buffer) == 0
    end
    
end