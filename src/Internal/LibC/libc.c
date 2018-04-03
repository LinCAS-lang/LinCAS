
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

