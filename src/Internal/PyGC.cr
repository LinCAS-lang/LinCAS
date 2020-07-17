
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

module LinCAS::Internal::PyGC
    
    class Ref 
        property prev,follow
        getter object

        def initialize(@object : PyObject, @prev : Ref? = nil, @follow : Ref? = nil)
        end

        def dispose
            Python.Py_DecRef(@object) if !@object.null?
        end
    end

    @@last : Ref? = nil

    def self.track(obj : PyObject)
        tmp = Ref.new(obj,@@last)
        if !@@last.nil?
            @@last.as(Ref).follow = tmp 
        end
        return @@last = tmp 
    end

    def self.dispose(ref : Ref)
        prev   = ref.prev 
        follow = ref.follow
        if prev && follow 
            prev.follow = follow 
            follow.prev = prev 
        elsif !follow && @@last == ref
            @@last = prev
        end
        ref.dispose
    end

    def self.dispose(ref)
    end

    def self.get_tracked(gcref : IntnumR)
        tmp = @@pyObjects[gcref]?
        tmp ||= PyObject.null
        lc_bug("PyGC provided or received a bad reference") if gcref < 0 || tmp.as(PyObject).null?
        return tmp.as(PyObject)
    end

    def self.get_tracked(ref : Ref)
        return ref.object
    end

    def self.get_tracked(ref)
        lc_bug("PyGC provided or received a bad reference")
        return PyObject.null
    end

    def self.clear_all
        tmp = @@last
        while tmp 
            tmp.dispose
            tmp = tmp.prev 
        end
    end

end