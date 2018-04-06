
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module LinCAS::Internal

    MIN_BUFFER_CAPA = 10

    class String_buffer
        @buffer = Pointer(LibC::Char).null 
        @size   = 0.as(Intnum)
        @capa   = 0.as(Intnum)
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
            if length > MIN_BUFFER_CAPA
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

    def self.buffer_append_n(buffer : String_buffer,*args)
        args.each do |arg|
            buffer_append(buffer,arg)
        end
    end

    def self.buffer_trunc(buffer)
        size = buff_size(buffer)
        resize_buff_capa_0(buffer,size + 1)
        buff_ptr(buffer)[size + 1] = END_CHR
    end

    def self.buffer_flush(buffer)
        resize_buff_capa_0(buffer,MIN_BUFFER_CAPA)
        set_buff_size(buffer,0)
    end
    
end