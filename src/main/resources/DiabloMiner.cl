/*
 *  DiabloMiner - OpenCL miner for BitCoin
 *  Copyright (C) 2010, 2011, 2012 Patrick McFarland <diablod3@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

typedef uint z;

#if BITALIGN
#pragma OPENCL EXTENSION cl_amd_media_ops : enable
#define Zrotr(a, b) amd_bitalign((z)a, (z)a, (z)(32 - b))
#else
#define Zrotr(a, b) rotate((z)a, (z)b)
#endif

#if BFIINT
#define ZCh(a, b, c) amd_bytealign(a, b, c)
#define ZMa(a, b, c) amd_bytealign((c ^ a), (b), (a))
#else
#define ZCh(a, b, c) bitselect((z)c, (z)b, (z)a)
#define ZMa(a, b, c) bitselect((z)a, (z)b, (z)c ^ (z)a)
#endif

#define ZR25(n) ((Zrotr((n), 25) ^ Zrotr((n), 14) ^ ((n) >> 3U)))
#define ZR15(n) ((Zrotr((n), 15) ^ Zrotr((n), 13) ^ ((n) >> 10U)))
#define ZR26(n) ((Zrotr((n), 26) ^ Zrotr((n), 21) ^ Zrotr((n), 7)))
#define ZR30(n) ((Zrotr((n), 30) ^ Zrotr((n), 19) ^ Zrotr((n), 10)))

__constant uint K[64] = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

__constant uint C[24] = {
  0x80000000, 0x00000100, 0x00000280, 0x00A00055,
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0x98c7e2a2,
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0xfc08884d,
  0x136032ED, 0x90bb1e3c, 0x50c6645b, 0x3ac42e24,
  0xc19bf3f4, 0x5807aa98, 0xc19bf274, 0x00a00000,
  0x11002000, 0x00400022, 0x00000000, 0x00000000
};

__kernel __attribute__((reqd_work_group_size(WORKSIZE, 1, 1))) void search(
    const uint state0, const uint state1, const uint state2, const uint state3,
    const uint state4, const uint state5, const uint state6, const uint state7,
    const uint b1, const uint c1, const uint d1,
    const uint f1, const uint g1, const uint h1,
    const uint base,
    const uint W16, const uint W17,
    const uint W18, const uint W19,
    const uint W31, const uint W32,
    const uint PreVal4_plus_state0, const uint PreVal4_plus_T1,
    const uint b1_plus_k6, const uint c1_plus_k5,
    __global uint * output)
{
  z ZA[4];
  z ZB[4];
  z ZC[4];
  z ZD[4];
  z ZE[4];
  z ZF[4];
  z ZG[4];
  z ZH[4];

  uint noncebase = base + get_global_id(0);

  #ifdef DOLOOPS
  noncebase *= LOOPS;
  #endif

  z Znonce = noncebase;

  #ifdef DOLOOPS
  uint i;

  z Zloopout = 0;

  for(i = 0; i < LOOPS; i++) {
  #endif
    ZA[0] = PreVal4_plus_state0 + Znonce;
    ZB[0] = PreVal4_plus_T1 + Znonce;

    ZC[0] = W18 + ZR25(Znonce);
    ZD[0] = W19 + Znonce;
    ZE[0] = C[0] + ZR15(ZC[0]);
    ZF[0] = ZR15(ZD[0]);
    ZG[0] = C[2] + ZR15(ZE[0]);
    ZH[0] = ZR15(ZF[0]) + W16;
    ZA[1] = ZR15(ZG[0]) + W17;
    ZB[1] = ZR15(ZH[0]) + ZC[0];
    ZC[1] = ZR15(ZA[1]) + ZD[0];
    ZD[1] = ZR15(ZB[1]) + ZE[0];
    ZE[1] = ZR15(ZC[1]) + ZF[0];
    ZF[1] = ZR15(ZD[1]) + ZG[0];
    ZG[1] = C[3] + ZR15(ZE[1]) + ZH[0];
    ZH[1] = W31 + ZR15(ZF[1]) + ZA[1];
    ZA[2] = W32 + ZR15(ZG[1]) + ZB[1];

    ZB[2] = d1 + ZCh(ZA[0], b1, c1) + ZR26(ZA[0]);
    ZC[2] = h1 + ZB[2];
    ZD[2] = ZB[2] + ZR30(ZB[0]) + ZMa(f1, g1, ZB[0]);
    ZE[2] = c1_plus_k5 + ZCh(ZC[2], ZA[0], b1) + ZR26(ZC[2]);
    ZF[2] = g1 + ZE[2];
    ZG[2] = ZE[2] + ZR30(ZD[2]) + ZMa(ZB[0], f1, ZD[2]);
    ZH[2] = b1_plus_k6 + ZCh(ZF[2], ZC[2], ZA[0]) + ZR26(ZF[2]);
    ZA[3] = f1 + ZH[2];
    ZB[3] = ZH[2] + ZR30(ZG[2]) + ZMa(ZD[2], ZB[0], ZG[2]);
    ZC[3] = ZA[0] + K[7] + ZCh(ZA[3], ZF[2], ZC[2]) + ZR26(ZA[3]);
    ZD[3] = ZB[0] + ZC[3];
    ZE[3] = ZC[3] + ZR30(ZB[3]) + ZMa(ZG[2], ZD[2], ZB[3]);
    ZF[3] = ZC[2] + K[8] + ZCh(ZD[3], ZA[3], ZF[2]) + ZR26(ZD[3]);
    ZG[3] = ZD[2] + ZF[3];
    ZH[3] = ZF[3] + ZR30(ZE[3]) + ZMa(ZB[3], ZG[2], ZE[3]);
    ZA[0] = ZF[2] + K[9] + ZCh(ZG[3], ZD[3], ZA[3]) + ZR26(ZG[3]);
    ZB[0] = ZG[2] + ZA[0];
    ZB[2] = ZA[0] + ZR30(ZH[3]) + ZMa(ZE[3], ZB[3], ZH[3]);
    ZC[2] = ZA[3] + K[10] + ZCh(ZB[0], ZG[3], ZD[3]) + ZR26(ZB[0]);
    ZD[2] = ZB[3] + ZC[2];
    ZE[2] = ZC[2] + ZR30(ZB[2]) + ZMa(ZH[3], ZE[3], ZB[2]);
    ZF[2] = ZD[3] + K[11] + ZCh(ZD[2], ZB[0], ZG[3]) + ZR26(ZD[2]);
    ZG[2] = ZE[3] + ZF[2];
    ZH[2] = ZF[2] + ZR30(ZE[2]) + ZMa(ZB[2], ZH[3], ZE[2]);
    ZA[3] = ZG[3] + K[12] + ZCh(ZG[2], ZD[2], ZB[0]) + ZR26(ZG[2]);
    ZB[3] = ZH[3] + ZA[3];
    ZC[3] = ZA[3] + ZR30(ZH[2]) + ZMa(ZE[2], ZB[2], ZH[2]);
    ZD[3] = ZB[0] + K[13] + ZCh(ZB[3], ZG[2], ZD[2]) + ZR26(ZB[3]);
    ZE[3] = ZB[2] + ZD[3];
    ZF[3] = ZD[3] + ZR30(ZC[3]) + ZMa(ZH[2], ZE[2], ZC[3]);
    ZG[3] = ZD[2] + K[14] + ZCh(ZE[3], ZB[3], ZG[2]) + ZR26(ZE[3]);
    ZH[3] = ZE[2] + ZG[3];
    ZA[0] = ZG[3] + ZR30(ZF[3]) + ZMa(ZC[3], ZH[2], ZF[3]);
    ZB[0] = ZG[2] + C[16] + ZCh(ZH[3], ZE[3], ZB[3]) + ZR26(ZH[3]);
    ZB[2] = ZH[2] + ZB[0];
    ZC[2] = ZB[0] + ZR30(ZA[0]) + ZMa(ZF[3], ZC[3], ZA[0]);
    ZD[2] = ZB[3] + K[16] + W16 + ZCh(ZB[2], ZH[3], ZE[3]) + ZR26(ZB[2]);
    ZE[2] = ZC[3] + ZD[2];
    ZF[2] = ZD[2] + ZR30(ZC[2]) + ZMa(ZA[0], ZF[3], ZC[2]);
    ZG[2] = ZE[3] + K[17] + W17 + ZCh(ZE[2], ZB[2], ZH[3]) + ZR26(ZE[2]);
    ZH[2] = ZF[3] + ZG[2];
    ZA[3] = ZG[2] + ZR30(ZF[2]) + ZMa(ZC[2], ZA[0], ZF[2]);
    ZB[3] = ZH[3] + K[18] + ZC[0] + ZCh(ZH[2], ZE[2], ZB[2]) + ZR26(ZH[2]);
    ZC[3] = ZA[0] + ZB[3];
    ZD[3] = ZB[3] + ZR30(ZA[3]) + ZMa(ZF[2], ZC[2], ZA[3]);
    ZE[3] = ZB[2] + K[19] + ZD[0] + ZCh(ZC[3], ZH[2], ZE[2]) + ZR26(ZC[3]);
    ZF[3] = ZC[2] + ZE[3];
    ZG[3] = ZE[3] + ZR30(ZD[3]) + ZMa(ZA[3], ZF[2], ZD[3]);
    ZH[3] = ZE[2] + K[20] + ZE[0] + ZCh(ZF[3], ZC[3], ZH[2]) + ZR26(ZF[3]);
    ZA[0] = ZF[2] + ZH[3];
    ZB[0] = ZH[3] + ZR30(ZG[3]) + ZMa(ZD[3], ZA[3], ZG[3]);
    ZB[2] = ZH[2] + K[21] + ZF[0] + ZCh(ZA[0], ZF[3], ZC[3]) + ZR26(ZA[0]);
    ZC[2] = ZA[3] + ZB[2];
    ZD[2] = ZB[2] + ZR30(ZB[0]) + ZMa(ZG[3], ZD[3], ZB[0]);
    ZE[2] = ZC[3] + K[22] + ZG[0] + ZCh(ZC[2], ZA[0], ZF[3]) + ZR26(ZC[2]);
    ZF[2] = ZD[3] + ZE[2];
    ZG[2] = ZE[2] + ZR30(ZD[2]) + ZMa(ZB[0], ZG[3], ZD[2]);
    ZH[2] = ZF[3] + K[23] + ZH[0] + ZCh(ZF[2], ZC[2], ZA[0]) + ZR26(ZF[2]);
    ZA[3] = ZG[3] + ZH[2];
    ZB[3] = ZH[2] + ZR30(ZG[2]) + ZMa(ZD[2], ZB[0], ZG[2]);
    ZC[3] = ZA[0] + K[24] + ZA[1] + ZCh(ZA[3], ZF[2], ZC[2]) + ZR26(ZA[3]);
    ZD[3] = ZB[0] + ZC[3];
    ZE[3] = ZC[3] + ZR30(ZB[3]) + ZMa(ZG[2], ZD[2], ZB[3]);
    ZF[3] = ZC[2] + K[25] + ZB[1] + ZCh(ZD[3], ZA[3], ZF[2]) + ZR26(ZD[3]);
    ZG[3] = ZD[2] + ZF[3];
    ZH[3] = ZF[3] + ZR30(ZE[3]) + ZMa(ZB[3], ZG[2], ZE[3]);
    ZA[0] = ZF[2] + K[26] + ZC[1] + ZCh(ZG[3], ZD[3], ZA[3]) + ZR26(ZG[3]);
    ZB[0] = ZG[2] + ZA[0];
    ZB[2] = ZA[0] + ZR30(ZH[3]) + ZMa(ZE[3], ZB[3], ZH[3]);
    ZC[2] = ZA[3] + K[27] + ZD[1] + ZCh(ZB[0], ZG[3], ZD[3]) + ZR26(ZB[0]);
    ZD[2] = ZB[3] + ZC[2];
    ZE[2] = ZC[2] + ZR30(ZB[2]) + ZMa(ZH[3], ZE[3], ZB[2]);
    ZF[2] = ZD[3] + K[28] + ZE[1] + ZCh(ZD[2], ZB[0], ZG[3]) + ZR26(ZD[2]);
    ZG[2] = ZE[3] + ZF[2];
    ZH[2] = ZF[2] + ZR30(ZE[2]) + ZMa(ZB[2], ZH[3], ZE[2]);
    ZA[3] = ZG[3] + K[29] + ZF[1] + ZCh(ZG[2], ZD[2], ZB[0]) + ZR26(ZG[2]);
    ZB[3] = ZH[3] + ZA[3];
    ZC[3] = ZA[3] + ZR30(ZH[2]) + ZMa(ZE[2], ZB[2], ZH[2]);
    ZD[3] = ZB[0] + K[30] + ZG[1] + ZCh(ZB[3], ZG[2], ZD[2]) + ZR26(ZB[3]);
    ZE[3] = ZB[2] + ZD[3];
    ZF[3] = ZD[3] + ZR30(ZC[3]) + ZMa(ZH[2], ZE[2], ZC[3]);
    ZG[3] = ZD[2] + K[31] + ZH[1] + ZCh(ZE[3], ZB[3], ZG[2]) + ZR26(ZE[3]);
    ZH[3] = ZE[2] + ZG[3];
    ZA[0] = ZG[3] + ZR30(ZF[3]) + ZMa(ZC[3], ZH[2], ZF[3]);
    ZB[0] = ZG[2] + K[32] + ZA[2] + ZCh(ZH[3], ZE[3], ZB[3]) + ZR26(ZH[3]);
    ZB[2] = ZH[2] + ZB[0];
    ZC[2] = ZB[0] + ZR30(ZA[0]) + ZMa(ZF[3], ZC[3], ZA[0]);
    ZD[2] = ZR15(ZH[1]) + ZR25(ZC[0]) + ZC[1] + W17;
    ZE[2] = ZB[3] + K[33] + ZD[2] + ZCh(ZB[2], ZH[3], ZE[3]) + ZR26(ZB[2]);
    ZF[2] = ZC[3] + ZE[2];
    ZG[2] = ZE[2] + ZR30(ZC[2]) + ZMa(ZA[0], ZF[3], ZC[2]);
    ZH[2] = ZR15(ZA[2]) + ZR25(ZD[0]) + ZD[1] + ZC[0];
    ZA[3] = ZE[3] + K[34] + ZH[2] + ZCh(ZF[2], ZB[2], ZH[3]) + ZR26(ZF[2]);
    ZB[3] = ZF[3] + ZA[3];
    ZC[3] = ZA[3] + ZR30(ZG[2]) + ZMa(ZC[2], ZA[0], ZG[2]);
    ZD[3] = ZR15(ZD[2]) + ZR25(ZE[0]) + ZE[1] + ZD[0];
    ZE[3] = ZH[3] + K[35] + ZD[3] + ZCh(ZB[3], ZF[2], ZB[2]) + ZR26(ZB[3]);
    ZF[3] = ZA[0] + ZE[3];
    ZG[3] = ZE[3] + ZR30(ZC[3]) + ZMa(ZG[2], ZC[2], ZC[3]);
    ZH[3] = ZR15(ZH[2]) + ZR25(ZF[0]) + ZF[1] + ZE[0];
    ZA[0] = ZB[2] + K[36] + ZH[3] + ZCh(ZF[3], ZB[3], ZF[2]) + ZR26(ZF[3]);
    ZB[0] = ZC[2] + ZA[0];
    ZC[0] = ZA[0] + ZR30(ZG[3]) + ZMa(ZC[3], ZG[2], ZG[3]);
    ZD[0] = ZR15(ZD[3]) + ZR25(ZG[0]) + ZG[1] + ZF[0];
    ZE[0] = ZF[2] + K[37] + ZD[0] + ZCh(ZB[0], ZF[3], ZB[3]) + ZR26(ZB[0]);
    ZF[0] = ZG[2] + ZE[0];
    ZB[2] = ZE[0] + ZR30(ZC[0]) + ZMa(ZG[3], ZC[3], ZC[0]);
    ZC[2] = ZR15(ZH[3]) + ZR25(ZH[0]) + ZH[1] + ZG[0];
    ZE[2] = ZB[3] + K[38] + ZC[2] + ZCh(ZF[0], ZB[0], ZF[3]) + ZR26(ZF[0]);
    ZF[2] = ZC[3] + ZE[2];
    ZG[2] = ZE[2] + ZR30(ZB[2]) + ZMa(ZC[0], ZG[3], ZB[2]);
    ZA[3] = ZR15(ZD[0]) + ZR25(ZA[1]) + ZA[2] + ZH[0];
    ZB[3] = ZF[3] + K[39] + ZA[3] + ZCh(ZF[2], ZF[0], ZB[0]) + ZR26(ZF[2]);
    ZC[3] = ZG[3] + ZB[3];
    ZE[3] = ZB[3] + ZR30(ZG[2]) + ZMa(ZB[2], ZC[0], ZG[2]);
    ZF[3] = ZR15(ZC[2]) + ZR25(ZB[1]) + ZD[2] + ZA[1];
    ZG[3] = ZB[0] + K[40] + ZF[3] + ZCh(ZC[3], ZF[2], ZF[0]) + ZR26(ZC[3]);
    ZA[0] = ZC[0] + ZG[3];
    ZB[0] = ZG[3] + ZR30(ZE[3]) + ZMa(ZG[2], ZB[2], ZE[3]);
    ZC[0] = ZR15(ZA[3]) + ZR25(ZC[1]) + ZH[2] + ZB[1];
    ZE[0] = ZF[0] + K[41] + ZC[0] + ZCh(ZA[0], ZC[3], ZF[2]) + ZR26(ZA[0]);
    ZF[0] = ZB[2] + ZE[0];
    ZG[0] = ZE[0] + ZR30(ZB[0]) + ZMa(ZE[3], ZG[2], ZB[0]);
    ZH[0] = ZR15(ZF[3]) + ZR25(ZD[1]) + ZD[3] + ZC[1];
    ZA[1] = ZF[2] + K[42] + ZH[0] + ZCh(ZF[0], ZA[0], ZC[3]) + ZR26(ZF[0]);
    ZB[1] = ZG[2] + ZA[1];
    ZC[1] = ZA[1] + ZR30(ZG[0]) + ZMa(ZB[0], ZE[3], ZG[0]);
    ZB[2] = ZR15(ZC[0]) + ZR25(ZE[1]) + ZH[3] + ZD[1];
    ZE[2] = ZC[3] + K[43] + ZB[2] + ZCh(ZB[1], ZF[0], ZA[0]) + ZR26(ZB[1]);
    ZF[2] = ZE[3] + ZE[2];
    ZG[2] = ZE[2] + ZR30(ZC[1]) + ZMa(ZG[0], ZB[0], ZC[1]);
    ZB[3] = ZR15(ZH[0]) + ZR25(ZF[1]) + ZD[0] + ZE[1];
    ZC[3] = ZA[0] + K[44] + ZB[3] + ZCh(ZF[2], ZB[1], ZF[0]) + ZR26(ZF[2]);
    ZE[3] = ZB[0] + ZC[3];
    ZG[3] = ZC[3] + ZR30(ZG[2]) + ZMa(ZC[1], ZG[0], ZG[2]);
    ZA[0] = ZR15(ZB[2]) + ZR25(ZG[1]) + ZC[2] + ZF[1];
    ZB[0] = ZF[0] + K[45] + ZA[0] + ZCh(ZE[3], ZF[2], ZB[1]) + ZR26(ZE[3]);
    ZE[0] = ZG[0] + ZB[0];
    ZF[0] = ZB[0] + ZR30(ZG[3]) + ZMa(ZG[2], ZC[1], ZG[3]);
    ZG[0] = ZR15(ZB[3]) + ZR25(ZH[1]) + ZA[3] + ZG[1];
    ZA[1] = ZB[1] + K[46] + ZG[0] + ZCh(ZE[0], ZE[3], ZF[2]) + ZR26(ZE[0]);
    ZB[1] = ZC[1] + ZA[1];
    ZC[1] = ZA[1] + ZR30(ZF[0]) + ZMa(ZG[3], ZG[2], ZF[0]);
    ZD[1] = ZR15(ZA[0]) + ZF[3] + ZR25(ZA[2]) + ZH[1];
    ZE[1] = ZF[2] + K[47] + ZD[1] + ZCh(ZB[1], ZE[0], ZE[3]) + ZR26(ZB[1]);
    ZF[1] = ZG[2] + ZE[1];
    ZG[1] = ZE[1] + ZR30(ZC[1]) + ZMa(ZF[0], ZG[3], ZC[1]);
    ZH[1] = ZR15(ZG[0]) + ZC[0] + ZR25(ZD[2]) + ZA[2];
    ZA[2] = ZE[3] + K[48] + ZH[1] + ZCh(ZF[1], ZB[1], ZE[0]) + ZR26(ZF[1]);
    ZE[2] = ZG[3] + ZA[2];
    ZF[2] = ZA[2] + ZR30(ZG[1]) + ZMa(ZC[1], ZF[0], ZG[1]);
    ZG[2] = ZR15(ZD[1]) + ZH[0] + ZR25(ZH[2]) + ZD[2];
    ZC[3] = ZE[0] + K[49] + ZG[2] + ZCh(ZE[2], ZF[1], ZB[1]) + ZR26(ZE[2]);
    ZE[3] = ZF[0] + ZC[3];
    ZG[3] = ZC[3] + ZR30(ZF[2]) + ZMa(ZG[1], ZC[1], ZF[2]);
    ZB[0] = ZR15(ZH[1]) + ZB[2] + ZR25(ZD[3]) + ZH[2];
    ZE[0] = ZB[1] + K[50] + ZB[0] + ZCh(ZE[3], ZE[2], ZF[1]) + ZR26(ZE[3]);
    ZF[0] = ZC[1] + ZE[0];
    ZA[1] = ZE[0] + ZR30(ZG[3]) + ZMa(ZF[2], ZG[1], ZG[3]);
    ZB[1] = ZR15(ZG[2]) + ZB[3] + ZR25(ZH[3]) + ZD[3];
    ZC[1] = ZF[1] + K[51] + ZB[1] + ZCh(ZF[0], ZE[3], ZE[2]) + ZR26(ZF[0]);
    ZE[1] = ZG[1] + ZC[1];
    ZF[1] = ZC[1] + ZR30(ZA[1]) + ZMa(ZG[3], ZF[2], ZA[1]);
    ZG[1] = ZR15(ZB[0]) + ZA[0] + ZR25(ZD[0]) + ZH[3];
    ZA[2] = ZE[2] + K[52] + ZG[1] + ZCh(ZE[1], ZF[0], ZE[3]) + ZR26(ZE[1]);
    ZD[2] = ZF[2] + ZA[2];
    ZE[2] = ZA[2] + ZR30(ZF[1]) + ZMa(ZA[1], ZG[3], ZF[1]);
    ZF[2] = ZR15(ZB[1]) + ZG[0] + ZR25(ZC[2]) + ZD[0];
    ZH[2] = ZE[3] + K[53] + ZF[2] + ZCh(ZD[2], ZE[1], ZF[0]) + ZR26(ZD[2]);
    ZC[3] = ZG[3] + ZH[2];
    ZD[3] = ZH[2] + ZR30(ZE[2]) + ZMa(ZF[1], ZA[1], ZE[2]);
    ZE[3] = ZR15(ZG[1]) + ZD[1] + ZR25(ZA[3]) + ZC[2];
    ZG[3] = ZF[0] + K[54] + ZE[3] + ZCh(ZC[3], ZD[2], ZE[1]) + ZR26(ZC[3]);
    ZH[3] = ZA[1] + ZG[3];
    ZD[0] = ZG[3] + ZR30(ZD[3]) + ZMa(ZE[2], ZF[1], ZD[3]);
    ZE[0] = ZR15(ZF[2]) + ZH[1] + ZR25(ZF[3]) + ZA[3];
    ZF[0] = ZE[1] + K[55] + ZE[0] + ZCh(ZH[3], ZC[3], ZD[2]) + ZR26(ZH[3]);
    ZA[1] = ZF[1] + ZF[0];
    ZC[1] = ZF[0] + ZR30(ZD[0]) + ZMa(ZD[3], ZE[2], ZD[0]);
    ZE[1] = ZR15(ZE[3]) + ZG[2] + ZR25(ZC[0]) + ZF[3];
    ZF[1] = ZD[2] + K[56] + ZE[1] + ZCh(ZA[1], ZH[3], ZC[3]) + ZR26(ZA[1]);
    ZA[2] = ZE[2] + ZF[1];
    ZC[2] = ZF[1] + ZR30(ZC[1]) + ZMa(ZD[0], ZD[3], ZC[1]);
    ZD[2] = ZR15(ZE[0]) + ZB[0] + ZR25(ZH[0]) + ZC[0];
    ZE[2] = ZC[3] + K[57] + ZD[2] + ZCh(ZA[2], ZA[1], ZH[3]) + ZR26(ZA[2]);
    ZG[2] = ZD[3] + ZE[2];
    ZH[2] = ZE[2] + ZR30(ZC[2]) + ZMa(ZC[1], ZD[0], ZC[2]);
    ZA[3] = ZR15(ZE[1]) + ZB[1] + ZR25(ZB[2]) + ZH[0];
    ZC[3] = ZH[3] + K[58] + ZA[3] + ZCh(ZG[2], ZA[2], ZA[1]) + ZR26(ZG[2]);
    ZD[3] = ZD[0] + ZC[3];
    ZF[3] = ZC[3] + ZR30(ZH[2]) + ZMa(ZC[2], ZC[1], ZH[2]);
    ZG[3] = ZR15(ZD[2]) + ZG[1] + ZR25(ZB[3]) + ZB[2];
    ZH[3] = ZA[1] + K[59] + ZG[3] + ZCh(ZD[3], ZG[2], ZA[2]) + ZR26(ZD[3]);
    ZB[0] = ZC[1] + ZH[3];
    ZC[0] = ZH[3] + ZR30(ZF[3]) + ZMa(ZH[2], ZC[2], ZF[3]);
    ZD[0] = ZR15(ZA[3]) + ZF[2] + ZR25(ZA[0]) + ZB[3];
    ZF[0] = ZA[2] + K[60] + ZD[0] + ZCh(ZB[0], ZD[3], ZG[2]) + ZR26(ZB[0]);
    ZH[0] = ZC[2] + ZF[0];
    ZA[1] = ZF[0] + ZR30(ZC[0]) + ZMa(ZF[3], ZH[2], ZC[0]);
    ZB[1] = ZR15(ZG[3]) + ZE[3] + ZR25(ZG[0]) + ZA[0];
    ZC[1] = ZG[2] + K[61] + ZB[1] + ZCh(ZH[0], ZB[0], ZD[3]) + ZR26(ZH[0]);
    ZF[1] = ZH[2] + ZC[1];
    ZG[1] = ZC[1] + ZR30(ZA[1]) + ZMa(ZC[0], ZF[3], ZA[1]);
    ZA[2] = ZR15(ZD[0]) + ZR25(ZD[1]) + ZE[0] + ZG[0];
    ZB[2] = ZD[3] + K[62] + ZA[2] + ZCh(ZF[1], ZH[0], ZB[0]) + ZR26(ZF[1]);
    ZC[2] = ZF[3] + ZB[2];
    ZD[2] = ZB[2] + ZR30(ZG[1]) + ZMa(ZA[1], ZC[0], ZG[1]);
    ZE[2] = ZR15(ZB[1]) + ZR25(ZH[1]) + ZE[1] + ZD[1];
    ZF[2] = ZB[0] + K[63] + ZE[2] + ZCh(ZC[2], ZF[1], ZH[0]) + ZR26(ZC[2]);
    ZG[2] = ZC[0] + ZF[2];
    ZH[2] = ZF[2] + ZR30(ZD[2]) + ZMa(ZG[1], ZA[1], ZD[2]);

    ZA[3] = state0 + ZH[2];
    ZB[3] = state1 + ZD[2];
    ZC[3] = state2 + ZG[1];
    ZD[3] = state3 + ZA[1];
    ZE[3] = state4 + ZG[2];
    ZF[3] = state5 + ZC[2];
    ZG[3] = state6 + ZF[1];
    ZH[3] = state7 + ZH[0];

    ZA[0] = C[4];
    ZB[0] = C[5];
    ZC[0] = C[6];
    ZD[0] = C[7] + ZA[3];
    ZE[0] = C[8];
    ZF[0] = C[9];
    ZG[0] = C[10];
    ZH[0] = C[11] + ZA[3];

    ZA[1] = ZR25(ZB[3]) + ZA[3];

    ZB[1] = C[13] + ZB[3] + ZCh(ZD[0], ZE[0], ZF[0]) + ZR26(ZD[0]);
    ZC[1] = ZC[0] + ZB[1];
    ZD[1] = ZB[1] + ZR30(ZH[0]) + ZMa(ZA[0], ZB[0], ZH[0]);
    ZE[1] = C[14] + ZC[3] + ZCh(ZC[1], ZD[0], ZE[0]) + ZR26(ZC[1]);
    ZF[1] = ZB[0] + ZE[1];
    ZG[1] = ZE[1] + ZR30(ZD[1]) + ZMa(ZH[0], ZA[0], ZD[1]);
    ZH[1] = C[19] + ZR25(ZC[3]) + ZB[3];
    ZA[2] = ZR15(ZA[1]) + ZR25(ZD[3]) + ZC[3];
    ZB[2] = C[15] + ZD[3] + ZCh(ZF[1], ZC[1], ZD[0]) + ZR26(ZF[1]);
    ZC[2] = ZA[0] + ZB[2];
    ZD[2] = ZB[2] + ZR30(ZG[1]) + ZMa(ZD[1], ZH[0], ZG[1]);
    ZE[2] = ZR15(ZH[1]) + ZR25(ZE[3]) + ZD[3];
    ZF[2] = ZD[0] + K[4] + ZE[3] + ZCh(ZC[2], ZF[1], ZC[1]) + ZR26(ZC[2]);
    ZG[2] = ZH[0] + ZF[2];
    ZH[2] = ZF[2] + ZR30(ZD[2]) + ZMa(ZG[1], ZD[1], ZD[2]);
    ZA[3] = ZR15(ZA[2]) + ZR25(ZF[3]) + ZE[3];
    ZB[3] = ZC[1] + K[5] + ZF[3] + ZCh(ZG[2], ZC[2], ZF[1]) + ZR26(ZG[2]);
    ZC[3] = ZD[1] + ZB[3];
    ZD[3] = ZB[3] + ZR30(ZH[2]) + ZMa(ZD[2], ZG[1], ZH[2]);
    ZE[3] = ZR15(ZE[2]) + ZR25(ZG[3]) + ZF[3];
    ZF[3] = ZF[1] + K[6] + ZG[3] + ZCh(ZC[3], ZG[2], ZC[2]) + ZR26(ZC[3]);
    ZA[0] = ZG[1] + ZF[3];
    ZB[0] = ZF[3] + ZR30(ZD[3]) + ZMa(ZH[2], ZD[2], ZD[3]);
    ZC[0] = ZR15(ZA[3]) + C[1] + ZR25(ZH[3]) + ZG[3];
    ZD[0] = ZC[2] + K[7] + ZH[3] + ZCh(ZA[0], ZC[3], ZG[2]) + ZR26(ZA[0]);
    ZE[0] = ZD[2] + ZD[0];
    ZF[0] = ZD[0] + ZR30(ZB[0]) + ZMa(ZD[3], ZH[2], ZB[0]);
    ZG[0] = (ZG[2] + C[17] + ZCh(ZE[0], ZA[0], ZC[3]) + ZR26(ZE[0]));
    ZH[0] = ZH[2] + ZG[0];
    ZB[1] = ZG[0] + ZR30(ZF[0]) + ZMa(ZB[0], ZD[3], ZF[0]);
    ZC[1] = ZR15(ZE[3]) + ZA[1] + C[20] + ZH[3];
    ZD[1] = ZR15(ZC[0]) + ZH[1] + C[0];
    ZE[1] = ZC[3] + K[9] + ZCh(ZH[0], ZE[0], ZA[0]) + ZR26(ZH[0]);
    ZF[1] = ZD[3] + ZE[1];
    ZG[1] = ZE[1] + ZR30(ZB[1]) + ZMa(ZF[0], ZB[0], ZB[1]);
    ZB[2] = ZA[0] + K[10] + ZCh(ZF[1], ZH[0], ZE[0]) + ZR26(ZF[1]);
    ZC[2] = ZB[0] + ZB[2];
    ZD[2] = ZB[2] + ZR30(ZG[1]) + ZMa(ZB[1], ZF[0], ZG[1]);
    ZF[2] = ZR15(ZC[1]) + ZA[2];
    ZG[2] = ZR15(ZD[1]) + ZE[2];
    ZH[2] = ZE[0] + K[11] + ZCh(ZC[2], ZF[1], ZH[0]) + ZR26(ZC[2]);
    ZB[3] = ZF[0] + ZH[2];
    ZC[3] = ZH[2] + ZR30(ZD[2]) + ZMa(ZG[1], ZB[1], ZD[2]);
    ZD[3] = ZH[0] + K[12] + ZCh(ZB[3], ZC[2], ZF[1]) + ZR26(ZB[3]);
    ZF[3] = ZB[1] + ZD[3];
    ZG[3] = ZD[3] + ZR30(ZC[3]) + ZMa(ZD[2], ZG[1], ZC[3]);
    ZH[3] = ZR15(ZF[2]) + ZA[3];
    ZA[0] = ZR15(ZG[2]) + ZE[3];
    ZB[0] = ZF[1] + K[13] + ZCh(ZF[3], ZB[3], ZC[2]) + ZR26(ZF[3]);
    ZD[0] = ZG[1] + ZB[0];
    ZE[0] = ZB[0] + ZR30(ZG[3]) + ZMa(ZC[3], ZD[2], ZG[3]);
    ZF[0] = ZC[2] + K[14] + ZCh(ZD[0], ZF[3], ZB[3]) + ZR26(ZD[0]);
    ZG[0] = ZD[2] + ZF[0];
    ZH[0] = ZF[0] + ZR30(ZE[0]) + ZMa(ZG[3], ZC[3], ZE[0]);
    ZB[1] = ZB[3] + C[18] + ZCh(ZG[0], ZD[0], ZF[3]) + ZR26(ZG[0]);
    ZE[1] = ZC[3] + ZB[1];
    ZF[1] = ZB[1] + ZR30(ZH[0]) + ZMa(ZE[0], ZG[3], ZH[0]);
    ZG[1] = ZF[3] + K[16] + ZA[1] + ZCh(ZE[1], ZG[0], ZD[0]) + ZR26(ZE[1]);
    ZB[2] = ZG[3] + ZG[1];
    ZC[2] = ZG[1] + ZR30(ZF[1]) + ZMa(ZH[0], ZE[0], ZF[1]);
    ZD[2] = ZD[0] + K[17] + ZH[1] + ZCh(ZB[2], ZE[1], ZG[0]) + ZR26(ZB[2]);
    ZH[2] = ZE[0] + ZD[2];
    ZB[3] = ZD[2] + ZR30(ZC[2]) + ZMa(ZF[1], ZH[0], ZC[2]);
    ZC[3] = ZG[0] + K[18] + ZA[2] + ZCh(ZH[2], ZB[2], ZE[1]) + ZR26(ZH[2]);
    ZD[3] = ZH[0] + ZC[3];
    ZF[3] = ZC[3] + ZR30(ZB[3]) + ZMa(ZC[2], ZF[1], ZB[3]);
    ZG[3] = ZE[1] + K[19] + ZE[2] + ZCh(ZD[3], ZH[2], ZB[2]) + ZR26(ZD[3]);
    ZB[0] = ZF[1] + ZG[3];
    ZD[0] = ZG[3] + ZR30(ZF[3]) + ZMa(ZB[3], ZC[2], ZF[3]);
    ZE[0] = ZB[2] + K[20] + ZA[3] + ZCh(ZB[0], ZD[3], ZH[2]) + ZR26(ZB[0]);
    ZF[0] = ZC[2] + ZE[0];
    ZG[0] = ZE[0] + ZR30(ZD[0]) + ZMa(ZF[3], ZB[3], ZD[0]);
    ZH[0] = ZH[2] + K[21] + ZE[3] + ZCh(ZF[0], ZB[0], ZD[3]) + ZR26(ZF[0]);
    ZB[1] = ZB[3] + ZH[0];
    ZE[1] = ZH[0] + ZR30(ZG[0]) + ZMa(ZD[0], ZF[3], ZG[0]);
    ZF[1] = ZD[3] + K[22] + ZC[0] + ZCh(ZB[1], ZF[0], ZB[0]) + ZR26(ZB[1]);
    ZG[1] = ZF[3] + ZF[1];
    ZB[2] = ZF[1] + ZR30(ZE[1]) + ZMa(ZG[0], ZD[0], ZE[1]);
    ZC[2] = ZB[0] + K[23] + ZC[1] + ZCh(ZG[1], ZB[1], ZF[0]) + ZR26(ZG[1]);
    ZD[2] = ZD[0] + ZC[2];
    ZH[2] = ZC[2] + ZR30(ZB[2]) + ZMa(ZE[1], ZG[0], ZB[2]);
    ZB[3] = ZF[0] + K[24] + ZD[1] + ZCh(ZD[2], ZG[1], ZB[1]) + ZR26(ZD[2]);
    ZC[3] = ZG[0] + ZB[3];
    ZD[3] = ZB[3] + ZR30(ZH[2]) + ZMa(ZB[2], ZE[1], ZH[2]);
    ZF[3] = ZB[1] + K[25] + ZF[2] + ZCh(ZC[3], ZD[2], ZG[1]) + ZR26(ZC[3]);
    ZG[3] = ZE[1] + ZF[3];
    ZB[0] = ZF[3] + ZR30(ZD[3]) + ZMa(ZH[2], ZB[2], ZD[3]);
    ZD[0] = ZG[1] + K[26] + ZG[2] + ZCh(ZG[3], ZC[3], ZD[2]) + ZR26(ZG[3]);
    ZE[0] = ZB[2] + ZD[0];
    ZF[0] = ZD[0] + ZR30(ZB[0]) + ZMa(ZD[3], ZH[2], ZB[0]);
    ZG[0] = ZD[2] + K[27] + ZH[3] + ZCh(ZE[0], ZG[3], ZC[3]) + ZR26(ZE[0]);
    ZH[0] = ZH[2] + ZG[0];
    ZB[1] = ZG[0] + ZR30(ZF[0]) + ZMa(ZB[0], ZD[3], ZF[0]);
    ZE[1] = ZC[3] + K[28] + ZA[0] + ZCh(ZH[0], ZE[0], ZG[3]) + ZR26(ZH[0]);
    ZF[1] = ZD[3] + ZE[1];
    ZG[1] = ZE[1] + ZR30(ZB[1]) + ZMa(ZF[0], ZB[0], ZB[1]);
    ZB[2] = ZR15(ZH[3]) + ZC[0];
    ZC[2] = ZG[3] + K[29] + ZB[2] + ZCh(ZF[1], ZH[0], ZE[0]) + ZR26(ZF[1]);
    ZD[2] = ZB[0] + ZC[2];
    ZH[2] = ZC[2] + ZR30(ZG[1]) + ZMa(ZB[1], ZF[0], ZG[1]);
    ZB[3] = ZR15(ZA[0]) + C[21] + ZC[1];
    ZC[3] = ZE[0] + K[30] + ZB[3] + ZCh(ZD[2], ZF[1], ZH[0]) + ZR26(ZD[2]);
    ZD[3] = ZF[0] + ZC[3];
    ZF[3] = ZC[3] + ZR30(ZH[2]) + ZMa(ZG[1], ZB[1], ZH[2]);
    ZG[3] = ZR15(ZB[2]) + ZR25(ZA[1]) + ZD[1] + C[1];
    ZB[0] = ZH[0] + K[31] + ZG[3] + ZCh(ZD[3], ZD[2], ZF[1]) + ZR26(ZD[3]);
    ZD[0] = ZB[1] + ZB[0];
    ZE[0] = ZB[0] + ZR30(ZF[3]) + ZMa(ZH[2], ZG[1], ZF[3]);
    ZF[0] = ZR15(ZB[3]) + ZR25(ZH[1]) + ZF[2] + ZA[1];
    ZG[0] = ZF[1] + K[32] + ZF[0] + ZCh(ZD[0], ZD[3], ZD[2]) + ZR26(ZD[0]);
    ZH[0] = ZG[1] + ZG[0];
    ZA[1] = ZG[0] + ZR30(ZE[0]) + ZMa(ZF[3], ZH[2], ZE[0]);
    ZB[1] = ZR15(ZG[3]) + ZR25(ZA[2]) + ZG[2] + ZH[1];
    ZE[1] = ZD[2] + K[33] + ZB[1] + ZCh(ZH[0], ZD[0], ZD[3]) + ZR26(ZH[0]);
    ZF[1] = ZH[2] + ZE[1];
    ZG[1] = ZE[1] + ZR30(ZA[1]) + ZMa(ZE[0], ZF[3], ZA[1]);
    ZH[1] = ZR15(ZF[0]) + ZR25(ZE[2]) + ZH[3] + ZA[2];
    ZA[2] = ZD[3] + K[34] + ZH[1] + ZCh(ZF[1], ZH[0], ZD[0]) + ZR26(ZF[1]);
    ZC[2] = ZF[3] + ZA[2];
    ZD[2] = ZA[2] + ZR30(ZG[1]) + ZMa(ZA[1], ZE[0], ZG[1]);
    ZH[2] = ZR15(ZB[1]) + ZR25(ZA[3]) + ZA[0] + ZE[2];
    ZC[3] = ZD[0] + K[35] + ZH[2] + ZCh(ZC[2], ZF[1], ZH[0]) + ZR26(ZC[2]);
    ZD[3] = ZE[0] + ZC[3];
    ZF[3] = ZC[3] + ZR30(ZD[2]) + ZMa(ZG[1], ZA[1], ZD[2]);
    ZB[0] = ZR15(ZH[1]) + ZR25(ZE[3]) + ZB[2] + ZA[3];
    ZD[0] = ZH[0] + K[36] + ZB[0] + ZCh(ZD[3], ZC[2], ZF[1]) + ZR26(ZD[3]);
    ZE[0] = ZA[1] + ZD[0];
    ZG[0] = ZD[0] + ZR30(ZF[3]) + ZMa(ZD[2], ZG[1], ZF[3]);
    ZH[0] = ZR15(ZH[2]) + ZR25(ZC[0]) + ZB[3] + ZE[3];
    ZA[1] = ZF[1] + K[37] + ZH[0] + ZCh(ZE[0], ZD[3], ZC[2]) + ZR26(ZE[0]);
    ZE[1] = ZG[1] + ZA[1];
    ZF[1] = ZA[1] + ZR30(ZG[0]) + ZMa(ZF[3], ZD[2], ZG[0]);
    ZG[1] = ZR15(ZB[0]) + ZR25(ZC[1]) + ZG[3] + ZC[0];
    ZA[2] = ZC[2] + K[38] + ZG[1] + ZCh(ZE[1], ZE[0], ZD[3]) + ZR26(ZE[1]);
    ZC[2] = ZD[2] + ZA[2];
    ZD[2] = ZA[2] + ZR30(ZF[1]) + ZMa(ZG[0], ZF[3], ZF[1]);
    ZE[2] = ZR15(ZH[0]) + ZR25(ZD[1]) + ZF[0] + ZC[1];
    ZA[3] = ZD[3] + K[39] + ZE[2] + ZCh(ZC[2], ZE[1], ZE[0]) + ZR26(ZC[2]);
    ZC[3] = ZF[3] + ZA[3];
    ZD[3] = ZA[3] + ZR30(ZD[2]) + ZMa(ZF[1], ZG[0], ZD[2]);
    ZE[3] = ZR15(ZG[1]) + ZR25(ZF[2]) + ZB[1] + ZD[1];
    ZF[3] = ZE[0] + K[40] + ZE[3] + ZCh(ZC[3], ZC[2], ZE[1]) + ZR26(ZC[3]);
    ZC[0] = ZG[0] + ZF[3];
    ZD[0] = ZF[3] + ZR30(ZD[3]) + ZMa(ZD[2], ZF[1], ZD[3]);
    ZE[0] = ZR15(ZE[2]) + ZR25(ZG[2]) + ZH[1] + ZF[2];
    ZG[0] = ZE[1] + K[41] + ZE[0] + ZCh(ZC[0], ZC[3], ZC[2]) + ZR26(ZC[0]);
    ZA[1] = ZF[1] + ZG[0];
    ZC[1] = ZG[0] + ZR30(ZD[0]) + ZMa(ZD[3], ZD[2], ZD[0]);
    ZD[1] = ZR15(ZE[3]) + ZR25(ZH[3]) + ZH[2] + ZG[2];
    ZE[1] = ZC[2] + K[42] + ZD[1] + ZCh(ZA[1], ZC[0], ZC[3]) + ZR26(ZA[1]);
    ZF[1] = ZD[2] + ZE[1];
    ZA[2] = ZE[1] + ZR30(ZC[1]) + ZMa(ZD[0], ZD[3], ZC[1]);
    ZC[2] = ZR15(ZE[0]) + ZR25(ZA[0]) + ZB[0] + ZH[3];
    ZD[2] = ZC[3] + K[43] + ZC[2] + ZCh(ZF[1], ZA[1], ZC[0]) + ZR26(ZF[1]);
    ZF[2] = ZD[3] + ZD[2];
    ZG[2] = ZD[2] + ZR30(ZA[2]) + ZMa(ZC[1], ZD[0], ZA[2]);
    ZA[3] = ZR15(ZD[1]) + ZR25(ZB[2]) + ZH[0] + ZA[0];
    ZC[3] = ZC[0] + K[44] + ZA[3] + ZCh(ZF[2], ZF[1], ZA[1]) + ZR26(ZF[2]);
    ZD[3] = ZD[0] + ZC[3];
    ZF[3] = ZC[3] + ZR30(ZG[2]) + ZMa(ZA[2], ZC[1], ZG[2]);
    ZH[3] = ZR15(ZC[2]) + ZR25(ZB[3]) + ZG[1] + ZB[2];
    ZA[0] = ZA[1] + K[45] + ZH[3] + ZCh(ZD[3], ZF[2], ZF[1]) + ZR26(ZD[3]);
    ZC[0] = ZC[1] + ZA[0];
    ZD[0] = ZA[0] + ZR30(ZF[3]) + ZMa(ZG[2], ZA[2], ZF[3]);
    ZG[0] = ZR15(ZA[3]) + ZR25(ZG[3]) + ZE[2] + ZB[3];
    ZA[1] = ZF[1] + K[46] + ZG[0] + ZCh(ZC[0], ZD[3], ZF[2]) + ZR26(ZC[0]);
    ZC[1] = ZA[2] + ZA[1];
    ZE[1] = ZA[1] + ZR30(ZD[0]) + ZMa(ZF[3], ZG[2], ZD[0]);
    ZF[1] = ZR15(ZH[3]) + ZR25(ZF[0]) + ZE[3] + ZG[3];
    ZA[2] = ZF[2] + K[47] + ZF[1] + ZCh(ZC[1], ZC[0], ZD[3]) + ZR26(ZC[1]);
    ZB[2] = ZG[2] + ZA[2];
    ZD[2] = ZA[2] + ZR30(ZE[1]) + ZMa(ZD[0], ZF[3], ZE[1]);
    ZF[2] = ZR15(ZG[0]) + ZR25(ZB[1]) + ZE[0] + ZF[0];
    ZG[2] = ZD[3] + K[48] + ZF[2] + ZCh(ZB[2], ZC[1], ZC[0]) + ZR26(ZB[2]);
    ZB[3] = ZF[3] + ZG[2];
    ZC[3] = ZG[2] + ZR30(ZD[2]) + ZMa(ZE[1], ZD[0], ZD[2]);
    ZD[3] = ZR15(ZF[1]) + ZR25(ZH[1]) + ZD[1] + ZB[1];
    ZF[3] = ZC[0] + K[49] + ZD[3] + ZCh(ZB[3], ZB[2], ZC[1]) + ZR26(ZB[3]);
    ZG[3] = ZD[0] + ZF[3];
    ZA[0] = ZF[3] + ZR30(ZC[3]) + ZMa(ZD[2], ZE[1], ZC[3]);
    ZC[0] = ZR15(ZF[2]) + ZC[2] + ZR25(ZH[2]) + ZH[1];
    ZD[0] = ZC[1] + K[50] + ZC[0] + ZCh(ZG[3], ZB[3], ZB[2]) + ZR26(ZG[3]);
    ZF[0] = ZE[1] + ZD[0];
    ZA[1] = ZD[0] + ZR30(ZA[0]) + ZMa(ZC[3], ZD[2], ZA[0]);
    ZB[1] = ZR15(ZD[3]) + ZA[3] + ZR25(ZB[0]) + ZH[2];
    ZC[1] = ZB[2] + K[51] + ZB[1] + ZCh(ZF[0], ZG[3], ZB[3]) + ZR26(ZF[0]);
    ZE[1] = ZD[2] + ZC[1];
    ZH[1] = ZC[1] + ZR30(ZA[1]) + ZMa(ZA[0], ZC[3], ZA[1]);
    ZA[2] = ZR15(ZC[0]) + ZH[3] + ZR25(ZH[0]) + ZB[0];
    ZB[2] = ZB[3] + K[52] + ZA[2] + ZCh(ZE[1], ZF[0], ZG[3]) + ZR26(ZE[1]);
    ZD[2] = ZC[3] + ZB[2];
    ZG[2] = ZB[2] + ZR30(ZH[1]) + ZMa(ZA[1], ZA[0], ZH[1]);
    ZH[2] = ZR15(ZB[1]) + ZG[0] + ZR25(ZG[1]) + ZH[0];
    ZB[3] = ZG[3] + K[53] + ZH[2] + ZCh(ZD[2], ZE[1], ZF[0]) + ZR26(ZD[2]);
    ZC[3] = ZA[0] + ZB[3];
    ZF[3] = ZB[3] + ZR30(ZG[2]) + ZMa(ZH[1], ZA[1], ZG[2]);
    ZG[3] = ZR15(ZA[2]) + ZF[1] + ZR25(ZE[2]) + ZG[1];
    ZA[0] = ZF[0] + K[54] + ZG[3] + ZCh(ZC[3], ZD[2], ZE[1]) + ZR26(ZC[3]);
    ZB[0] = ZA[1] + ZA[0];
    ZD[0] = ZA[0] + ZR30(ZF[3]) + ZMa(ZG[2], ZH[1], ZF[3]);
    ZF[0] = ZR15(ZH[2]) + ZF[2] + ZR25(ZE[3]) + ZE[2];
    ZG[0] = ZE[1] + K[55] + ZF[0] + ZCh(ZB[0], ZC[3], ZD[2]) + ZR26(ZB[0]);
    ZH[0] = ZH[1] + ZG[0];
    ZA[1] = ZG[0] + ZR30(ZD[0]) + ZMa(ZF[3], ZG[2], ZD[0]);
    ZC[1] = ZR15(ZG[3]) + ZR25(ZE[0]) + ZD[3] + ZE[3];
    ZE[1] = ZD[2] + K[56] + ZC[1] + ZCh(ZH[0], ZB[0], ZC[3]) + ZR26(ZH[0]);
    ZF[1] = ZG[2] + ZE[1];
    ZG[1] = ZE[1] + ZR30(ZA[1]) + ZMa(ZD[0], ZF[3], ZA[1]);
    ZH[1] = ZR15(ZF[0]) + ZR25(ZD[1]) + ZC[0] + ZE[0];
    ZB[2] = ZF[3] + ZC[3] + K[57] + ZH[1] + ZCh(ZF[1], ZH[0], ZB[0]) + ZR26(ZF[1]);
    ZD[2] = ZR15(ZC[1]) + ZR25(ZC[2]) + ZB[1] + ZD[1];
    ZE[2] = ZD[0] + ZB[0] + K[58] + ZD[2] + ZCh(ZB[2], ZF[1], ZH[0]) + ZR26(ZB[2]);
    ZF[2] = ZA[1] + ZH[0] + K[59] + ZR15(ZH[1]) + ZR25(ZA[3]) + ZA[2] + ZC[2] + ZCh(ZE[2], ZB[2], ZF[1]) + ZR26(ZE[2]);
    ZG[2] = ZG[1] + ZF[1] + ZR26(ZF[2]) + ZCh(ZF[2], ZE[2], ZB[2]) + ZR15(ZD[2]) + ZH[2] + ZR25(ZH[3]) + ZA[3];

    bool Zio = any(ZG[2] == (z)C[12]);

  #ifdef DOLOOPS
    Zloopout = (Zio) ? Znonce : Zloopout;

    Znonce += (z)1;
  }

  Znonce = Zloopout;

  bool Zio = any(Znonce > (z)0);
  #endif

  #ifdef VSTORE
  if(Zio) { vstorezz(Znonce, 0, output); }
  #else
  if(Zio) { output[0] = (uintzz)Znonce; }
  #endif
}

// vim: set ft=c

