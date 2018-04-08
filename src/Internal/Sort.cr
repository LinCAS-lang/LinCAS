
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