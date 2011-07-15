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

#define ZR25(n) ((Zrotr(ZW[(n)], 25) ^ Zrotr(ZW[(n)], 14) ^ ((ZW[(n)]) >> 3U)))
#define ZR25C(n) ((Zrotr((n), 25) ^ Zrotr((n), 14) ^ ((n) >> 3U)))
#define ZR15(n) ((Zrotr(ZW[(n)], 15) ^ Zrotr(ZW[(n)], 13) ^ ((ZW[(n)]) >> 10U)))
#define ZR26(n) ((Zrotr(ZV[(n)], 26) ^ Zrotr(ZV[(n)], 21) ^ Zrotr(ZV[(n)], 7)))
#define ZR30(n) ((Zrotr(ZV[(n)], 30) ^ Zrotr(ZV[(n)], 19) ^ Zrotr(ZV[(n)], 10))) 

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
  z ZW[106];
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
    ZV[4] = PreVal4_plus_T1 + Znonce;

    ZW[18] = W18 + ZR25C(Znonce);
    ZW[19] = W19 + Znonce;
    ZW[20] = 0x80000000U + ZR15(18);
    ZW[21] = ZR15(19);
    ZW[22] = 0x00000280U + ZR15(20);
    ZW[23] = ZR15(21) + W16;
    ZW[24] = ZR15(22) + W17;
    ZW[25] = ZR15(23) + ZW[18];
    ZW[26] = ZR15(24) + ZW[19];
    ZW[27] = ZR15(25) + ZW[20];
    ZW[28] = ZR15(26) + ZW[21];
    ZW[29] = ZR15(27) + ZW[22];
    ZW[30] = 0x00A00055U + ZR15(28) + ZW[23];
    ZW[31] = W31 + ZR15(29) + ZW[24];
    ZW[32] = W32 + ZR15(30) + ZW[25];

    Zt1 = d1 + Ch(ZV[0], b1, c1) + ZR26(0);
    ZV[7] = h1 + Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(f1, g1, ZV[4]);
    Zt1 = c1 + K[5] + Ch(ZV[7], ZV[0], b1) + ZR26(7);
    ZV[6] = g1 + Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], f1, ZV[3]);
    Zt1 = b1 + K[6] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] = f1 + Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    Zt1 = ZV[0] + K[7] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    Zt1 = ZV[7] + K[8] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    Zt1 = ZV[6] + K[9] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    Zt1 = ZV[5] + K[10] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    Zt1 = ZV[4] + K[11] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    Zt1 = ZV[3] + K[12] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    Zt1 = ZV[2] + K[13] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    Zt1 = ZV[1] + K[14] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    Zt1 = ZV[0] + K[15] + 0x00000280U + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    Zt1 = ZV[7] + K[16] + W16 + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    Zt1 = ZV[6] + K[17] + W17 + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    Zt1 = ZV[5] + K[18] + ZW[18] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    Zt1 = ZV[4] + K[19] + ZW[19] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    Zt1 = ZV[3] + K[20] + ZW[20] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    Zt1 = ZV[2] + K[21] + ZW[21] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    Zt1 = ZV[1] + K[22] + ZW[22] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    Zt1 = ZV[0] + K[23] + ZW[23] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    Zt1 = ZV[7] + K[24] + ZW[24] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    Zt1 = ZV[6] + K[25] + ZW[25] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    Zt1 = ZV[5] + K[26] + ZW[26] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    Zt1 = ZV[4] + K[27] + ZW[27] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    Zt1 = ZV[3] + K[28] + ZW[28] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    Zt1 = ZV[2] + K[29] + ZW[29] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    Zt1 = ZV[1] + K[30] + ZW[30] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    Zt1 = ZV[0] + K[31] + ZW[31] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    Zt1 = ZV[7] + K[32] + ZW[32] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    ZW[33] = ZR15(31) + ZR25(18) + ZW[26] + W17;
    Zt1 = ZV[6] + K[33] + ZW[33] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    ZW[34] = ZR15(32) + ZR25(19) + ZW[27] + ZW[18];
    Zt1 = ZV[5] + K[34] + ZW[34] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    ZW[35] = ZR15(33) + ZR25(20) + ZW[28] + ZW[19];
    Zt1 = ZV[4] + K[35] + ZW[35] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    ZW[36] = ZR15(34) + ZR25(21) + ZW[29] + ZW[20];
    Zt1 = ZV[3] + K[36] + ZW[36] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[37] = ZR15(35) + ZR25(22) + ZW[30] + ZW[21];
    Zt1 = ZV[2] + K[37] + ZW[37] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    ZW[38] = ZR15(36) + ZR25(23) + ZW[31] + ZW[22];
    Zt1 = ZV[1] + K[38] + ZW[38] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    ZW[39] = ZR15(37) + ZR25(24) + ZW[32] + ZW[23];
    Zt1 = ZV[0] + K[39] + ZW[39] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    ZW[40] = ZR15(38) + ZR25(25) + ZW[33] + ZW[24];
    Zt1 = ZV[7] + K[40] + ZW[40] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    ZW[41] = ZR15(39) + ZR25(26) + ZW[34] + ZW[25];
    Zt1 = ZV[6] + K[41] + ZW[41] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    ZW[42] = ZR15(40) + ZR25(27) + ZW[35] + ZW[26];
    Zt1 = ZV[5] + K[42] + ZW[42] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    ZW[43] = ZR15(41) + ZR25(28) + ZW[36] + ZW[27];
    Zt1 = ZV[4] + K[43] + ZW[43] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    ZW[44] = ZR15(42) + ZR25(29) + ZW[37] + ZW[28];
    Zt1 = ZV[3] + K[44] + ZW[44] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[45] = ZR15(43) + ZR25(30) + ZW[38] + ZW[29];
    Zt1 = ZV[2] + K[45] + ZW[45] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    ZW[46] = ZR15(44) + ZR25(31) + ZW[39] + ZW[30];
    Zt1 = ZV[1] + K[46] + ZW[46] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    ZW[47] = ZR15(45) + ZW[40] + ZR25(32) + ZW[31];
    Zt1 = ZV[0] + K[47] + ZW[47] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    ZW[48] = ZR15(46) + ZW[41] + ZR25(33) + ZW[32];
    Zt1 = ZV[7] + K[48] + ZW[48] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    ZW[49] = ZR15(47) + ZW[42] + ZR25(34) + ZW[33];
    Zt1 = ZV[6] + K[49] + ZW[49] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    ZW[50] = ZR15(48) + ZW[43] + ZR25(35) + ZW[34];
    Zt1 = ZV[5] + K[50] + ZW[50] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    ZW[51] = ZR15(49) + ZW[44] + ZR25(36) + ZW[35];
    Zt1 = ZV[4] + K[51] + ZW[51] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    ZW[52] = ZR15(50) + ZW[45] + ZR25(37) + ZW[36];
    Zt1 = ZV[3] + K[52] + ZW[52] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[53] = ZR15(51) + ZW[46] + ZR25(38) + ZW[37];
    Zt1 = ZV[2] + K[53] + ZW[53] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    ZW[54] = ZR15(52) + ZW[47] + ZR25(39) + ZW[38];
    Zt1 = ZV[1] + K[54] + ZW[54] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    ZW[55] = ZR15(53) + ZW[48] + ZR25(40) + ZW[39];
    Zt1 = ZV[0] + K[55] + ZW[55] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    ZW[56] = ZR15(54) + ZW[49] + ZR25(41) + ZW[40];
    Zt1 = ZV[7] + K[56] + ZW[56] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    ZW[57] = ZR15(55) + ZW[50] + ZR25(42) + ZW[41];
    Zt1 = ZV[6] + K[57] + ZW[57] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    ZW[58] = ZR15(56) + ZW[51] + ZR25(43) + ZW[42];
    Zt1 = ZV[5] + K[58] + ZW[58] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    ZW[59] = ZR15(57) + ZW[52] + ZR25(44) + ZW[43];
    Zt1 = ZV[4] + K[59] + ZW[59] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    ZW[60] = ZR15(58) + ZW[53] + ZR25(45) + ZW[44];
    Zt1 = ZV[3] + K[60] + ZW[60] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[61] = ZR15(59) + ZW[54] + ZR25(46) + ZW[45];
    Zt1 = ZV[2] + K[61] + ZW[61] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    ZW[62] = ZR15(60) + ZR25(47) + ZW[55] + ZW[46];
    Zt1 = ZV[1] + K[62] + ZW[62] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    ZW[63] = ZR15(61) + ZR25(48) + ZW[56] + ZW[47];
    Zt1 = ZV[0] + K[63] + ZW[63] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);

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

    ZW[80] = ZR25(65) + ZW[64];

    Zt1 = ZV[6] + K[1] + ZW[65] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    Zt1 = ZV[5] + K[2] + ZW[66] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    ZW[81] = (Zrotr(0x00000100U, 15) ^ Zrotr(0x00000100U, 13) ^ ((0x00000100U) >> 10U)) + ZR25(66) + ZW[65];
    ZW[82] = ZR15(80) + ZR25(67) + ZW[66];
    Zt1 = ZV[4] + K[3] + ZW[67] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    ZW[83] = ZR15(81) + ZR25(68) + ZW[67];
    Zt1 = ZV[3] + K[4] + ZW[68] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[84] = ZR15(82) + ZR25(69) + ZW[68];
    Zt1 = ZV[2] + K[5] + ZW[69] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    ZW[85] = ZR15(83) + ZR25(70) + ZW[69];
    Zt1 = ZV[1] + K[6] + ZW[70] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    ZW[86] = ZR15(84) + 0x00000100U + ZR25(71) + ZW[70];
    Zt1 = ZV[0] + K[7] + ZW[71] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    Zt1 = (ZV[7] + K[8] + 0x80000000U + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4));
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    ZW[87] = ZR15(85) + ZW[80] + ZR25C(0x80000000U) + ZW[71];
    ZW[88] = ZR15(86) + ZW[81] + 0x80000000U;
    Zt1 = ZV[6] + K[9] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    Zt1 = ZV[5] + K[10] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    ZW[89] = ZR15(87) + ZW[82];
    ZW[90] = ZR15(88) + ZW[83];
    Zt1 = ZV[4] + K[11] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    Zt1 = ZV[3] + K[12] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[91] = ZR15(89) + ZW[84];
    ZW[92] = ZR15(90) + ZW[85];
    Zt1 = ZV[2] + K[13] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    Zt1 = ZV[1] + K[14] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    Zt1 = ZV[0] + K[15] + 0x00000100U + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    Zt1 = ZV[7] + K[16] + ZW[80] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    Zt1 = ZV[6] + K[17] + ZW[81] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    Zt1 = ZV[5] + K[18] + ZW[82] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    Zt1 = ZV[4] + K[19] + ZW[83] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    Zt1 = ZV[3] + K[20] + ZW[84] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    Zt1 = ZV[2] + K[21] + ZW[85] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    Zt1 = ZV[1] + K[22] + ZW[86] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    Zt1 = ZV[0] + K[23] + ZW[87] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    Zt1 = ZV[7] + K[24] + ZW[88] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    Zt1 = ZV[6] + K[25] + ZW[89] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    Zt1 = ZV[5] + K[26] + ZW[90] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    Zt1 = ZV[4] + K[27] + ZW[91] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    Zt1 = ZV[3] + K[28] + ZW[92] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[93] = ZR15(91) + ZW[86];
    Zt1 = ZV[2] + K[29] + ZW[93] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    ZW[94] = ZR15(92) + ZR25C(0x00000100U) + ZW[87];
    Zt1 = ZV[1] + K[30] + ZW[94] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    ZW[95] = ZR15(93) + ZR25(80) + ZW[88] + 0x00000100U;
    Zt1 = ZV[0] + K[31] + ZW[95] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    ZW[96] = ZR15(94) + ZR25(81) + ZW[89] + ZW[80];
    Zt1 = ZV[7] + K[32] + ZW[96] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    ZW[97] = ZR15(95) + ZR25(82) + ZW[90] + ZW[81];
    Zt1 = ZV[6] + K[33] + ZW[97] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    ZW[98] = ZR15(96) + ZR25(83) + ZW[91] + ZW[82];
    Zt1 = ZV[5] + K[34] + ZW[98] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    ZW[99] = ZR15(97) + ZR25(84) + ZW[92] + ZW[83];
    Zt1 = ZV[4] + K[35] + ZW[99] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    ZW[100] = ZR15(98) + ZR25(85) + ZW[93] + ZW[84];
    Zt1 = ZV[3] + K[36] + ZW[100] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[101] = ZR15(99) + ZR25(86) + ZW[94] + ZW[85];
    Zt1 = ZV[2] + K[37] + ZW[101] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    ZW[102] = ZR15(100) + ZR25(87) + ZW[95] + ZW[86];
    Zt1 = ZV[1] + K[38] + ZW[102] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    ZW[103] = ZR15(101) + ZR25(88) + ZW[96] + ZW[87];
    Zt1 = ZV[0] + K[39] + ZW[103] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    ZW[104] = ZR15(102) + ZR25(89) + ZW[97] + ZW[88];
    Zt1 = ZV[7] + K[40] + ZW[104] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    ZW[105] = ZR15(103) + ZR25(90) + ZW[98] + ZW[89];
    Zt1 = ZV[6] + K[41] + ZW[105] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    ZW[17] = ZR15(104) + ZR25(91) + ZW[99] + ZW[90];
    Zt1 = ZV[5] + K[42] + ZW[17] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    ZW[16] = ZR15(105) + ZR25(92) + ZW[100] + ZW[91];
    Zt1 = ZV[4] + K[43] + ZW[16] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    ZW[15] = ZR15(17) + ZR25(93) + ZW[101] + ZW[92];
    Zt1 = ZV[3] + K[44] + ZW[15] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[14] = ZR15(16) + ZR25(94) + ZW[102] + ZW[93];
    Zt1 = ZV[2] + K[45] + ZW[14] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    ZW[13] = ZR15(15) + ZR25(95) + ZW[103] + ZW[94];
    Zt1 = ZV[1] + K[46] + ZW[13] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    ZW[12] = ZR15(14) + ZR25(96) + ZW[104] + ZW[95];
    Zt1 = ZV[0] + K[47] + ZW[12] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    ZW[11] = ZR15(13) + ZR25(97) + ZW[105] + ZW[96];
    Zt1 = ZV[7] + K[48] + ZW[11] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    ZW[10] = ZR15(12) + ZR25(98) + ZW[17] + ZW[97];
    Zt1 = ZV[6] + K[49] + ZW[10] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZV[2] += Zt1;
    ZV[6] = Zt1 + ZR30(7) + Ma(ZV[0], ZV[1], ZV[7]);
    ZW[9] = ZR15(11) + ZW[16] + ZR25(99) + ZW[98];
    Zt1 = ZV[5] + K[50] + ZW[9] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[1] += Zt1;
    ZV[5] = Zt1 + ZR30(6) + Ma(ZV[7], ZV[0], ZV[6]);
    ZW[8] = ZR15(10) + ZW[15] + ZR25(100) + ZW[99];
    Zt1 = ZV[4] + K[51] + ZW[8] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[0] += Zt1;
    ZV[4] = Zt1 + ZR30(5) + Ma(ZV[6], ZV[7], ZV[5]);
    ZW[6] = ZR15(9) + ZW[14] + ZR25(101) + ZW[100];
    Zt1 = ZV[3] + K[52] + ZW[6] + Ch(ZV[0], ZV[1], ZV[2]) + ZR26(0);
    ZV[7] += Zt1;
    ZV[3] = Zt1 + ZR30(4) + Ma(ZV[5], ZV[6], ZV[4]);
    ZW[7] = ZR15(8) + ZW[13] + ZR25(102) + ZW[101];
    Zt1 = ZV[2] + K[53] + ZW[7] + Ch(ZV[7], ZV[0], ZV[1]) + ZR26(7);
    ZV[6] += Zt1;
    ZV[2] = Zt1 + ZR30(3) + Ma(ZV[4], ZV[5], ZV[3]);
    ZW[4] = ZR15(6) + ZW[12] + ZR25(103) + ZW[102];
    Zt1 = ZV[1] + K[54] + ZW[4] + Ch(ZV[6], ZV[7], ZV[0]) + ZR26(6);
    ZV[5] += Zt1;
    ZV[1] = Zt1 + ZR30(2) + Ma(ZV[3], ZV[4], ZV[2]);
    ZW[3] = ZR15(7) + ZW[11] + ZR25(104) + ZW[103];
    Zt1 = ZV[0] + K[55] + ZW[3] + Ch(ZV[5], ZV[6], ZV[7]) + ZR26(5);
    ZV[4] += Zt1;
    ZV[0] = Zt1 + ZR30(1) + Ma(ZV[2], ZV[3], ZV[1]);
    ZW[2] = ZR15(4) + ZR25(105) + ZW[10] + ZW[104];
    Zt1 = ZV[7] + K[56] + ZW[2] + Ch(ZV[4], ZV[5], ZV[6]) + ZR26(4);
    ZV[3] += Zt1;
    ZV[7] = Zt1 + ZR30(0) + Ma(ZV[1], ZV[2], ZV[0]);
    ZW[1] = ZR15(3) + ZR25(17) + ZW[9] + ZW[105];
    ZV[2] += ZV[6] + K[57] + ZW[1] + Ch(ZV[3], ZV[4], ZV[5]) + ZR26(3);
    ZW[0] = ZR15(2) + ZR25(16) + ZW[8] + ZW[17];
    ZV[1] += ZV[5] + K[58] + ZW[0] + Ch(ZV[2], ZV[3], ZV[4]) + ZR26(2);
    ZV[0] += ZV[4] + K[59] + ZR15(1) + ZR25(15) + ZW[6] + ZW[16] + Ch(ZV[1], ZV[2], ZV[3]) + ZR26(1);
    ZV[7] += ZV[3] + ZR26(0) + Ch(ZV[0], ZV[1], ZV[2]) + ZR15(0) + ZW[7] + ZR25(14) + ZW[15];

    if(ZV[7] == 0x136032ED) { output[Znonce & 0xF] = Znonce; }
#ifdef DOLOOPS
  }
#endif
}
