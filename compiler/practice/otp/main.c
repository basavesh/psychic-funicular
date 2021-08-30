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

extern void encrypt_jasmin(uint64_t *r0);

int main(void) {
    uint64_t key = 0x1d381f22be58ac3a;
    uint64_t msg = 0x09a9d3591c6adb40;

    uint64_t result_c = encrypt_c(msg, key);
    // declassify(msg); 

    for(int i=0;i<10;i++) {
        printf("%c",base64[result_c & 0x3f]);
        result_c >>= 6;
    }
    printf("\n");
    return 0;
}