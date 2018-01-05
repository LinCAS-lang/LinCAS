
# Copyright (c) 2017 Massimiliano Dal Mas
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
    macro send_to(name,args,arity)
        {% if name == :lc_is_a %}
            internal_call(:lc_is_a,args,arity)
        {% elsif name == :lc_class_class %}
            internal_call(:lc_class_class,args,arity)
        {% elsif name == :lc_class_eq %}
            internal_call(:lc_class_eq,args,arity)
        {% elsif name == :lc_class_ne %}
            internal_call(:lc_class_ne,args,arity)
        {% elsif name == :lc_str_concat%}
            internal_call(:lc_str_concat,args,arity)
        {% elsif name == :lc_str_multiply %}
            internal_call(:lc_str_multiply,args,arity)
        {% else %}
            puts "Unreached"
        {% end %}
    end
    def self.send(name,args,arity)
        call_internal_1(:lc_str_concat,args)
    end
end