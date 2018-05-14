
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

macro expand_for_float
    {% for sign in {"+", "-", "*", "/", "**"} %}
        def {{sign.id}}(other : BigFloat)
            return BigFloat.new(self) {{sign.id}} other 
        end
    {% end %}
end

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

struct Float32
    expand_for_float
end

struct Float64
    expand_for_float
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
        puts "#{msg}\n","An internal error occourred.\n\
        Please open an issue and report the code which caused this message".colorize(:yellow)
        exit 1
    end

    def lc_warn(msg : String)
        puts "Warning: #{msg}\n"
    end

end
