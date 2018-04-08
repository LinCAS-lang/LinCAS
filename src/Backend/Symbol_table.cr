
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

class LinCAS::Symbol_Table_Stack

    private struct ID_table 
        def initialize
            @cache = [] of String
        end

        @[AlwaysInline]
        def fetch(name : String)
            return @cache.includes? name
        end

        @[AlwaysInline]
        def set(name : String)
            unless @cache.includes? name 
                @cache << name
            end
        end

        {% if flag?(:debug)%}
            def print_table
                p @cache
            end
        {% end %}

    end

    def initialize
        @stack = [ID_table.new]
        @sp    = 1
    end

    @[AlwaysInline]
    def fetch(name : String, max_depth : Intnum)
        count = 0
        @stack.reverse_each do |table|
            {% if flag?(:debug) %}
                print "seeking in table"
                table.print_table 
            {% end %}

            if table.fetch(name)
                return count
            end
            break if max_depth == count
            count += 1
        end
        return -1
    end

    @[AlwaysInline]
    def set(name : String)
        {% if flag?(:debug) %}
            puts "Set variable '#{name}' in symbol table"
        {% end %}
        @stack.last.set(name)
    end 

    @[AlwaysInline]
    def push_table
        {% if flag?(:debug) %}
            puts "push new symbol table"
        {% end %}
        @stack.push ID_table.new 
        @sp        += 1
    end

    @[AlwaysInline]
    def pop_table
        {% if flag?(:debug) %}
            puts "pop symbol table"
        {% end %}
        @stack.pop
    end

end
