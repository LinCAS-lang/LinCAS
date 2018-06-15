
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

    @@free_location = [] of IntnumR
    @@pyObjects     = [] of PyObject

    private def self.get_location
        if @@free_location.empty?
            @@pyObjects << PyObject.null
            return @@pyObjects.size - 1
        end
        return @@free_location.shift
    end

    def self.track(obj : PyObject)
        return -1 if obj.null?
        location = get_location
        @@pyObjects[location] = obj 
        return location
    end

    def self.dispose(gcref : IntnumR)
        return if gcref < 0
        obj = @@pyObjects[gcref]
        Python.Py_DecRef(obj)
        @@pyObjects[gcref] = PyObject.null
        @@free_location << gcref
    end

    def self.get_tracked(gcref : IntnumR)
        tmp = @@pyObjects[gcref]?
        tmp ||= PyObject.null
        lc_bug("PyGC provided or received a bad reference") if gcref < 0 || tmp.as(PyObject).null?
        return tmp.as(PyObject)
    end

    def self.clear_all
        @@pyObjects.each do |obj|
            Python.Py_DecRef(obj)
        end
    end

end