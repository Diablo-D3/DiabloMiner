/*
 *  DiabloMiner - OpenCL miner for BitCoin
 *  Copyright (C) 2010, 2011 Patrick McFarland <diablod3@gmail.com>
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
#define Ch(a, b, c) amd_bytealign(a, b, c)
#define Ma(a, b, c) amd_bytealign((c ^ a), (b), (a))
#else
#define Zrotr(a, b) rotate((z)a, (z)b)
#define Ch(a, b, c) (c ^ (a & (b ^ c)))
#define Ma(a, b, c) ((b & c) | (a & (b | c)))
#endif

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
    __global uint * output)
{
  z ZV[8];
  z ZW[128];
  z Zt1;

  z Znonce = base + get_global_id(0);

  #ifdef DOLOOPS
  Znonce *= (z)LOOPS;

  uint it;
  const z Zloopnonce = Znonce;
  for(it = LOOPS; it != 0; it--) {
    Znonce = (LOOPS - it) ^ Zloopnonce;
  #endif

    ZV[0] = PreVal4_plus_state0 + Znonce;
    ZV[1] = b1;
    ZV[2] = c1;
    ZV[3] = d1;
    ZV[4] = PreVal4_plus_T1 + Znonce;
    ZV[5] = f1;
    ZV[6] = g1;
    ZV[7] = h1;

    ZW[16] = W16;
    ZW[17] = W17;

    ZW[18] = W18 + (Zrotr(Znonce, 25) ^ Zrotr(Znonce, 14) ^ ((Znonce) >> 3U));
    ZW[19] = W19 + Znonce;
    ZW[20] = 0x80000000U + (Zrotr(ZW[18], 15) ^ Zrotr(ZW[18], 13) ^ ((ZW[18]) >> 10U));
    ZW[21] = (Zrotr(ZW[19], 15) ^ Zrotr(ZW[19], 13) ^ ((ZW[19]) >> 10U));
    ZW[22] = 0x00000280U + (Zrotr(ZW[20], 15) ^ Zrotr(ZW[20], 13) ^ ((ZW[20]) >> 10U));
    ZW[23] = ZW[16] + (Zrotr(ZW[21], 15) ^ Zrotr(ZW[21], 13) ^ ((ZW[21]) >> 10U));
    ZW[24] = (Zrotr(ZW[22], 15) ^ Zrotr(ZW[22], 13) ^ ((ZW[22]) >> 10U)) + ZW[17];
    ZW[25] = (Zrotr(ZW[23], 15) ^ Zrotr(ZW[23], 13) ^ ((ZW[23]) >> 10U)) + ZW[18];
    ZW[26] = (Zrotr(ZW[24], 15) ^ Zrotr(ZW[24], 13) ^ ((ZW[24]) >> 10U)) + ZW[19];
    ZW[27] = (Zrotr(ZW[25], 15) ^ Zrotr(ZW[25], 13) ^ ((ZW[25]) >> 10U)) + ZW[20];
    ZW[28] = (Zrotr(ZW[26], 15) ^ Zrotr(ZW[26], 13) ^ ((ZW[26]) >> 10U)) + ZW[21];
    ZW[29] = (Zrotr(ZW[27], 15) ^ Zrotr(ZW[27], 13) ^ ((ZW[27]) >> 10U)) + ZW[22];
    ZW[30] = 0x00A00055U + (Zrotr(ZW[28], 15) ^ Zrotr(ZW[28], 13) ^ ((ZW[28]) >> 10U)) + ZW[23];
    ZW[31] = W31 + (Zrotr(ZW[29], 15) ^ Zrotr(ZW[29], 13) ^ ((ZW[29]) >> 10U)) + ZW[24];
    ZW[32] = W32 + (Zrotr(ZW[30], 15) ^ Zrotr(ZW[30], 13) ^ ((ZW[30]) >> 10U)) + ZW[25];

    Zt1 = (ZV[3] + K[4] + 0x80000000U + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    Zt1 = (ZV[2] + K[5] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    Zt1 = (ZV[1] + K[6] + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    Zt1 = (ZV[0] + K[7] + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    Zt1 = (ZV[7] + K[8] + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    Zt1 = (ZV[6] + K[9] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    Zt1 = (ZV[5] + K[10] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    Zt1 = (ZV[4] + K[11] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    Zt1 = (ZV[3] + K[12] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    Zt1 = (ZV[2] + K[13] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    Zt1 = (ZV[1] + K[14] + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    Zt1 = (ZV[0] + K[15] + 0x00000280U + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    Zt1 = (ZV[7] + K[16] + ZW[16] + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    Zt1 = (ZV[6] + K[17] + ZW[17] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    Zt1 = (ZV[5] + K[18] + ZW[18] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    Zt1 = (ZV[4] + K[19] + ZW[19] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    Zt1 = (ZV[3] + K[20] + ZW[20] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    Zt1 = (ZV[2] + K[21] + ZW[21] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    Zt1 = (ZV[1] + K[22] + ZW[22] + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    Zt1 = (ZV[0] + K[23] + ZW[23] + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    Zt1 = (ZV[7] + K[24] + ZW[24] + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    Zt1 = (ZV[6] + K[25] + ZW[25] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    Zt1 = (ZV[5] + K[26] + ZW[26] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    Zt1 = (ZV[4] + K[27] + ZW[27] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    Zt1 = (ZV[3] + K[28] + ZW[28] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    Zt1 = (ZV[2] + K[29] + ZW[29] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    Zt1 = (ZV[1] + K[30] + ZW[30] + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    Zt1 = (ZV[0] + K[31] + ZW[31] + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    Zt1 = (ZV[7] + K[32] + ZW[32] + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    ZV[2] += (ZV[6] + K[33] + (ZW[33] = (Zrotr(ZW[31], 15) ^ Zrotr(ZW[31], 13) ^ ((ZW[31]) >> 10U)) + (Zrotr(ZW[18], 25) ^ Zrotr(ZW[18], 14) ^ ((ZW[18]) >> 3U)) + ZW[26] + ZW[17]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[6] = (ZV[6] + K[33] + (ZW[33] = (Zrotr(ZW[31], 15) ^ Zrotr(ZW[31], 13) ^ ((ZW[31]) >> 10U)) + (Zrotr(ZW[18], 25) ^ Zrotr(ZW[18], 14) ^ ((ZW[18]) >> 3U)) + ZW[26] + ZW[17]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7))) + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    ZV[1] += (ZV[5] + K[34] + (ZW[34] = (Zrotr(ZW[32], 15) ^ Zrotr(ZW[32], 13) ^ ((ZW[32]) >> 10U)) + (Zrotr(ZW[19], 25) ^ Zrotr(ZW[19], 14) ^ ((ZW[19]) >> 3U)) + ZW[27] + ZW[18]) + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[5] = (ZV[5] + K[34] + (ZW[34] = (Zrotr(ZW[32], 15) ^ Zrotr(ZW[32], 13) ^ ((ZW[32]) >> 10U)) + (Zrotr(ZW[19], 25) ^ Zrotr(ZW[19], 14) ^ ((ZW[19]) >> 3U)) + ZW[27] + ZW[18]) + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7))) + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    ZV[0] += (ZV[4] + K[35] + (ZW[35] = (Zrotr(ZW[33], 15) ^ Zrotr(ZW[33], 13) ^ ((ZW[33]) >> 10U)) + (Zrotr(ZW[20], 25) ^ Zrotr(ZW[20], 14) ^ ((ZW[20]) >> 3U)) + ZW[28] + ZW[19]) + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[4] = (ZV[4] + K[35] + (ZW[35] = (Zrotr(ZW[33], 15) ^ Zrotr(ZW[33], 13) ^ ((ZW[33]) >> 10U)) + (Zrotr(ZW[20], 25) ^ Zrotr(ZW[20], 14) ^ ((ZW[20]) >> 3U)) + ZW[28] + ZW[19]) + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7))) + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    ZV[7] += (ZV[3] + K[36] + (ZW[36] = (Zrotr(ZW[34], 15) ^ Zrotr(ZW[34], 13) ^ ((ZW[34]) >> 10U)) + (Zrotr(ZW[21], 25) ^ Zrotr(ZW[21], 14) ^ ((ZW[21]) >> 3U)) + ZW[29] + ZW[20]) + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[3] = (ZV[3] + K[36] + (ZW[36] = (Zrotr(ZW[34], 15) ^ Zrotr(ZW[34], 13) ^ ((ZW[34]) >> 10U)) + (Zrotr(ZW[21], 25) ^ Zrotr(ZW[21], 14) ^ ((ZW[21]) >> 3U)) + ZW[29] + ZW[20]) + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7))) + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    ZV[6] += (ZV[2] + K[37] + (ZW[37] = (Zrotr(ZW[35], 15) ^ Zrotr(ZW[35], 13) ^ ((ZW[35]) >> 10U)) + (Zrotr(ZW[22], 25) ^ Zrotr(ZW[22], 14) ^ ((ZW[22]) >> 3U)) + ZW[30] + ZW[21]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[2] = (ZV[2] + K[37] + (ZW[37] = (Zrotr(ZW[35], 15) ^ Zrotr(ZW[35], 13) ^ ((ZW[35]) >> 10U)) + (Zrotr(ZW[22], 25) ^ Zrotr(ZW[22], 14) ^ ((ZW[22]) >> 3U)) + ZW[30] + ZW[21]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7))) + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    ZV[5] += (ZV[1] + K[38] + (ZW[38] = (Zrotr(ZW[36], 15) ^ Zrotr(ZW[36], 13) ^ ((ZW[36]) >> 10U)) + (Zrotr(ZW[23], 25) ^ Zrotr(ZW[23], 14) ^ ((ZW[23]) >> 3U)) + ZW[31] + ZW[22]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[1] = (ZV[1] + K[38] + (ZW[38] = (Zrotr(ZW[36], 15) ^ Zrotr(ZW[36], 13) ^ ((ZW[36]) >> 10U)) + (Zrotr(ZW[23], 25) ^ Zrotr(ZW[23], 14) ^ ((ZW[23]) >> 3U)) + ZW[31] + ZW[22]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7))) + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    ZV[4] += (ZV[0] + K[39] + (ZW[39] = (Zrotr(ZW[37], 15) ^ Zrotr(ZW[37], 13) ^ ((ZW[37]) >> 10U)) + (Zrotr(ZW[24], 25) ^ Zrotr(ZW[24], 14) ^ ((ZW[24]) >> 3U)) + ZW[32] + ZW[23]) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[0] = (ZV[0] + K[39] + (ZW[39] = (Zrotr(ZW[37], 15) ^ Zrotr(ZW[37], 13) ^ ((ZW[37]) >> 10U)) + (Zrotr(ZW[24], 25) ^ Zrotr(ZW[24], 14) ^ ((ZW[24]) >> 3U)) + ZW[32] + ZW[23]) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7))) + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    ZV[3] += (ZV[7] + K[40] + (ZW[40] = (Zrotr(ZW[38], 15) ^ Zrotr(ZW[38], 13) ^ ((ZW[38]) >> 10U)) + (Zrotr(ZW[25], 25) ^ Zrotr(ZW[25], 14) ^ ((ZW[25]) >> 3U)) + ZW[33] + ZW[24]) + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[7] = (ZV[7] + K[40] + (ZW[40] = (Zrotr(ZW[38], 15) ^ Zrotr(ZW[38], 13) ^ ((ZW[38]) >> 10U)) + (Zrotr(ZW[25], 25) ^ Zrotr(ZW[25], 14) ^ ((ZW[25]) >> 3U)) + ZW[33] + ZW[24]) + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7))) + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    ZV[2] += (ZV[6] + K[41] + (ZW[41] = (Zrotr(ZW[39], 15) ^ Zrotr(ZW[39], 13) ^ ((ZW[39]) >> 10U)) + (Zrotr(ZW[26], 25) ^ Zrotr(ZW[26], 14) ^ ((ZW[26]) >> 3U)) + ZW[34] + ZW[25]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[6] = (ZV[6] + K[41] + (ZW[41] = (Zrotr(ZW[39], 15) ^ Zrotr(ZW[39], 13) ^ ((ZW[39]) >> 10U)) + (Zrotr(ZW[26], 25) ^ Zrotr(ZW[26], 14) ^ ((ZW[26]) >> 3U)) + ZW[34] + ZW[25]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7))) + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    ZV[1] += (ZV[5] + K[42] + (ZW[42] = (Zrotr(ZW[40], 15) ^ Zrotr(ZW[40], 13) ^ ((ZW[40]) >> 10U)) + (Zrotr(ZW[27], 25) ^ Zrotr(ZW[27], 14) ^ ((ZW[27]) >> 3U)) + ZW[35] + ZW[26]) + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[5] = (ZV[5] + K[42] + (ZW[42] = (Zrotr(ZW[40], 15) ^ Zrotr(ZW[40], 13) ^ ((ZW[40]) >> 10U)) + (Zrotr(ZW[27], 25) ^ Zrotr(ZW[27], 14) ^ ((ZW[27]) >> 3U)) + ZW[35] + ZW[26]) + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7))) + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    ZV[0] += (ZV[4] + K[43] + (ZW[43] = (Zrotr(ZW[41], 15) ^ Zrotr(ZW[41], 13) ^ ((ZW[41]) >> 10U)) + (Zrotr(ZW[28], 25) ^ Zrotr(ZW[28], 14) ^ ((ZW[28]) >> 3U)) + ZW[36] + ZW[27]) + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[4] = (ZV[4] + K[43] + (ZW[43] = (Zrotr(ZW[41], 15) ^ Zrotr(ZW[41], 13) ^ ((ZW[41]) >> 10U)) + (Zrotr(ZW[28], 25) ^ Zrotr(ZW[28], 14) ^ ((ZW[28]) >> 3U)) + ZW[36] + ZW[27]) + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7))) + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    ZV[7] += (ZV[3] + K[44] + (ZW[44] = (Zrotr(ZW[42], 15) ^ Zrotr(ZW[42], 13) ^ ((ZW[42]) >> 10U)) + (Zrotr(ZW[29], 25) ^ Zrotr(ZW[29], 14) ^ ((ZW[29]) >> 3U)) + ZW[37] + ZW[28]) + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[3] = (ZV[3] + K[44] + (ZW[44] = (Zrotr(ZW[42], 15) ^ Zrotr(ZW[42], 13) ^ ((ZW[42]) >> 10U)) + (Zrotr(ZW[29], 25) ^ Zrotr(ZW[29], 14) ^ ((ZW[29]) >> 3U)) + ZW[37] + ZW[28]) + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7))) + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    ZV[6] += (ZV[2] + K[45] + (ZW[45] = (Zrotr(ZW[43], 15) ^ Zrotr(ZW[43], 13) ^ ((ZW[43]) >> 10U)) + (Zrotr(ZW[30], 25) ^ Zrotr(ZW[30], 14) ^ ((ZW[30]) >> 3U)) + ZW[38] + ZW[29]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[2] = (ZV[2] + K[45] + (ZW[45] = (Zrotr(ZW[43], 15) ^ Zrotr(ZW[43], 13) ^ ((ZW[43]) >> 10U)) + (Zrotr(ZW[30], 25) ^ Zrotr(ZW[30], 14) ^ ((ZW[30]) >> 3U)) + ZW[38] + ZW[29]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7))) + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    ZV[5] += (ZV[1] + K[46] + (ZW[46] = (Zrotr(ZW[44], 15) ^ Zrotr(ZW[44], 13) ^ ((ZW[44]) >> 10U)) + (Zrotr(ZW[31], 25) ^ Zrotr(ZW[31], 14) ^ ((ZW[31]) >> 3U)) + ZW[39] + ZW[30]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[1] = (ZV[1] + K[46] + (ZW[46] = (Zrotr(ZW[44], 15) ^ Zrotr(ZW[44], 13) ^ ((ZW[44]) >> 10U)) + (Zrotr(ZW[31], 25) ^ Zrotr(ZW[31], 14) ^ ((ZW[31]) >> 3U)) + ZW[39] + ZW[30]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7))) + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    (ZW[47] = (Zrotr(ZW[45], 15) ^ Zrotr(ZW[45], 13) ^ ((ZW[45]) >> 10U)) + ZW[40] + (Zrotr(ZW[32], 25) ^ Zrotr(ZW[32], 14) ^ ((ZW[32]) >> 3U)) + ZW[31]);
    Zt1 = (ZV[0] + K[47] + ZW[47] + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    (ZW[48] = (Zrotr(ZW[46], 15) ^ Zrotr(ZW[46], 13) ^ ((ZW[46]) >> 10U)) + ZW[41] + (Zrotr(ZW[33], 25) ^ Zrotr(ZW[33], 14) ^ ((ZW[33]) >> 3U)) + ZW[32]);
    Zt1 = (ZV[7] + K[48] + ZW[48] + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    (ZW[49] = (Zrotr(ZW[47], 15) ^ Zrotr(ZW[47], 13) ^ ((ZW[47]) >> 10U)) + ZW[42] + (Zrotr(ZW[34], 25) ^ Zrotr(ZW[34], 14) ^ ((ZW[34]) >> 3U)) + ZW[33]);
    Zt1 = (ZV[6] + K[49] + ZW[49] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    (ZW[50] = (Zrotr(ZW[48], 15) ^ Zrotr(ZW[48], 13) ^ ((ZW[48]) >> 10U)) + ZW[43] + (Zrotr(ZW[35], 25) ^ Zrotr(ZW[35], 14) ^ ((ZW[35]) >> 3U)) + ZW[34]);
    Zt1 = (ZV[5] + K[50] + ZW[50] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    (ZW[51] = (Zrotr(ZW[49], 15) ^ Zrotr(ZW[49], 13) ^ ((ZW[49]) >> 10U)) + ZW[44] + (Zrotr(ZW[36], 25) ^ Zrotr(ZW[36], 14) ^ ((ZW[36]) >> 3U)) + ZW[35]);
    Zt1 = (ZV[4] + K[51] + ZW[51] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    (ZW[52] = (Zrotr(ZW[50], 15) ^ Zrotr(ZW[50], 13) ^ ((ZW[50]) >> 10U)) + ZW[45] + (Zrotr(ZW[37], 25) ^ Zrotr(ZW[37], 14) ^ ((ZW[37]) >> 3U)) + ZW[36]);
    Zt1 = (ZV[3] + K[52] + ZW[52] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    (ZW[53] = (Zrotr(ZW[51], 15) ^ Zrotr(ZW[51], 13) ^ ((ZW[51]) >> 10U)) + ZW[46] + (Zrotr(ZW[38], 25) ^ Zrotr(ZW[38], 14) ^ ((ZW[38]) >> 3U)) + ZW[37]);
    Zt1 = (ZV[2] + K[53] + ZW[53] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    (ZW[54] = (Zrotr(ZW[52], 15) ^ Zrotr(ZW[52], 13) ^ ((ZW[52]) >> 10U)) + ZW[47] + (Zrotr(ZW[39], 25) ^ Zrotr(ZW[39], 14) ^ ((ZW[39]) >> 3U)) + ZW[38]);
    Zt1 = (ZV[1] + K[54] + ZW[54] + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    (ZW[55] = (Zrotr(ZW[53], 15) ^ Zrotr(ZW[53], 13) ^ ((ZW[53]) >> 10U)) + ZW[48] + (Zrotr(ZW[40], 25) ^ Zrotr(ZW[40], 14) ^ ((ZW[40]) >> 3U)) + ZW[39]);
    Zt1 = (ZV[0] + K[55] + ZW[55] + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    (ZW[56] = (Zrotr(ZW[54], 15) ^ Zrotr(ZW[54], 13) ^ ((ZW[54]) >> 10U)) + ZW[49] + (Zrotr(ZW[41], 25) ^ Zrotr(ZW[41], 14) ^ ((ZW[41]) >> 3U)) + ZW[40]);
    Zt1 = (ZV[7] + K[56] + ZW[56] + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    (ZW[57] = (Zrotr(ZW[55], 15) ^ Zrotr(ZW[55], 13) ^ ((ZW[55]) >> 10U)) + ZW[50] + (Zrotr(ZW[42], 25) ^ Zrotr(ZW[42], 14) ^ ((ZW[42]) >> 3U)) + ZW[41]);
    Zt1 = (ZV[6] + K[57] + ZW[57] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    (ZW[58] = (Zrotr(ZW[56], 15) ^ Zrotr(ZW[56], 13) ^ ((ZW[56]) >> 10U)) + ZW[51] + (Zrotr(ZW[43], 25) ^ Zrotr(ZW[43], 14) ^ ((ZW[43]) >> 3U)) + ZW[42]);
    Zt1 = (ZV[5] + K[58] + ZW[58] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    (ZW[59] = (Zrotr(ZW[57], 15) ^ Zrotr(ZW[57], 13) ^ ((ZW[57]) >> 10U)) + ZW[52] + (Zrotr(ZW[44], 25) ^ Zrotr(ZW[44], 14) ^ ((ZW[44]) >> 3U)) + ZW[43]);
    Zt1 = (ZV[4] + K[59] + ZW[59] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    (ZW[60] = (Zrotr(ZW[58], 15) ^ Zrotr(ZW[58], 13) ^ ((ZW[58]) >> 10U)) + ZW[53] + (Zrotr(ZW[45], 25) ^ Zrotr(ZW[45], 14) ^ ((ZW[45]) >> 3U)) + ZW[44]);
    Zt1 = (ZV[3] + K[60] + ZW[60] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    (ZW[61] = (Zrotr(ZW[59], 15) ^ Zrotr(ZW[59], 13) ^ ((ZW[59]) >> 10U)) + ZW[54] + (Zrotr(ZW[46], 25) ^ Zrotr(ZW[46], 14) ^ ((ZW[46]) >> 3U)) + ZW[45]);
    Zt1 = (ZV[2] + K[61] + ZW[61] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    ZV[5] += (ZV[1] + K[62] + (ZW[62] = (Zrotr(ZW[60], 15) ^ Zrotr(ZW[60], 13) ^ ((ZW[60]) >> 10U)) + (Zrotr(ZW[47], 25) ^ Zrotr(ZW[47], 14) ^ ((ZW[47]) >> 3U)) + ZW[55] + ZW[46]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[1] = (ZV[1] + K[62] + (ZW[62] = (Zrotr(ZW[60], 15) ^ Zrotr(ZW[60], 13) ^ ((ZW[60]) >> 10U)) + (Zrotr(ZW[47], 25) ^ Zrotr(ZW[47], 14) ^ ((ZW[47]) >> 3U)) + ZW[55] + ZW[46]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7))) + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    ZV[4] += (ZV[0] + K[63] + (ZW[63] = (Zrotr(ZW[61], 15) ^ Zrotr(ZW[61], 13) ^ ((ZW[61]) >> 10U)) + (Zrotr(ZW[48], 25) ^ Zrotr(ZW[48], 14) ^ ((ZW[48]) >> 3U)) + ZW[56] + ZW[47]) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[0] = (ZV[0] + K[63] + (ZW[63] = (Zrotr(ZW[61], 15) ^ Zrotr(ZW[61], 13) ^ ((ZW[61]) >> 10U)) + (Zrotr(ZW[48], 25) ^ Zrotr(ZW[48], 14) ^ ((ZW[48]) >> 3U)) + ZW[56] + ZW[47]) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7))) + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));

    ZW[64] = state0 + ZV[0];
    ZW[65] = state1 + ZV[1];
    ZW[66] = state2 + ZV[2];
    ZW[67] = state3 + ZV[3];
    ZW[68] = state4 + ZV[4];
    ZW[69] = state5 + ZV[5];
    ZW[70] = state6 + ZV[6];
    ZW[71] = state7 + ZV[7];

    ZV[0] = 0x6a09e667U;
    ZV[1] = 0xbb67ae85U;
    ZV[2] = 0x3c6ef372U;
    ZV[3] = 0x98c7e2a2U + ZW[64];
    ZV[4] = 0x510e527fU;
    ZV[5] = 0x9b05688cU;
    ZV[6] = 0x1f83d9abU;
    ZV[7] = 0xfc08884dU + ZW[64];

    ZW[80] = (Zrotr(ZW[65], 25) ^ Zrotr(ZW[65], 14) ^ ((ZW[65]) >> 3U)) + ZW[64];

    Zt1 = (ZV[6] + K[1] + ZW[65] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    Zt1 = (ZV[5] + K[2] + ZW[66] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    ZW[81] = (Zrotr(0x00000100U, 15) ^ Zrotr(0x00000100U, 13) ^ ((0x00000100U) >> 10U)) + (Zrotr(ZW[66], 25) ^ Zrotr(ZW[66], 14) ^ ((ZW[66]) >> 3U)) + ZW[65];
    ZW[82] = (Zrotr(ZW[80], 15) ^ Zrotr(ZW[80], 13) ^ ((ZW[80]) >> 10U)) + (Zrotr(ZW[67], 25) ^ Zrotr(ZW[67], 14) ^ ((ZW[67]) >> 3U)) + ZW[66];
    Zt1 = (ZV[4] + K[3] + ZW[67] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    ZW[83] = (Zrotr(ZW[81], 15) ^ Zrotr(ZW[81], 13) ^ ((ZW[81]) >> 10U)) + (Zrotr(ZW[68], 25) ^ Zrotr(ZW[68], 14) ^ ((ZW[68]) >> 3U)) + ZW[67];
    Zt1 = (ZV[3] + K[4] + ZW[68] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    ZW[84] = (Zrotr(ZW[82], 15) ^ Zrotr(ZW[82], 13) ^ ((ZW[82]) >> 10U)) + (Zrotr(ZW[69], 25) ^ Zrotr(ZW[69], 14) ^ ((ZW[69]) >> 3U)) + ZW[68];
    Zt1 = (ZV[2] + K[5] + ZW[69] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    ZW[85] = (Zrotr(ZW[83], 15) ^ Zrotr(ZW[83], 13) ^ ((ZW[83]) >> 10U)) + (Zrotr(ZW[70], 25) ^ Zrotr(ZW[70], 14) ^ ((ZW[70]) >> 3U)) + ZW[69];
    Zt1 = (ZV[1] + K[6] + ZW[70] + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    (ZW[86] = (Zrotr(ZW[84], 15) ^ Zrotr(ZW[84], 13) ^ ((ZW[84]) >> 10U)) + 0x00000100U + (Zrotr(ZW[71], 25) ^ Zrotr(ZW[71], 14) ^ ((ZW[71]) >> 3U)) + ZW[70]);
    Zt1 = (ZV[0] + K[7] + ZW[71] + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    Zt1 = (ZV[7] + K[8] + 0x80000000U + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    (ZW[87] = (Zrotr(ZW[85], 15) ^ Zrotr(ZW[85], 13) ^ ((ZW[85]) >> 10U)) + ZW[80] + (Zrotr(0x80000000U, 25) ^ Zrotr(0x80000000U, 14) ^ ((0x80000000U) >> 3U)) + ZW[71]);
    ZW[88] = (Zrotr(ZW[86], 15) ^ Zrotr(ZW[86], 13) ^ ((ZW[86]) >> 10U)) + ZW[81] + 0x80000000U;
    Zt1 = (ZV[6] + K[9] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    Zt1 = (ZV[5] + K[10] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    ZW[89] = (Zrotr(ZW[87], 15) ^ Zrotr(ZW[87], 13) ^ ((ZW[87]) >> 10U)) + ZW[82];
    ZW[90] = (Zrotr(ZW[88], 15) ^ Zrotr(ZW[88], 13) ^ ((ZW[88]) >> 10U)) + ZW[83];
    Zt1 = (ZV[4] + K[11] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    Zt1 = (ZV[3] + K[12] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    ZW[91] = (Zrotr(ZW[89], 15) ^ Zrotr(ZW[89], 13) ^ ((ZW[89]) >> 10U)) + ZW[84];
    ZW[92] = (Zrotr(ZW[90], 15) ^ Zrotr(ZW[90], 13) ^ ((ZW[90]) >> 10U)) + ZW[85];
    Zt1 = (ZV[2] + K[13] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    Zt1 = (ZV[1] + K[14] + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    Zt1 = (ZV[0] + K[15] + 0x00000100U + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    Zt1 = (ZV[7] + K[16] + ZW[80] + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    Zt1 = (ZV[6] + K[17] + ZW[81] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    Zt1 = (ZV[5] + K[18] + ZW[82] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    Zt1 = (ZV[4] + K[19] + ZW[83] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    Zt1 = (ZV[3] + K[20] + ZW[84] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    Zt1 = (ZV[2] + K[21] + ZW[85] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    Zt1 = (ZV[1] + K[22] + ZW[86] + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    Zt1 = (ZV[0] + K[23] + ZW[87] + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    Zt1 = (ZV[7] + K[24] + ZW[88] + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    Zt1 = (ZV[6] + K[25] + ZW[89] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    Zt1 = (ZV[5] + K[26] + ZW[90] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    Zt1 = (ZV[4] + K[27] + ZW[91] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    Zt1 = (ZV[3] + K[28] + ZW[92] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    ZV[6] += (ZV[2] + K[29] + (ZW[93] = (Zrotr(ZW[91], 15) ^ Zrotr(ZW[91], 13) ^ ((ZW[91]) >> 10U)) + ZW[86]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[2] = (ZV[2] + K[29] + (ZW[93] = (Zrotr(ZW[91], 15) ^ Zrotr(ZW[91], 13) ^ ((ZW[91]) >> 10U)) + ZW[86]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7))) + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    ZV[5] += (ZV[1] + K[30] + (ZW[94] = (Zrotr(ZW[92], 15) ^ Zrotr(ZW[92], 13) ^ ((ZW[92]) >> 10U)) + (Zrotr(0x00000100U, 25) ^ Zrotr(0x00000100U, 14) ^ ((0x00000100U) >> 3U)) + ZW[87]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[1] = (ZV[1] + K[30] + (ZW[94] = (Zrotr(ZW[92], 15) ^ Zrotr(ZW[92], 13) ^ ((ZW[92]) >> 10U)) + (Zrotr(0x00000100U, 25) ^ Zrotr(0x00000100U, 14) ^ ((0x00000100U) >> 3U)) + ZW[87]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7))) + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    ZV[4] += (ZV[0] + K[31] + (ZW[95] = (Zrotr(ZW[93], 15) ^ Zrotr(ZW[93], 13) ^ ((ZW[93]) >> 10U)) + (Zrotr(ZW[80], 25) ^ Zrotr(ZW[80], 14) ^ ((ZW[80]) >> 3U)) + ZW[88] + 0x00000100U) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[0] = (ZV[0] + K[31] + (ZW[95] = (Zrotr(ZW[93], 15) ^ Zrotr(ZW[93], 13) ^ ((ZW[93]) >> 10U)) + (Zrotr(ZW[80], 25) ^ Zrotr(ZW[80], 14) ^ ((ZW[80]) >> 3U)) + ZW[88] + 0x00000100U) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7))) + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    ZV[3] += (ZV[7] + K[32] + (ZW[96] = (Zrotr(ZW[94], 15) ^ Zrotr(ZW[94], 13) ^ ((ZW[94]) >> 10U)) + (Zrotr(ZW[81], 25) ^ Zrotr(ZW[81], 14) ^ ((ZW[81]) >> 3U)) + ZW[89] + ZW[80]) + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[7] = (ZV[7] + K[32] + (ZW[96] = (Zrotr(ZW[94], 15) ^ Zrotr(ZW[94], 13) ^ ((ZW[94]) >> 10U)) + (Zrotr(ZW[81], 25) ^ Zrotr(ZW[81], 14) ^ ((ZW[81]) >> 3U)) + ZW[89] + ZW[80]) + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7))) + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    ZV[2] += (ZV[6] + K[33] + (ZW[97] = (Zrotr(ZW[95], 15) ^ Zrotr(ZW[95], 13) ^ ((ZW[95]) >> 10U)) + (Zrotr(ZW[82], 25) ^ Zrotr(ZW[82], 14) ^ ((ZW[82]) >> 3U)) + ZW[90] + ZW[81]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[6] = (ZV[6] + K[33] + (ZW[97] = (Zrotr(ZW[95], 15) ^ Zrotr(ZW[95], 13) ^ ((ZW[95]) >> 10U)) + (Zrotr(ZW[82], 25) ^ Zrotr(ZW[82], 14) ^ ((ZW[82]) >> 3U)) + ZW[90] + ZW[81]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7))) + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    ZV[1] += (ZV[5] + K[34] + (ZW[98] = (Zrotr(ZW[96], 15) ^ Zrotr(ZW[96], 13) ^ ((ZW[96]) >> 10U)) + (Zrotr(ZW[83], 25) ^ Zrotr(ZW[83], 14) ^ ((ZW[83]) >> 3U)) + ZW[91] + ZW[82]) + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[5] = (ZV[5] + K[34] + (ZW[98] = (Zrotr(ZW[96], 15) ^ Zrotr(ZW[96], 13) ^ ((ZW[96]) >> 10U)) + (Zrotr(ZW[83], 25) ^ Zrotr(ZW[83], 14) ^ ((ZW[83]) >> 3U)) + ZW[91] + ZW[82]) + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7))) + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    ZV[0] += (ZV[4] + K[35] + (ZW[99] = (Zrotr(ZW[97], 15) ^ Zrotr(ZW[97], 13) ^ ((ZW[97]) >> 10U)) + (Zrotr(ZW[84], 25) ^ Zrotr(ZW[84], 14) ^ ((ZW[84]) >> 3U)) + ZW[92] + ZW[83]) + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[4] = (ZV[4] + K[35] + (ZW[99] = (Zrotr(ZW[97], 15) ^ Zrotr(ZW[97], 13) ^ ((ZW[97]) >> 10U)) + (Zrotr(ZW[84], 25) ^ Zrotr(ZW[84], 14) ^ ((ZW[84]) >> 3U)) + ZW[92] + ZW[83]) + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7))) + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    ZV[7] += (ZV[3] + K[36] + (ZW[100] = (Zrotr(ZW[98], 15) ^ Zrotr(ZW[98], 13) ^ ((ZW[98]) >> 10U)) + (Zrotr(ZW[85], 25) ^ Zrotr(ZW[85], 14) ^ ((ZW[85]) >> 3U)) + ZW[93] + ZW[84]) + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[3] = (ZV[3] + K[36] + (ZW[100] = (Zrotr(ZW[98], 15) ^ Zrotr(ZW[98], 13) ^ ((ZW[98]) >> 10U)) + (Zrotr(ZW[85], 25) ^ Zrotr(ZW[85], 14) ^ ((ZW[85]) >> 3U)) + ZW[93] + ZW[84]) + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7))) + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    ZV[6] += (ZV[2] + K[37] + (ZW[101] = (Zrotr(ZW[99], 15) ^ Zrotr(ZW[99], 13) ^ ((ZW[99]) >> 10U)) + (Zrotr(ZW[86], 25) ^ Zrotr(ZW[86], 14) ^ ((ZW[86]) >> 3U)) + ZW[94] + ZW[85]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[2] = (ZV[2] + K[37] + (ZW[101] = (Zrotr(ZW[99], 15) ^ Zrotr(ZW[99], 13) ^ ((ZW[99]) >> 10U)) + (Zrotr(ZW[86], 25) ^ Zrotr(ZW[86], 14) ^ ((ZW[86]) >> 3U)) + ZW[94] + ZW[85]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7))) + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    ZV[5] += (ZV[1] + K[38] + (ZW[102] = (Zrotr(ZW[100], 15) ^ Zrotr(ZW[100], 13) ^ ((ZW[100]) >> 10U)) + (Zrotr(ZW[87], 25) ^ Zrotr(ZW[87], 14) ^ ((ZW[87]) >> 3U)) + ZW[95] + ZW[86]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[1] = (ZV[1] + K[38] + (ZW[102] = (Zrotr(ZW[100], 15) ^ Zrotr(ZW[100], 13) ^ ((ZW[100]) >> 10U)) + (Zrotr(ZW[87], 25) ^ Zrotr(ZW[87], 14) ^ ((ZW[87]) >> 3U)) + ZW[95] + ZW[86]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7))) + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    ZV[4] += (ZV[0] + K[39] + (ZW[103] = (Zrotr(ZW[101], 15) ^ Zrotr(ZW[101], 13) ^ ((ZW[101]) >> 10U)) + (Zrotr(ZW[88], 25) ^ Zrotr(ZW[88], 14) ^ ((ZW[88]) >> 3U)) + ZW[96] + ZW[87]) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[0] = (ZV[0] + K[39] + (ZW[103] = (Zrotr(ZW[101], 15) ^ Zrotr(ZW[101], 13) ^ ((ZW[101]) >> 10U)) + (Zrotr(ZW[88], 25) ^ Zrotr(ZW[88], 14) ^ ((ZW[88]) >> 3U)) + ZW[96] + ZW[87]) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7))) + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    ZV[3] += (ZV[7] + K[40] + (ZW[104] = (Zrotr(ZW[102], 15) ^ Zrotr(ZW[102], 13) ^ ((ZW[102]) >> 10U)) + (Zrotr(ZW[89], 25) ^ Zrotr(ZW[89], 14) ^ ((ZW[89]) >> 3U)) + ZW[97] + ZW[88]) + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[7] = (ZV[7] + K[40] + (ZW[104] = (Zrotr(ZW[102], 15) ^ Zrotr(ZW[102], 13) ^ ((ZW[102]) >> 10U)) + (Zrotr(ZW[89], 25) ^ Zrotr(ZW[89], 14) ^ ((ZW[89]) >> 3U)) + ZW[97] + ZW[88]) + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7))) + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    ZV[2] += (ZV[6] + K[41] + (ZW[105] = (Zrotr(ZW[103], 15) ^ Zrotr(ZW[103], 13) ^ ((ZW[103]) >> 10U)) + (Zrotr(ZW[90], 25) ^ Zrotr(ZW[90], 14) ^ ((ZW[90]) >> 3U)) + ZW[98] + ZW[89]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[6] = (ZV[6] + K[41] + (ZW[105] = (Zrotr(ZW[103], 15) ^ Zrotr(ZW[103], 13) ^ ((ZW[103]) >> 10U)) + (Zrotr(ZW[90], 25) ^ Zrotr(ZW[90], 14) ^ ((ZW[90]) >> 3U)) + ZW[98] + ZW[89]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7))) + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    ZV[1] += (ZV[5] + K[42] + (ZW[106] = (Zrotr(ZW[104], 15) ^ Zrotr(ZW[104], 13) ^ ((ZW[104]) >> 10U)) + (Zrotr(ZW[91], 25) ^ Zrotr(ZW[91], 14) ^ ((ZW[91]) >> 3U)) + ZW[99] + ZW[90]) + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[5] = (ZV[5] + K[42] + (ZW[106] = (Zrotr(ZW[104], 15) ^ Zrotr(ZW[104], 13) ^ ((ZW[104]) >> 10U)) + (Zrotr(ZW[91], 25) ^ Zrotr(ZW[91], 14) ^ ((ZW[91]) >> 3U)) + ZW[99] + ZW[90]) + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7))) + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    ZV[0] += (ZV[4] + K[43] + (ZW[107] = (Zrotr(ZW[105], 15) ^ Zrotr(ZW[105], 13) ^ ((ZW[105]) >> 10U)) + (Zrotr(ZW[92], 25) ^ Zrotr(ZW[92], 14) ^ ((ZW[92]) >> 3U)) + ZW[100] + ZW[91]) + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[4] = (ZV[4] + K[43] + (ZW[107] = (Zrotr(ZW[105], 15) ^ Zrotr(ZW[105], 13) ^ ((ZW[105]) >> 10U)) + (Zrotr(ZW[92], 25) ^ Zrotr(ZW[92], 14) ^ ((ZW[92]) >> 3U)) + ZW[100] + ZW[91]) + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7))) + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    ZV[7] += (ZV[3] + K[44] + (ZW[108] = (Zrotr(ZW[106], 15) ^ Zrotr(ZW[106], 13) ^ ((ZW[106]) >> 10U)) + (Zrotr(ZW[93], 25) ^ Zrotr(ZW[93], 14) ^ ((ZW[93]) >> 3U)) + ZW[101] + ZW[92]) + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[3] = (ZV[3] + K[44] + (ZW[108] = (Zrotr(ZW[106], 15) ^ Zrotr(ZW[106], 13) ^ ((ZW[106]) >> 10U)) + (Zrotr(ZW[93], 25) ^ Zrotr(ZW[93], 14) ^ ((ZW[93]) >> 3U)) + ZW[101] + ZW[92]) + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7))) + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    ZV[6] += (ZV[2] + K[45] + (ZW[109] = (Zrotr(ZW[107], 15) ^ Zrotr(ZW[107], 13) ^ ((ZW[107]) >> 10U)) + (Zrotr(ZW[94], 25) ^ Zrotr(ZW[94], 14) ^ ((ZW[94]) >> 3U)) + ZW[102] + ZW[93]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[2] = (ZV[2] + K[45] + (ZW[109] = (Zrotr(ZW[107], 15) ^ Zrotr(ZW[107], 13) ^ ((ZW[107]) >> 10U)) + (Zrotr(ZW[94], 25) ^ Zrotr(ZW[94], 14) ^ ((ZW[94]) >> 3U)) + ZW[102] + ZW[93]) + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7))) + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    ZV[5] += (ZV[1] + K[46] + (ZW[110] = (Zrotr(ZW[108], 15) ^ Zrotr(ZW[108], 13) ^ ((ZW[108]) >> 10U)) + (Zrotr(ZW[95], 25) ^ Zrotr(ZW[95], 14) ^ ((ZW[95]) >> 3U)) + ZW[103] + ZW[94]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[1] = (ZV[1] + K[46] + (ZW[110] = (Zrotr(ZW[108], 15) ^ Zrotr(ZW[108], 13) ^ ((ZW[108]) >> 10U)) + (Zrotr(ZW[95], 25) ^ Zrotr(ZW[95], 14) ^ ((ZW[95]) >> 3U)) + ZW[103] + ZW[94]) + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7))) + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    ZV[4] += (ZV[0] + K[47] + (ZW[111] = (Zrotr(ZW[109], 15) ^ Zrotr(ZW[109], 13) ^ ((ZW[109]) >> 10U)) + (Zrotr(ZW[96], 25) ^ Zrotr(ZW[96], 14) ^ ((ZW[96]) >> 3U)) + ZW[104] + ZW[95]) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[0] = (ZV[0] + K[47] + (ZW[111] = (Zrotr(ZW[109], 15) ^ Zrotr(ZW[109], 13) ^ ((ZW[109]) >> 10U)) + (Zrotr(ZW[96], 25) ^ Zrotr(ZW[96], 14) ^ ((ZW[96]) >> 3U)) + ZW[104] + ZW[95]) + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7))) + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));
    ZV[3] += (ZV[7] + K[48] + (ZW[112] = (Zrotr(ZW[110], 15) ^ Zrotr(ZW[110], 13) ^ ((ZW[110]) >> 10U)) + (Zrotr(ZW[97], 25) ^ Zrotr(ZW[97], 14) ^ ((ZW[97]) >> 3U)) + ZW[105] + ZW[96]) + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));
    ZV[7] = (ZV[7] + K[48] + (ZW[112] = (Zrotr(ZW[110], 15) ^ Zrotr(ZW[110], 13) ^ ((ZW[110]) >> 10U)) + (Zrotr(ZW[97], 25) ^ Zrotr(ZW[97], 14) ^ ((ZW[97]) >> 3U)) + ZW[105] + ZW[96]) + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7))) + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    ZV[2] += (ZV[6] + K[49] + (ZW[113] = (Zrotr(ZW[111], 15) ^ Zrotr(ZW[111], 13) ^ ((ZW[111]) >> 10U)) + (Zrotr(ZW[98], 25) ^ Zrotr(ZW[98], 14) ^ ((ZW[98]) >> 3U)) + ZW[106] + ZW[97]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZV[6] = (ZV[6] + K[49] + (ZW[113] = (Zrotr(ZW[111], 15) ^ Zrotr(ZW[111], 13) ^ ((ZW[111]) >> 10U)) + (Zrotr(ZW[98], 25) ^ Zrotr(ZW[98], 14) ^ ((ZW[98]) >> 3U)) + ZW[106] + ZW[97]) + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7))) + ((Zrotr(ZV[7], 30) ^ Zrotr(ZV[7], 19) ^ Zrotr(ZV[7], 10)) + (Ma(ZV[0], ZV[1], ZV[7])));
    (ZW[114] = (Zrotr(ZW[112], 15) ^ Zrotr(ZW[112], 13) ^ ((ZW[112]) >> 10U)) + ZW[107] + (Zrotr(ZW[99], 25) ^ Zrotr(ZW[99], 14) ^ ((ZW[99]) >> 3U)) + ZW[98]);
    Zt1 = (ZV[5] + K[50] + ZW[114] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ((Zrotr(ZV[6], 30) ^ Zrotr(ZV[6], 19) ^ Zrotr(ZV[6], 10)) + (Ma(ZV[7], ZV[0], ZV[6])));
    (ZW[115] = (Zrotr(ZW[113], 15) ^ Zrotr(ZW[113], 13) ^ ((ZW[113]) >> 10U)) + ZW[108] + (Zrotr(ZW[100], 25) ^ Zrotr(ZW[100], 14) ^ ((ZW[100]) >> 3U)) + ZW[99]);
    Zt1 = (ZV[4] + K[51] + ZW[115] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ((Zrotr(ZV[5], 30) ^ Zrotr(ZV[5], 19) ^ Zrotr(ZV[5], 10)) + (Ma(ZV[6], ZV[7], ZV[5])));
    (ZW[116] = (Zrotr(ZW[114], 15) ^ Zrotr(ZW[114], 13) ^ ((ZW[114]) >> 10U)) + ZW[109] + (Zrotr(ZW[101], 25) ^ Zrotr(ZW[101], 14) ^ ((ZW[101]) >> 3U)) + ZW[100]);
    Zt1 = (ZV[3] + K[52] + ZW[116] + (Ch(ZV[0], ZV[1], ZV[2])) + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)));
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ((Zrotr(ZV[4], 30) ^ Zrotr(ZV[4], 19) ^ Zrotr(ZV[4], 10)) + (Ma(ZV[5], ZV[6], ZV[4])));
    (ZW[117] = (Zrotr(ZW[115], 15) ^ Zrotr(ZW[115], 13) ^ ((ZW[115]) >> 10U)) + ZW[110] + (Zrotr(ZW[102], 25) ^ Zrotr(ZW[102], 14) ^ ((ZW[102]) >> 3U)) + ZW[101]);
    Zt1 = (ZV[2] + K[53] + ZW[117] + (Ch(ZV[7], ZV[0], ZV[1])) + (Zrotr(ZV[7], 26) ^ Zrotr(ZV[7], 21) ^ Zrotr(ZV[7], 7)));
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ((Zrotr(ZV[3], 30) ^ Zrotr(ZV[3], 19) ^ Zrotr(ZV[3], 10)) + (Ma(ZV[4], ZV[5], ZV[3])));
    (ZW[118] = (Zrotr(ZW[116], 15) ^ Zrotr(ZW[116], 13) ^ ((ZW[116]) >> 10U)) + ZW[111] + (Zrotr(ZW[103], 25) ^ Zrotr(ZW[103], 14) ^ ((ZW[103]) >> 3U)) + ZW[102]);
    Zt1 = (ZV[1] + K[54] + ZW[118] + (Ch(ZV[6], ZV[7], ZV[0])) + (Zrotr(ZV[6], 26) ^ Zrotr(ZV[6], 21) ^ Zrotr(ZV[6], 7)));
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ((Zrotr(ZV[2], 30) ^ Zrotr(ZV[2], 19) ^ Zrotr(ZV[2], 10)) + (Ma(ZV[3], ZV[4], ZV[2])));
    (ZW[119] = (Zrotr(ZW[117], 15) ^ Zrotr(ZW[117], 13) ^ ((ZW[117]) >> 10U)) + ZW[112] + (Zrotr(ZW[104], 25) ^ Zrotr(ZW[104], 14) ^ ((ZW[104]) >> 3U)) + ZW[103]);
    Zt1 = (ZV[0] + K[55] + ZW[119] + (Ch(ZV[5], ZV[6], ZV[7])) + (Zrotr(ZV[5], 26) ^ Zrotr(ZV[5], 21) ^ Zrotr(ZV[5], 7)));
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ((Zrotr(ZV[1], 30) ^ Zrotr(ZV[1], 19) ^ Zrotr(ZV[1], 10)) + (Ma(ZV[2], ZV[3], ZV[1])));

    ZV[3] += (ZV[7] + K[56] + (ZW[120] = (Zrotr(ZW[118], 15) ^ Zrotr(ZW[118], 13) ^ ((ZW[118]) >> 10U)) + (Zrotr(ZW[105], 25) ^ Zrotr(ZW[105], 14) ^ ((ZW[105]) >> 3U)) + ZW[113] + ZW[104]) + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7)));

    ZW[120] = (Zrotr(ZW[118], 15) ^ Zrotr(ZW[118], 13) ^ ((ZW[118]) >> 10U)) + (Zrotr(ZW[105], 25) ^ Zrotr(ZW[105], 14) ^ ((ZW[105]) >> 3U)) + ZW[113] + ZW[104];
    ZV[7] = (ZV[7] + K[56] + ZW[120] + (Ch(ZV[4], ZV[5], ZV[6])) + (Zrotr(ZV[4], 26) ^ Zrotr(ZV[4], 21) ^ Zrotr(ZV[4], 7))) + ((Zrotr(ZV[0], 30) ^ Zrotr(ZV[0], 19) ^ Zrotr(ZV[0], 10)) + (Ma(ZV[1], ZV[2], ZV[0])));
    ZW[121] = (Zrotr(ZW[119], 15) ^ Zrotr(ZW[119], 13) ^ ((ZW[119]) >> 10U)) + (Zrotr(ZW[106], 25) ^ Zrotr(ZW[106], 14) ^ ((ZW[106]) >> 3U)) + ZW[114] + ZW[105];
    ZV[2] += (ZV[6] + K[57] + ZW[121] + (Ch(ZV[3], ZV[4], ZV[5])) + (Zrotr(ZV[3], 26) ^ Zrotr(ZV[3], 21) ^ Zrotr(ZV[3], 7)));
    ZW[121] = (Zrotr(ZW[119], 15) ^ Zrotr(ZW[119], 13) ^ ((ZW[119]) >> 10U)) + (Zrotr(ZW[106], 25) ^ Zrotr(ZW[106], 14) ^ ((ZW[106]) >> 3U)) + ZW[114] + ZW[105];

    ZW[122] = (Zrotr(ZW[120], 15) ^ Zrotr(ZW[120], 13) ^ ((ZW[120]) >> 10U)) + (Zrotr(ZW[107], 25) ^ Zrotr(ZW[107], 14) ^ ((ZW[107]) >> 3U)) + ZW[115] + ZW[106]; 
    ZV[1] += (ZV[5] + K[58] + ZW[122] + (Ch(ZV[2], ZV[3], ZV[4])) + (Zrotr(ZV[2], 26) ^ Zrotr(ZV[2], 21) ^ Zrotr(ZV[2], 7)));
    ZW[123] = (Zrotr(ZW[121], 15) ^ Zrotr(ZW[121], 13) ^ ((ZW[121]) >> 10U)) + (Zrotr(ZW[108], 25) ^ Zrotr(ZW[108], 14) ^ ((ZW[108]) >> 3U)) + ZW[116] + ZW[107];
    ZV[0] += (ZV[4] + K[59] + ZW[123] + (Ch(ZV[1], ZV[2], ZV[3])) + (Zrotr(ZV[1], 26) ^ Zrotr(ZV[1], 21) ^ Zrotr(ZV[1], 7)));
    ZV[3] += K[60] + (Zrotr(ZV[0], 26) ^ Zrotr(ZV[0], 21) ^ Zrotr(ZV[0], 7)) + (Ch(ZV[0], ZV[1], ZV[2]));
    ZW[124] = (Zrotr(ZW[122], 15) ^ Zrotr(ZW[122], 13) ^ ((ZW[122]) >> 10U)) + ZW[117] + (Zrotr(ZW[109], 25) ^ Zrotr(ZW[109], 14) ^ ((ZW[109]) >> 3U)) + ZW[108];    
    ZV[3] = ZV[3] + ZW[124];
    ZV[7] += ZV[3];

    if(ZV[7] == 0xA41F32E7) { output[Znonce & 0xF] = Znonce; }
#ifdef DOLOOPS
  }
#endif
}
