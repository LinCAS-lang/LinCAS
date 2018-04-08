
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

    def self.lc_heap_sort(heap : Pointer, size : Intnum,&block)
        n      = size
        parent = size / 2
        loop do
            if parent > 0
                parent -= 1
                tmp = heap[parent]
            else 
                n -= 1
                if n == 0
                    return nil
                end 
                tmp     = heap[n]
                heap[n] = heap[0]
            end
            index = parent 
            child = index * 2 + 1
            while child < n
                if child + 1 < n
                    cmp = yield(heap[child + 1],heap[child])
                    return unless cmp 
                    if cmp > 0
                        child += 1
                    end
                end
                cmp = yield(heap[child],tmp)
                return unless cmp 
                if cmp > 0
                    heap[index] = heap[child]
                    index = child 
                    child = index * 2 + 1
                else
                    break 
                end
            end
            heap[index] = tmp
        end
    end

        
end
