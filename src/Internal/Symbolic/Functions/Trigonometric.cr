
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

    define_function(Sin) do 
        return Cos.create(value) * value.diff(obj)
    end

    define_function(Cos) do
        return -Sin.create(value) * value.diff(obj)
    end

    define_function(Asin) do 
        tmp = value
        return tmp.diff(obj) / Sqrt.create(SONE - tmp ** STWO)
    end

    define_function(Acos) do 
        tmp = value 
        return -(tmp.diff(obj) / Sqrt.create(SONE - tmp ** STWO))
    end

    define_function(Tan) do 
        tmp = value
        return tmp.diff(obj) / Cos.create(tmp) ** STWO 
    end

    define_function(Atan) do 
        tmp = value 
        return tmp.diff(obj) / (SONE - tmp ** STWO)
    end

end