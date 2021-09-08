#include <stdio.h>
#include <stdint.h>

const char *base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ\
abcdefghijklmnopqrstuvwxyz0123456789+/";

uint64_t encrypt_c(const uint64_t msg, const uint64_t key) {
    uint64_t result = msg;
    for(int i=31;i>=0;i--) {
        result ^= (key & (1 << i));
    }
    return result;
}

uint64_t encrypt_c_2(const uint64_t msg, const uint64_t key) {
    uint64_t result = msg;
    for(int i=0;i < 32;i++) {
        result ^= (key & (1 << (31 - i)));
    }
    return result;
}



extern uint64_t encrypt_jasmin(const uint64_t msg, const uint64_t key);

int main(void) {
    const uint64_t key = 0x1d381f22be58ac3a;
    const uint64_t msg = 0x09a9d3591c6adb40;

    uint64_t result_c = encrypt_c(msg, key);
    uint64_t result_c_2 = encrypt_c_2(msg, key);
    uint64_t result_jazz = encrypt_jasmin(msg, key);
    printf("The C result is %lx\n", result_c);
    printf("The C_2 result is %lx\n", result_c_2);
    printf("The jasmin result is %lx\n\n", result_jazz);
    // declassify(msg); 

    for(int i=0;i<10;i++) {
        printf("%c",base64[result_c & 0x3f]);
        result_c >>= 6;
    }
    printf("\n");
    return 0;
}