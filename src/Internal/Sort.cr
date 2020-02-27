
# Copyright (c) 2017-2019 Massimiliano Dal Mas
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

    MAX_THRESH = 16

    macro lg(n)
        sizeof(typeof(n)) * 8 - 1 - n.leading_zeros_count
    end

    def self.lc_heap_sort(heap : Pointer, size : IntnumR,&block)
        n      = size
        parent = size // 2
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

    {% if (Crystal::VERSION) < "0.29.0" %}

    protected def self.intro_sort!(a, n, comp)
      return if n < 2
      quick_sort_for_intro_sort!(a, n, Math.log2(n).to_i * 2, comp)
      insertion_sort!(a, n, comp)
    end

    protected def self.quick_sort_for_intro_sort!(a, n, d, comp)
      while n > 16
        if d == 0
          heap_sort!(a, n, comp)
          return
        end
        d -= 1
        center_median!(a, n, comp)
        c = partition_for_quick_sort!(a, n, comp)
        quick_sort_for_intro_sort!(c, n - (c - a), d, comp)
        n = c - a
      end
    end

    protected def self.heap_sort!(a, n, comp)
      (n / 2).downto 0 do |p|
        heapify!(a, p, n, comp)
      end
      while n > 1
        n -= 1
        a.value, a[n] = a[n], a.value
        heapify!(a, 0, n, comp)
      end
    end

    protected def self.heapify!(a, p, n, comp)
      v, c = a[p], p
      while c < (n - 1) / 2
        c = 2 * (c + 1)
        c -= 1 if comp.call(a[c], a[c - 1]) < 0
        break unless comp.call(v, a[c]) <= 0
        a[p] = a[c]
        p = c
      end
      if n & 1 == 0 && c == n / 2 - 1
        c = 2 * c + 1
        if comp.call(v, a[c]) < 0
          a[p] = a[c]
          p = c
        end
      end
      a[p] = v
    end

    protected def self.center_median!(a, n, comp)
      b, c = a + n / 2, a + n - 1
      if comp.call(a.value, b.value) <= 0
        if comp.call(b.value, c.value) <= 0
          return
        elsif comp.call(a.value, c.value) <= 0
          b.value, c.value = c.value, b.value
        else
          a.value, b.value, c.value = c.value, a.value, b.value
        end
      elsif comp.call(a.value, c.value) <= 0
        a.value, b.value = b.value, a.value
      elsif comp.call(b.value, c.value) <= 0
        a.value, b.value, c.value = b.value, c.value, a.value
      else
        a.value, c.value = c.value, a.value
      end
    end

    protected def self.partition_for_quick_sort!(a, n, comp)
      v, l, r = a[n / 2], a + 1, a + n - 1
      loop do
        while l < a + n && comp.call(l.value, v) < 0
          l += 1
        end
        r -= 1
        while r >= a && comp.call(v, r.value) < 0
          r -= 1
        end
        return l unless l < r
        l.value, r.value = r.value, l.value
        l += 1
      end
    end

    protected def self.insertion_sort!(a, n, comp)
      (1...n).each do |i|
        l = a + i
        v = l.value
        p = l - 1
        while l > a && comp.call(v, p.value) < 0
          l.value = p.value
          l, p = p, p - 1
        end
        l.value = v
      end
    end

    {% end %}

    def self.lincas_sort(vector : Pointer, size : Intnum,&block : LcVal,LcVal->_)
        {%if Crystal::VERSION < "0.29.0" %}
            intro_sort(vector, size, block)
            return vector
        {% else %}
            return Slice.new(vector,size).sort!.to_unsafe
        {% end %}
    end


        
end
