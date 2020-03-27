// This is only for convenience for main(). The real prototype used by the
// inmate is in inmates/lib/x86/include/inmate.h

int count_set_bits_mgh(unsigned char *, int, int);
unsigned long long random_access_mgh(unsigned char *, int);
void *sha3_mgh(const void *, int, void *, int);
