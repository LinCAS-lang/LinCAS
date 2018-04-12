
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

class LinCAS::VMcall_tracker
 
    private struct Info
        def initialize(@filename : String,@line : Intnum, @callname : String)
        end   
        getter filename,line,callname     
    end

    def initialize
        @stack = [] of Info
    end

    @[AlwaysInline]
    def push_track(filename : String, line : Intnum, callname : String)
        @stack.push Info.new(filename,line,callname)
    end

    @[AlwaysInline]
    def pop_track
        @stack.pop 
    end

    @[AlwaysInline]
    def get_backtrace
        count = 0
        return String.build do |io|
            @stack.reverse_each do |element|
                io << '\n'
                io << "In: `"  << element.callname << '\'' << '\n'
                io << "Line: " << element.line     << '\n'
                io << "In: "   << element.filename << '\n'
                count += 1
                break if count == 10
            end
            if count == 10 && @stack.size > 10
                io << "  ...and other " << @stack.size - 10
                io << " items"
            end
        end
    end

end
