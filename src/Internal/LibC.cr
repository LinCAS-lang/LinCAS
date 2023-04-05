
# Copyright (c) 2017-2023 Massimiliano Dal Mas
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

@[Link(ldflags: "#{__DIR__}/LibC/libc.o")]
lib LibC
  fun strstr(str1 : Char*, str2 : Char*) : Char*
  fun printf(format : Char*, ... ) : Int 
  fun toupper(str : Char*) : Char*
  fun strlwr(str : Char*) : Char*
  fun strlen(str : Char*) : SizeT
  fun strtok(str : Char*, delimiter : Char*) : Char*
  fun strtol(str : Char*, endptr : Char*, base : Int) : Int
  fun strtod(str : Char*, endptr : Char**) : Double
  fun strcmp(str1 : Char*, str2 : Char*) : Int
end
