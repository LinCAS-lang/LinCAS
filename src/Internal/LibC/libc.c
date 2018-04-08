/***************************************************************************
*
* Copyright (c) 2017-2018 Massimiliano Dal Mas
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*      http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
****************************************************************************/

int add_overflow_i(int n1,int n2, int *var)
{
    return __builtin_add_overflow(n1,n2,var);
}

int add_overflow_l(long n1,long n2, long *var)
{
    return __builtin_add_overflow(n1,n2,var);
}

int sub_overflow_i(int n1, int n2, int *var)
{
    return __builtin_sub_overflow(n1,n2,var);
}

int sub_overflow_l(long n1, long n2, long *var)
{
    return __builtin_sub_overflow(n1,n2,var);
}

int mul_overflow_i(int n1, int n2, int *var)
{
    return __builtin_mul_overflow(n1,n2,var);
}

int mul_overflow_l(long n1, long n2, long *var)
{
    return __builtin_mul_overflow(n1,n2,var);
}

