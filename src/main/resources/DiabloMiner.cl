// ArtForz's kernel

typedef uint z;

#if BITALIGN
#pragma OPENCL EXTENSION cl_amd_media_ops : enable
#define Zrotr(a, b) amd_bitalign((z)a, (z)a, (z)b)
#define Ch(a, b, c) amd_bytealign(a, b, c)
#define Ma(a, b, c) amd_bytealign((b), (a | c), (c & a))
#else
#define Zrotr(a, b) rotate((z)a, (z)(32 - b))
#define Ch(a, b, c) (c ^ (a & (b ^ c)))
#define Ma(a, b, c) ((b & c) | (a & (b | c)))
#endif

#define Ma2(a, b, c) ((b & c) | (a & (b | c)))

__constant uint K[64] = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

__kernel void search(
    const uint fW0, const uint fW1, const uint fW2,
    const uint fW3, const uint fW15, const uint fW01r,
    const uint fcty_e, const uint fcty_e2,
    const uint state0, const uint state1, const uint state2, const uint state3,
    const uint state4, const uint state5, const uint state6, const uint state7,
    const uint b1, const uint c1, const uint d1,
    const uint f1, const uint g1, const uint h1,
    const uint base,
    __global uint * output)
{
  z ZA, ZB, ZC, ZD, ZE, ZF, ZG, ZH;
  z ZW0, ZW1, ZW2, ZW3, ZW4, ZW5, ZW6, ZW7, ZW8, ZW9, ZW10, ZW11, ZW12, ZW13, ZW14, ZW15;
  z Znonce = base + get_global_id(0);

  #ifdef DOLOOPS
  Znonce *= (z)LOOPS;

  uint it;
  const z Zloopnonce = Znonce;
  for(it = LOOPS; it != 0; i--) {
    Znonce = (LOOPS - it) ^ Zloopnonce;
  #endif
    
    ZW3 = Znonce + fW3;
  
    ZE = fcty_e + Znonce;
    ZA = state0 + ZE;
    ZE = ZE + fcty_e2;
    ZD = d1 + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, b1, c1) + K[ 4] + 0x80000000;
    ZH = h1 + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma2(g1, ZE, f1);
    ZC = c1 + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, b1) + K[ 5];
    ZG = g1 + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma2(f1, ZD, ZE);
    ZB = b1 + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[ 6];
    ZF = f1 + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[ 7];
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[ 8];
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[ 9];
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[10];
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[11];
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[12];
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[13];
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[14];
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[15] + 0x00000280U;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[16] + fW0;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[17] + fW1;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW2 = (Zrotr(Znonce, 7) ^ Zrotr(Znonce, 18) ^ (Znonce >> 3U)) + fW2;
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[18] + ZW2;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[19] + ZW3;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW4 = (Zrotr(ZW2, 17) ^ Zrotr(ZW2, 19) ^ (ZW2 >> 10U)) + 0x80000000;
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[20] + ZW4;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW5 = (Zrotr(ZW3, 17) ^ Zrotr(ZW3, 19) ^ (ZW3 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[21] + ZW5;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW6 = (Zrotr(ZW4, 17) ^ Zrotr(ZW4, 19) ^ (ZW4 >> 10U)) + 0x00000280U;
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[22] + ZW6;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW7 = (Zrotr(ZW5, 17) ^ Zrotr(ZW5, 19) ^ (ZW5 >> 10U)) + fW0;
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[23] + ZW7;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW8 = (Zrotr(ZW6, 17) ^ Zrotr(ZW6, 19) ^ (ZW6 >> 10U)) + fW1;
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[24] + ZW8;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW9 = ZW2 + (Zrotr(ZW7, 17) ^ Zrotr(ZW7, 19) ^ (ZW7 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[25] + ZW9;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW10 = ZW3 + (Zrotr(ZW8, 17) ^ Zrotr(ZW8, 19) ^ (ZW8 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[26] + ZW10;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW11 = ZW4 + (Zrotr(ZW9, 17) ^ Zrotr(ZW9, 19) ^ (ZW9 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[27] + ZW11;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW12 = ZW5 + (Zrotr(ZW10, 17) ^ Zrotr(ZW10, 19) ^ (ZW10 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[28] + ZW12;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW13 = ZW6 + (Zrotr(ZW11, 17) ^ Zrotr(ZW11, 19) ^ (ZW11 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[29] + ZW13;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW14 = 0x00a00055U + ZW7 + (Zrotr(ZW12, 17) ^ Zrotr(ZW12, 19) ^ (ZW12 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[30] + ZW14;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW15 = fW15 + ZW8 + (Zrotr(ZW13, 17) ^ Zrotr(ZW13, 19) ^ (ZW13 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[31] + ZW15;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW0 = fW01r + ZW9 + (Zrotr(ZW14, 17) ^ Zrotr(ZW14, 19) ^ (ZW14 >> 10U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[32] + ZW0;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW1 = fW1 + (Zrotr(ZW2, 7) ^ Zrotr(ZW2, 18) ^ (ZW2 >> 3U)) + ZW10 + (Zrotr(ZW15, 17) ^ Zrotr(ZW15, 19) ^ (ZW15 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[33] + ZW1;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW2 = ZW2 + (Zrotr(ZW3, 7) ^ Zrotr(ZW3, 18) ^ (ZW3 >> 3U)) + ZW11 + (Zrotr(ZW0, 17) ^ Zrotr(ZW0, 19) ^ (ZW0 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[34] + ZW2;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW3 = ZW3 + (Zrotr(ZW4, 7) ^ Zrotr(ZW4, 18) ^ (ZW4 >> 3U)) + ZW12 + (Zrotr(ZW1, 17) ^ Zrotr(ZW1, 19) ^ (ZW1 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[35] + ZW3;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW4 = ZW4 + (Zrotr(ZW5, 7) ^ Zrotr(ZW5, 18) ^ (ZW5 >> 3U)) + ZW13 + (Zrotr(ZW2, 17) ^ Zrotr(ZW2, 19) ^ (ZW2 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[36] + ZW4;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW5 = ZW5 + (Zrotr(ZW6, 7) ^ Zrotr(ZW6, 18) ^ (ZW6 >> 3U)) + ZW14 + (Zrotr(ZW3, 17) ^ Zrotr(ZW3, 19) ^ (ZW3 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[37] + ZW5;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW6 = ZW6 + (Zrotr(ZW7, 7) ^ Zrotr(ZW7, 18) ^ (ZW7 >> 3U)) + ZW15 + (Zrotr(ZW4, 17) ^ Zrotr(ZW4, 19) ^ (ZW4 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[38] + ZW6;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW7 = ZW7 + (Zrotr(ZW8, 7) ^ Zrotr(ZW8, 18) ^ (ZW8 >> 3U)) + ZW0 + (Zrotr(ZW5, 17) ^ Zrotr(ZW5, 19) ^ (ZW5 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[39] + ZW7;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW8 = ZW8 + (Zrotr(ZW9, 7) ^ Zrotr(ZW9, 18) ^ (ZW9 >> 3U)) + ZW1 + (Zrotr(ZW6, 17) ^ Zrotr(ZW6, 19) ^ (ZW6 >> 10U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[40] + ZW8;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW9 = ZW9 + (Zrotr(ZW10, 7) ^ Zrotr(ZW10, 18) ^ (ZW10 >> 3U)) + ZW2 + (Zrotr(ZW7, 17) ^ Zrotr(ZW7, 19) ^ (ZW7 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[41] + ZW9;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW10 = ZW10 + (Zrotr(ZW11, 7) ^ Zrotr(ZW11, 18) ^ (ZW11 >> 3U)) + ZW3 + (Zrotr(ZW8, 17) ^ Zrotr(ZW8, 19) ^ (ZW8 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[42] + ZW10;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW11 = ZW11 + (Zrotr(ZW12, 7) ^ Zrotr(ZW12, 18) ^ (ZW12 >> 3U)) + ZW4 + (Zrotr(ZW9, 17) ^ Zrotr(ZW9, 19) ^ (ZW9 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[43] + ZW11;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW12 = ZW12 + (Zrotr(ZW13, 7) ^ Zrotr(ZW13, 18) ^ (ZW13 >> 3U)) + ZW5 + (Zrotr(ZW10, 17) ^ Zrotr(ZW10, 19) ^ (ZW10 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[44] + ZW12;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW13 = ZW13 + (Zrotr(ZW14, 7) ^ Zrotr(ZW14, 18) ^ (ZW14 >> 3U)) + ZW6 + (Zrotr(ZW11, 17) ^ Zrotr(ZW11, 19) ^ (ZW11 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[45] + ZW13;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW14 = ZW14 + (Zrotr(ZW15, 7) ^ Zrotr(ZW15, 18) ^ (ZW15 >> 3U)) + ZW7 + (Zrotr(ZW12, 17) ^ Zrotr(ZW12, 19) ^ (ZW12 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[46] + ZW14;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW15 = ZW15 + (Zrotr(ZW0, 7) ^ Zrotr(ZW0, 18) ^ (ZW0 >> 3U)) + ZW8 + (Zrotr(ZW13, 17) ^ Zrotr(ZW13, 19) ^ (ZW13 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[47] + ZW15;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW0 = ZW0 + (Zrotr(ZW1, 7) ^ Zrotr(ZW1, 18) ^ (ZW1 >> 3U)) + ZW9 + (Zrotr(ZW14, 17) ^ Zrotr(ZW14, 19) ^ (ZW14 >> 10U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[48] + ZW0;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW1 = ZW1 + (Zrotr(ZW2, 7) ^ Zrotr(ZW2, 18) ^ (ZW2 >> 3U)) + ZW10 + (Zrotr(ZW15, 17) ^ Zrotr(ZW15, 19) ^ (ZW15 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[49] + ZW1;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW2 = ZW2 + (Zrotr(ZW3, 7) ^ Zrotr(ZW3, 18) ^ (ZW3 >> 3U)) + ZW11 + (Zrotr(ZW0, 17) ^ Zrotr(ZW0, 19) ^ (ZW0 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[50] + ZW2;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW3 = ZW3 + (Zrotr(ZW4, 7) ^ Zrotr(ZW4, 18) ^ (ZW4 >> 3U)) + ZW12 + (Zrotr(ZW1, 17) ^ Zrotr(ZW1, 19) ^ (ZW1 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[51] + ZW3;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW4 = ZW4 + (Zrotr(ZW5, 7) ^ Zrotr(ZW5, 18) ^ (ZW5 >> 3U)) + ZW13 + (Zrotr(ZW2, 17) ^ Zrotr(ZW2, 19) ^ (ZW2 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[52] + ZW4;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW5 = ZW5 + (Zrotr(ZW6, 7) ^ Zrotr(ZW6, 18) ^ (ZW6 >> 3U)) + ZW14 + (Zrotr(ZW3, 17) ^ Zrotr(ZW3, 19) ^ (ZW3 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[53] + ZW5;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW6 = ZW6 + (Zrotr(ZW7, 7) ^ Zrotr(ZW7, 18) ^ (ZW7 >> 3U)) + ZW15 + (Zrotr(ZW4, 17) ^ Zrotr(ZW4, 19) ^ (ZW4 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[54] + ZW6;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW7 = ZW7 + (Zrotr(ZW8, 7) ^ Zrotr(ZW8, 18) ^ (ZW8 >> 3U)) + ZW0 + (Zrotr(ZW5, 17) ^ Zrotr(ZW5, 19) ^ (ZW5 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[55] + ZW7;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW8 = ZW8 + (Zrotr(ZW9, 7) ^ Zrotr(ZW9, 18) ^ (ZW9 >> 3U)) + ZW1 + (Zrotr(ZW6, 17) ^ Zrotr(ZW6, 19) ^ (ZW6 >> 10U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[56] + ZW8;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW9 = ZW9 + (Zrotr(ZW10, 7) ^ Zrotr(ZW10, 18) ^ (ZW10 >> 3U)) + ZW2 + (Zrotr(ZW7, 17) ^ Zrotr(ZW7, 19) ^ (ZW7 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[57] + ZW9;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW10 = ZW10 + (Zrotr(ZW11, 7) ^ Zrotr(ZW11, 18) ^ (ZW11 >> 3U)) + ZW3 + (Zrotr(ZW8, 17) ^ Zrotr(ZW8, 19) ^ (ZW8 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[58] + ZW10;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW11 = ZW11 + (Zrotr(ZW12, 7) ^ Zrotr(ZW12, 18) ^ (ZW12 >> 3U)) + ZW4 + (Zrotr(ZW9, 17) ^ Zrotr(ZW9, 19) ^ (ZW9 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[59] + ZW11;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW12 = ZW12 + (Zrotr(ZW13, 7) ^ Zrotr(ZW13, 18) ^ (ZW13 >> 3U)) + ZW5 + (Zrotr(ZW10, 17) ^ Zrotr(ZW10, 19) ^ (ZW10 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[60] + ZW12;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW13 = ZW13 + (Zrotr(ZW14, 7) ^ Zrotr(ZW14, 18) ^ (ZW14 >> 3U)) + ZW6 + (Zrotr(ZW11, 17) ^ Zrotr(ZW11, 19) ^ (ZW11 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[61] + ZW13;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW14 = ZW14 + (Zrotr(ZW15, 7) ^ Zrotr(ZW15, 18) ^ (ZW15 >> 3U)) + ZW7 + (Zrotr(ZW12, 17) ^ Zrotr(ZW12, 19) ^ (ZW12 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[62] + ZW14;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW15 = ZW15 + (Zrotr(ZW0, 7) ^ Zrotr(ZW0, 18) ^ (ZW0 >> 3U)) + ZW8 + (Zrotr(ZW13, 17) ^ Zrotr(ZW13, 19) ^ (ZW13 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[63] + ZW15;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);

    ZW0 = ZA + state0;
    ZW1 = ZB + state1;
    ZW2 = ZC + state2;
    ZW3 = ZD + state3;
    ZW4 = ZE + state4;
    ZW5 = ZF + state5;
    ZW6 = ZG + state6;
    ZW7 = ZH + state7;

    ZH = 0xb0edbdd0 + K[ 0] + ZW0;
    ZD = 0xa54ff53a + ZH;
    ZH = ZH + 0x08909ae5U;
    ZG = 0x1f83d9abU + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + (0x9b05688cU ^ (ZD & 0xca0b3af3U)) + K[ 1] + ZW1;
    ZC = 0x3c6ef372U + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma2(0xbb67ae85U, ZH, 0x6a09e667U);
    ZF = 0x9b05688cU + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, 0x510e527fU) + K[ 2] + ZW2;
    ZB = 0xbb67ae85U + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma2(0x6a09e667U, ZG, ZH);
    ZE = 0x510e527fU + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[ 3] + ZW3;
    ZA = 0x6a09e667U + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[ 4] + ZW4;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[ 5] + ZW5;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[ 6] + ZW6;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[ 7] + ZW7;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[ 8] + 0x80000000;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[ 9];
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[10];
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[11];
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[12];
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[13];
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[14];
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[15] + 0x00000100U;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW0 = ZW0 + (Zrotr(ZW1, 7) ^ Zrotr(ZW1, 18) ^ (ZW1 >> 3U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[16] + ZW0;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW1 = ZW1 + (Zrotr(ZW2, 7) ^ Zrotr(ZW2, 18) ^ (ZW2 >> 3U)) + 0x00a00000U;
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[17] + ZW1;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW2 = ZW2 + (Zrotr(ZW3, 7) ^ Zrotr(ZW3, 18) ^ (ZW3 >> 3U)) + (Zrotr(ZW0, 17) ^ Zrotr(ZW0, 19) ^ (ZW0 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[18] + ZW2;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW3 = ZW3 + (Zrotr(ZW4, 7) ^ Zrotr(ZW4, 18) ^ (ZW4 >> 3U)) + (Zrotr(ZW1, 17) ^ Zrotr(ZW1, 19) ^ (ZW1 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[19] + ZW3;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW4 = ZW4 + (Zrotr(ZW5, 7) ^ Zrotr(ZW5, 18) ^ (ZW5 >> 3U)) + (Zrotr(ZW2, 17) ^ Zrotr(ZW2, 19) ^ (ZW2 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[20] + ZW4;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW5 = ZW5 + (Zrotr(ZW6, 7) ^ Zrotr(ZW6, 18) ^ (ZW6 >> 3U)) + (Zrotr(ZW3, 17) ^ Zrotr(ZW3, 19) ^ (ZW3 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[21] + ZW5;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW6 = ZW6 + (Zrotr(ZW7, 7) ^ Zrotr(ZW7, 18) ^ (ZW7 >> 3U)) + 0x00000100U + (Zrotr(ZW4, 17) ^ Zrotr(ZW4, 19) ^ (ZW4 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[22] + ZW6;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW7 = ZW7 + 0x11002000U + ZW0 + (Zrotr(ZW5, 17) ^ Zrotr(ZW5, 19) ^ (ZW5 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[23] + ZW7;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW8 = 0x80000000 + ZW1 + (Zrotr(ZW6, 17) ^ Zrotr(ZW6, 19) ^ (ZW6 >> 10U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[24] + ZW8;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW9 = ZW2 + (Zrotr(ZW7, 17) ^ Zrotr(ZW7, 19) ^ (ZW7 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[25] + ZW9;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW10 = ZW3 + (Zrotr(ZW8, 17) ^ Zrotr(ZW8, 19) ^ (ZW8 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[26] + ZW10;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW11 = ZW4 + (Zrotr(ZW9, 17) ^ Zrotr(ZW9, 19) ^ (ZW9 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[27] + ZW11;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW12 = ZW5 + (Zrotr(ZW10, 17) ^ Zrotr(ZW10, 19) ^ (ZW10 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[28] + ZW12;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW13 = ZW6 + (Zrotr(ZW11, 17) ^ Zrotr(ZW11, 19) ^ (ZW11 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[29] + ZW13;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW14 = 0x00400022U + ZW7 + (Zrotr(ZW12, 17) ^ Zrotr(ZW12, 19) ^ (ZW12 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[30] + ZW14;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW15 = 0x00000100U + (Zrotr(ZW0, 7) ^ Zrotr(ZW0, 18) ^ (ZW0 >> 3U)) + ZW8 + (Zrotr(ZW13, 17) ^ Zrotr(ZW13, 19) ^ (ZW13 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[31] + ZW15;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW0 = ZW0 + (Zrotr(ZW1, 7) ^ Zrotr(ZW1, 18) ^ (ZW1 >> 3U)) + ZW9 + (Zrotr(ZW14, 17) ^ Zrotr(ZW14, 19) ^ (ZW14 >> 10U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[32] + ZW0;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW1 = ZW1 + (Zrotr(ZW2, 7) ^ Zrotr(ZW2, 18) ^ (ZW2 >> 3U)) + ZW10 + (Zrotr(ZW15, 17) ^ Zrotr(ZW15, 19) ^ (ZW15 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[33] + ZW1;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW2 = ZW2 + (Zrotr(ZW3, 7) ^ Zrotr(ZW3, 18) ^ (ZW3 >> 3U)) + ZW11 + (Zrotr(ZW0, 17) ^ Zrotr(ZW0, 19) ^ (ZW0 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[34] + ZW2;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW3 = ZW3 + (Zrotr(ZW4, 7) ^ Zrotr(ZW4, 18) ^ (ZW4 >> 3U)) + ZW12 + (Zrotr(ZW1, 17) ^ Zrotr(ZW1, 19) ^ (ZW1 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[35] + ZW3;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW4 = ZW4 + (Zrotr(ZW5, 7) ^ Zrotr(ZW5, 18) ^ (ZW5 >> 3U)) + ZW13 + (Zrotr(ZW2, 17) ^ Zrotr(ZW2, 19) ^ (ZW2 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[36] + ZW4;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW5 = ZW5 + (Zrotr(ZW6, 7) ^ Zrotr(ZW6, 18) ^ (ZW6 >> 3U)) + ZW14 + (Zrotr(ZW3, 17) ^ Zrotr(ZW3, 19) ^ (ZW3 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[37] + ZW5;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW6 = ZW6 + (Zrotr(ZW7, 7) ^ Zrotr(ZW7, 18) ^ (ZW7 >> 3U)) + ZW15 + (Zrotr(ZW4, 17) ^ Zrotr(ZW4, 19) ^ (ZW4 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[38] + ZW6;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW7 = ZW7 + (Zrotr(ZW8, 7) ^ Zrotr(ZW8, 18) ^ (ZW8 >> 3U)) + ZW0 + (Zrotr(ZW5, 17) ^ Zrotr(ZW5, 19) ^ (ZW5 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[39] + ZW7;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW8 = ZW8 + (Zrotr(ZW9, 7) ^ Zrotr(ZW9, 18) ^ (ZW9 >> 3U)) + ZW1 + (Zrotr(ZW6, 17) ^ Zrotr(ZW6, 19) ^ (ZW6 >> 10U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[40] + ZW8;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW9 = ZW9 + (Zrotr(ZW10, 7) ^ Zrotr(ZW10, 18) ^ (ZW10 >> 3U)) + ZW2 + (Zrotr(ZW7, 17) ^ Zrotr(ZW7, 19) ^ (ZW7 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[41] + ZW9;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW10 = ZW10 + (Zrotr(ZW11, 7) ^ Zrotr(ZW11, 18) ^ (ZW11 >> 3U)) + ZW3 + (Zrotr(ZW8, 17) ^ Zrotr(ZW8, 19) ^ (ZW8 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[42] + ZW10;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW11 = ZW11 + (Zrotr(ZW12, 7) ^ Zrotr(ZW12, 18) ^ (ZW12 >> 3U)) + ZW4 + (Zrotr(ZW9, 17) ^ Zrotr(ZW9, 19) ^ (ZW9 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[43] + ZW11;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW12 = ZW12 + (Zrotr(ZW13, 7) ^ Zrotr(ZW13, 18) ^ (ZW13 >> 3U)) + ZW5 + (Zrotr(ZW10, 17) ^ Zrotr(ZW10, 19) ^ (ZW10 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[44] + ZW12;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW13 = ZW13 + (Zrotr(ZW14, 7) ^ Zrotr(ZW14, 18) ^ (ZW14 >> 3U)) + ZW6 + (Zrotr(ZW11, 17) ^ Zrotr(ZW11, 19) ^ (ZW11 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[45] + ZW13;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW14 = ZW14 + (Zrotr(ZW15, 7) ^ Zrotr(ZW15, 18) ^ (ZW15 >> 3U)) + ZW7 + (Zrotr(ZW12, 17) ^ Zrotr(ZW12, 19) ^ (ZW12 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[46] + ZW14;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW15 = ZW15 + (Zrotr(ZW0, 7) ^ Zrotr(ZW0, 18) ^ (ZW0 >> 3U)) + ZW8 + (Zrotr(ZW13, 17) ^ Zrotr(ZW13, 19) ^ (ZW13 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[47] + ZW15;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW0 = ZW0 + (Zrotr(ZW1, 7) ^ Zrotr(ZW1, 18) ^ (ZW1 >> 3U)) + ZW9 + (Zrotr(ZW14, 17) ^ Zrotr(ZW14, 19) ^ (ZW14 >> 10U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[48] + ZW0;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW1 = ZW1 + (Zrotr(ZW2, 7) ^ Zrotr(ZW2, 18) ^ (ZW2 >> 3U)) + ZW10 + (Zrotr(ZW15, 17) ^ Zrotr(ZW15, 19) ^ (ZW15 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[49] + ZW1;
    ZC = ZC + ZG;
    ZG = ZG + (Zrotr(ZH, 2) ^ Zrotr(ZH, 13) ^ Zrotr(ZH, 22)) + Ma(ZB, ZH, ZA);
    ZW2 = ZW2 + (Zrotr(ZW3, 7) ^ Zrotr(ZW3, 18) ^ (ZW3 >> 3U)) + ZW11 + (Zrotr(ZW0, 17) ^ Zrotr(ZW0, 19) ^ (ZW0 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[50] + ZW2;
    ZB = ZB + ZF;
    ZF = ZF + (Zrotr(ZG, 2) ^ Zrotr(ZG, 13) ^ Zrotr(ZG, 22)) + Ma(ZA, ZG, ZH);
    ZW3 = ZW3 + (Zrotr(ZW4, 7) ^ Zrotr(ZW4, 18) ^ (ZW4 >> 3U)) + ZW12 + (Zrotr(ZW1, 17) ^ Zrotr(ZW1, 19) ^ (ZW1 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[51] + ZW3;
    ZA = ZA + ZE;
    ZE = ZE + (Zrotr(ZF, 2) ^ Zrotr(ZF, 13) ^ Zrotr(ZF, 22)) + Ma(ZH, ZF, ZG);
    ZW4 = ZW4 + (Zrotr(ZW5, 7) ^ Zrotr(ZW5, 18) ^ (ZW5 >> 3U)) + ZW13 + (Zrotr(ZW2, 17) ^ Zrotr(ZW2, 19) ^ (ZW2 >> 10U));
    ZD = ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[52] + ZW4;
    ZH = ZH + ZD;
    ZD = ZD + (Zrotr(ZE, 2) ^ Zrotr(ZE, 13) ^ Zrotr(ZE, 22)) + Ma(ZG, ZE, ZF);
    ZW5 = ZW5 + (Zrotr(ZW6, 7) ^ Zrotr(ZW6, 18) ^ (ZW6 >> 3U)) + ZW14 + (Zrotr(ZW3, 17) ^ Zrotr(ZW3, 19) ^ (ZW3 >> 10U));
    ZC = ZC + (Zrotr(ZH, 6) ^ Zrotr(ZH, 11) ^ Zrotr(ZH, 25)) + Ch(ZH, ZA, ZB) + K[53] + ZW5;
    ZG = ZG + ZC;
    ZC = ZC + (Zrotr(ZD, 2) ^ Zrotr(ZD, 13) ^ Zrotr(ZD, 22)) + Ma(ZF, ZD, ZE);
    ZW6 = ZW6 + (Zrotr(ZW7, 7) ^ Zrotr(ZW7, 18) ^ (ZW7 >> 3U)) + ZW15 + (Zrotr(ZW4, 17) ^ Zrotr(ZW4, 19) ^ (ZW4 >> 10U));
    ZB = ZB + (Zrotr(ZG, 6) ^ Zrotr(ZG, 11) ^ Zrotr(ZG, 25)) + Ch(ZG, ZH, ZA) + K[54] + ZW6;
    ZF = ZF + ZB;
    ZB = ZB + (Zrotr(ZC, 2) ^ Zrotr(ZC, 13) ^ Zrotr(ZC, 22)) + Ma(ZE, ZC, ZD);
    ZW7 = ZW7 + (Zrotr(ZW8, 7) ^ Zrotr(ZW8, 18) ^ (ZW8 >> 3U)) + ZW0 + (Zrotr(ZW5, 17) ^ Zrotr(ZW5, 19) ^ (ZW5 >> 10U));
    ZA = ZA + (Zrotr(ZF, 6) ^ Zrotr(ZF, 11) ^ Zrotr(ZF, 25)) + Ch(ZF, ZG, ZH) + K[55] + ZW7;
    ZE = ZE + ZA;
    ZA = ZA + (Zrotr(ZB, 2) ^ Zrotr(ZB, 13) ^ Zrotr(ZB, 22)) + Ma(ZD, ZB, ZC);
    ZW8 = ZW8 + (Zrotr(ZW9, 7) ^ Zrotr(ZW9, 18) ^ (ZW9 >> 3U)) + ZW1 + (Zrotr(ZW6, 17) ^ Zrotr(ZW6, 19) ^ (ZW6 >> 10U));
    ZH = ZH + (Zrotr(ZE, 6) ^ Zrotr(ZE, 11) ^ Zrotr(ZE, 25)) + Ch(ZE, ZF, ZG) + K[56] + ZW8;
    ZD = ZD + ZH;
    ZH = ZH + (Zrotr(ZA, 2) ^ Zrotr(ZA, 13) ^ Zrotr(ZA, 22)) + Ma(ZC, ZA, ZB);
    ZW9 = ZW9 + (Zrotr(ZW10, 7) ^ Zrotr(ZW10, 18) ^ (ZW10 >> 3U)) + ZW2 + (Zrotr(ZW7, 17) ^ Zrotr(ZW7, 19) ^ (ZW7 >> 10U));
    ZG = ZG + (Zrotr(ZD, 6) ^ Zrotr(ZD, 11) ^ Zrotr(ZD, 25)) + Ch(ZD, ZE, ZF) + K[57] + ZW9;
    ZC = ZC + ZG;
    ZW10 = ZW10 + (Zrotr(ZW11, 7) ^ Zrotr(ZW11, 18) ^ (ZW11 >> 3U)) + ZW3 + (Zrotr(ZW8, 17) ^ Zrotr(ZW8, 19) ^ (ZW8 >> 10U));
    ZF = ZF + (Zrotr(ZC, 6) ^ Zrotr(ZC, 11) ^ Zrotr(ZC, 25)) + Ch(ZC, ZD, ZE) + K[58] + ZW10;
    ZB = ZB + ZF;
    ZW11 = ZW11 + (Zrotr(ZW12, 7) ^ Zrotr(ZW12, 18) ^ (ZW12 >> 3U)) + ZW4 + (Zrotr(ZW9, 17) ^ Zrotr(ZW9, 19) ^ (ZW9 >> 10U));
    ZE = ZE + (Zrotr(ZB, 6) ^ Zrotr(ZB, 11) ^ Zrotr(ZB, 25)) + Ch(ZB, ZC, ZD) + K[59] + ZW11;
    ZA = ZA + ZE;
    ZW12 = ZW12 + (Zrotr(ZW13, 7) ^ Zrotr(ZW13, 18) ^ (ZW13 >> 3U)) + ZW5 + (Zrotr(ZW10, 17) ^ Zrotr(ZW10, 19) ^ (ZW10 >> 10U));
    ZH = ZH + ZD + (Zrotr(ZA, 6) ^ Zrotr(ZA, 11) ^ Zrotr(ZA, 25)) + Ch(ZA, ZB, ZC) + K[60] + ZW12;

    ZH += 0x5be0cd19U;

    if(ZH == 0) { output[Znonce & 0xFF] = Znonce; }
#ifdef DOLOOPS
  }
#endif
}
