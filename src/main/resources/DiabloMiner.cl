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

__constant uint H[8] = { 
   0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
};

#define Zs0(n) (Zrotr(ZV[(0 + 128 - (n)) % 8], 30) ^ Zrotr(ZV[(0 + 128 - (n)) % 8], 19) ^ Zrotr(ZV[(0 + 128 - (n)) % 8], 10))
#define Zs1(n) (Zrotr(ZV[(4 + 128 - (n)) % 8], 26) ^ Zrotr(ZV[(4 + 128 - (n)) % 8], 21) ^ Zrotr(ZV[(4 + 128 - (n)) % 8], 7))
#define Zch(n) (Ch(ZV[(4 + 128 - (n)) % 8], ZV[(5 + 128 - (n)) % 8], ZV[(6 + 128 - (n)) % 8]))
#define Zmaj(n) (Ma(ZV[(1 + 128 - (n)) % 8], ZV[(2 + 128 - (n)) % 8], ZV[(0 + 128 - (n)) % 8]))
#define Zt1(n) (ZV[(7 + 128 - (n)) % 8] + K[(n) % 64] + ZW[(n)] + Zch(n) + Zs1(n))
#define Zt1W(n) (ZV[(7 + 128 - (n)) % 8] + K[(n) % 64] + Zw(n) + Zch(n) + Zs1(n))
#define Zt2(n) (Zs0(n) + Zmaj(n))

#define Zw(n) (ZW[n] = ZP1(n) + ZP2(n) + ZP3(n) + ZP4(n))

#define ZR(x) (ZW[x] = (Zrotr(ZW[x-2], 15) ^ Zrotr(ZW[x-2], 13) ^ ((ZW[x-2])>>10U)) + ZW[x-7] + (Zrotr(ZW[x-15], 25) ^ Zrotr(ZW[x-15], 14) ^ ((ZW[x-15])>>3U)) + ZW[x-16])

#define ZR0(n) ((Zrotr(ZW[(n)],25) ^ Zrotr(ZW[(n)],14) ^ ((ZW[(n)])>>3U)))
#define ZR1(n) ((Zrotr(ZW[(n)],15) ^ Zrotr(ZW[(n)],13) ^ ((ZW[(n)])>>10U)))
#define ZP1(x) ZR1(x-2)
#define ZP2(x) ZR0(x-15)
#define ZP3(x) ZW[x-7]
#define ZP4(x) ZW[x-16]

#define Zsharound2(n) { ZV[(3 + 128 - (n)) % 8] += Zt1W(n); ZV[(7 + 128 - (n)) % 8] = Zt1W(n) + Zt2(n); }
#define Zsharound(n) { Zt1 = Zt1(n); ZV[(3 + 128 - (n)) % 8] += Zt1(n); ZV[(7 + 128 - (n)) % 8] = Zt1(n) + Zt2(n); }

#define Zpartround(n) { ZV[(7 + 128 - n) % 8] = (ZV[(7 + 128 - n) % 8]+ZW[n]); ZV[(3 + 128 - n) % 8] += ZV[(7 + 128 - n) % 8]; ZV[(7 + 128 - n) % 8] += Zt1; }

__kernel __attribute__((reqd_work_group_size(WORKSIZE, 1, 1))) void search(
    const uint state0, const uint state1, const uint state2, const uint state3,
    const uint state4, const uint state5, const uint state6, const uint state7,
    const uint b1, const uint c1, const uint d1,
    const uint f1, const uint g1, const uint h1,
    const uint base,
    const uint W2,
    const uint W16, const uint W17,
    const uint PreVal4, const uint T1,
    __global uint * output)
{
  z ZV[8];
  z ZW[128];
  z Zt1 = T1;
  
  z Znonce = base + get_global_id(0);

  #ifdef DOLOOPS
  Znonce *= (z)LOOPS;

  uint it;
  const z Zloopnonce = Znonce;
  for(it = LOOPS; it != 0; it--) {
    Znonce = (LOOPS - it) ^ Zloopnonce;
  #endif

    ZV[0] = state0;
    ZV[1] = b1;
    ZV[2] = c1;
    ZV[3] = d1;
    ZV[4] = PreVal4;
    ZV[5] = f1;
    ZV[6] = g1;
    ZV[7] = h1;

    ZW[2] = W2;
    ZW[4] = 0x80000000U;
    ZW[5] = 0x00000000U;
    ZW[6] = 0x00000000U;
    ZW[7] = 0x00000000U;
    ZW[8] = 0x00000000U;
    ZW[9] = 0x00000000U;
    ZW[10] = 0x00000000U;
    ZW[11] = 0x00000000U;
    ZW[12] = 0x00000000U;
    ZW[13] = 0x00000000U;
    ZW[14] = 0x00000000U;
    ZW[15] = 0x00000280U;
    ZW[16] = W16;
    ZW[17] = W17;

    ZW[19] = ZP1(19) + ZP2(19) + ZP3(19);
    ZW[18] = ZP1(18) + ZP3(18) + ZP4(18);
    ZW[20] = ZP2(20) + ZP3(20) + ZP4(20);

    ZW[3] = Znonce;

    ZW[31] = ZP2(31) + ZP4(31);
    ZW[18] += ZP2(18);
    Zpartround(3);
    ZW[19] += ZP4(19);
    Zsharound(4);
    ZW[20] += ZP1(20);
    Zsharound(5);
    ZW[32] = ZP2(32) + ZP4(32);
    ZW[21] = ZP1(21);
    Zsharound(6);
    ZW[22] = ZP3(22) + ZP1(22);
    ZW[23] = ZP3(23) + ZP1(23);
    Zsharound(7);
    ZW[24] = ZP1(24) + ZP3(24);
    Zsharound(8);
    ZW[25] = ZP1(25) + ZP3(25);
    Zsharound(9);
    ZW[26] = ZP1(26) + ZP3(26);
    ZW[27] = ZP1(27) + ZP3(27);
    Zsharound(10);
    Zsharound(11);
    ZW[28] = ZP1(28) + ZP3(28);
    Zsharound(12);
    ZW[29] = ZP1(29) + ZP3(29);
    ZW[30] = ZP1(30) + ZP2(30) + ZP3(30);
    Zsharound(13);
    Zsharound(14);
    ZW[31] += (ZP1(31) + ZP3(31));
    Zsharound(15);
    Zsharound(16);
    ZW[32] += (ZP1(32) + ZP3(32));
    Zsharound(17);
    Zsharound(18);
    Zsharound(19);
    Zsharound(20);
    Zsharound(21);
    Zsharound(22);
    Zsharound(23);
    Zsharound(24);
    Zsharound(25);
    Zsharound(26);
    Zsharound(27);
    Zsharound(28);
    Zsharound(29);
    Zsharound(30);
    Zsharound(31);
    Zsharound(32);
    Zsharound2(33);
    Zsharound2(34);
    Zsharound2(35);
    Zsharound2(36);
    Zsharound2(37);
    Zsharound2(38);
    Zsharound2(39);
    Zsharound2(40);
    Zsharound2(41);
    Zsharound2(42);
    Zsharound2(43);
    Zsharound2(44);
    Zsharound2(45);
    ZR(47);
    Zsharound(47);
    ZR(48);
    Zsharound(48);
    ZR(49);
    Zsharound(49);
    ZR(50);
    Zsharound(50);
    ZR(51);
    Zsharound(51);
    ZR(52);
    Zsharound(52);
    ZR(53);
    Zsharound(53);
    ZR(54);
    Zsharound(54);
    ZR(55);
    Zsharound(55);
    ZR(56);
    Zsharound(56);
    ZR(57);
    Zsharound(57);
    ZR(58);
    Zsharound(58);
    ZR(59);
    Zsharound(59);
    ZR(60);
    Zsharound(60);
    ZR(61);
    Zsharound(61);
    Zsharound2(62);
    Zsharound2(63);

    ZW[64] = state0 + ZV[0];
    ZW[65] = state1 + ZV[1];
    ZW[66] = state2 + ZV[2];
    ZW[67] = state3 + ZV[3];
    ZW[68] = state4 + ZV[4];
    ZW[69] = state5 + ZV[5];
    ZW[70] = state6 + ZV[6];
    ZW[71] = state7 + ZV[7];

    ZW[64 + 8] = 0x80000000U;
    ZW[64 + 9] = 0x00000000U;
    ZW[64 + 10] = 0x00000000U;
    ZW[64 + 11] = 0x00000000U;
    ZW[64 + 12] = 0x00000000U;
    ZW[64 + 13] = 0x00000000U;
    ZW[64 + 14] = 0x00000000U;
    ZW[64 + 15] = 0x00000100U;

    ZV[0] = H[0];
    ZV[1] = H[1];
    ZV[2] = H[2];
    ZV[3] = H[3];
    ZV[4] = H[4];
    ZV[5] = H[5];
    ZV[6] = H[6];
    ZV[7] = H[7];

    ZV[7] = 0xb0edbdd0 + K[0] +  ZW[64] + 0x08909ae5U;
    ZV[3] = 0xa54ff53a + 0xb0edbdd0 + K[0] + ZW[64];

    ZR(64 + 16);

    Zsharound(64 + 1);
    Zsharound(64 + 2);
    ZW[64 + 17] = ZP1(64 + 17) + ZP2(64 + 17) + ZP4(64 + 17);
    ZW[64 + 18] = ZP1(64 + 18) + ZP2(64 + 18) + ZP4(64 + 18);
    Zsharound(64 + 3);
    ZW[64 + 19] = ZP1(64 + 19) + ZP2(64 + 19) + ZP4(64 + 19);
    Zsharound(64 + 4);
    ZW[64 + 20] = ZP1(64 + 20) + ZP2(64 + 20) + ZP4(64 + 20);
    Zsharound(64 + 5);
    ZW[64 + 21] = ZP1(64 + 21) + ZP2(64 + 21) + ZP4(64 + 21);
    Zsharound(64 + 6);
    ZR(64 + 22);
    Zsharound(64 + 7);
    Zsharound(64 + 8);
    ZR(64 + 23);
    ZW[64 + 24] = ZP1(64 + 24) + ZP3(64 + 24) + ZP4(64 + 24);
    Zsharound(64 + 9);
    Zsharound(64 + 10);
    ZW[64 + 25] = ZP1(64 + 25) + ZP3(64 + 25);
    ZW[64 + 26] = ZP1(64 + 26) + ZP3(64 + 26);
    Zsharound(64 + 11);
    Zsharound(64 + 12);
    ZW[64 + 27] = ZP1(64 + 27) + ZP3(64 + 27);
    ZW[64 + 28] = ZP1(64 + 28) + ZP3(64 + 28);
    Zsharound(64 + 13);
    Zsharound(64 + 14);
    Zsharound(64 + 15);
    Zsharound(64 + 16);
    Zsharound(64 + 17);
    Zsharound(64 + 18);
    Zsharound(64 + 19);
    Zsharound(64 + 20);
    Zsharound(64 + 21);
    Zsharound(64 + 22);
    Zsharound(64 + 23);
    Zsharound(64 + 24);
    Zsharound(64 + 25);
    Zsharound(64 + 26);
    Zsharound(64 + 27);
    Zsharound(64 + 28);
    Zsharound2(64 + 29);
    Zsharound2(64 + 30);
    Zsharound2(64 + 31);
    Zsharound2(64 + 32);
    Zsharound2(64 + 33);
    Zsharound2(64 + 34);
    Zsharound2(64 + 35);
    Zsharound2(64 + 36);
    Zsharound2(64 + 37);
    Zsharound2(64 + 38);
    Zsharound2(64 + 39);
    Zsharound2(64 + 40);
    Zsharound2(64 + 41);
    Zsharound2(64 + 42);
    Zsharound2(64 + 43);
    Zsharound2(64 + 44);
    Zsharound2(64 + 45);
    Zsharound2(64 + 46);
    Zsharound2(64 + 47);
    Zsharound2(64 + 48);
    Zsharound2(64 + 49);
    ZR(64 + 50);
    Zsharound(64 + 50);
    ZR(64 + 51);
    Zsharound(64 + 51);
    ZR(64 + 52);
    Zsharound(64 + 52);
    ZR(64 + 53);
    Zsharound(64 + 53);
    ZR(64 + 54);
    Zsharound(64 + 54);
    ZR(64 + 55);
    Zsharound(64 + 55);
    Zsharound2(64 + 56);
    Zsharound2(64 + 57);
    Zsharound2(64 + 58);
    Zsharound2(64 + 59);
    
    ZV[3] += K[60] + Zs1(124) + Zch(124);
    ZR(64+60);
    Zpartround(64 + 60);
    ZV[7] += H[7];

    if(ZV[7] == 0x136032ED) { output[Znonce & 0xF] = Znonce; }
#ifdef DOLOOPS
  }
#endif
}
