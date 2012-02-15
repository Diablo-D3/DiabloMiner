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

__kernel __attribute__((reqd_work_group_size(WORKSIZE, 1, 1))) void search(
    const uint base,
    const uint PreVal4_state0, const uint PreVal4_state0_k7,
    const uint PreVal4_T1,
    const uint W18, const uint W19,
    const uint W16, const uint W17,
    const uint W16_plus_K16, const uint W17_plus_K17,
    const uint W31, const uint W32,
    const uint d1, const uint b1, const uint c1,
    const uint h1, const uint f1, const uint g1,
    const uint c1_plus_k5, const uint b1_plus_k6,
    const uint state0, const uint state1, const uint state2, const uint state3,
    const uint state4, const uint state5, const uint state6, const uint state7,
    __global uint * output)
{
  z ZQ[1024];

  #ifdef USEBASE
  uint noncebase = base + get_global_id(0);
  #else
  uint noncebase = get_global_id(0);
  #endif

  #ifdef DOLOOPS
  noncebase *= LOOPS;
  #endif

  z Znonce = noncebase;
  uintzz nonce = (uintzz)0;

  #ifdef DOLOOPS
  uintzz loopout = 0;

  for(int i = 0; i < LOOPS; i++) {
  #endif
    ZQ[15] = Znonce + PreVal4_state0;

    ZQ[16] = (ZCh(ZQ[15], b1, c1) + d1) + ZR26(ZQ[15]);
    ZQ[26] = Znonce + PreVal4_T1;

    ZQ[27] = ZMa(f1, g1, ZQ[26]) + ZR30(ZQ[26]);
    ZQ[17] = ZQ[16] + h1;

    ZQ[19] = (ZCh(ZQ[17], ZQ[15], b1) + c1_plus_k5) + ZR26(ZQ[17]);
    ZQ[28] = ZQ[27] + ZQ[16];

    ZQ[548] = ZMa(ZQ[26], f1, ZQ[28]) + ZR30(ZQ[28]);
    ZQ[20] = ZQ[19] + g1;

    ZQ[22] = (ZCh(ZQ[20], ZQ[17], ZQ[15]) + b1_plus_k6) + ZR26(ZQ[20]);
    ZQ[29] = ZQ[548] + ZQ[19];

    ZQ[549] = ZMa(ZQ[28], ZQ[26], ZQ[29]) + ZR30(ZQ[29]);
    ZQ[23] = ZQ[22] + f1;

    ZQ[24] = ZCh(ZQ[23], ZQ[20], ZQ[17]) + ZR26(ZQ[23]);
    ZQ[180] = Znonce + PreVal4_state0_k7;
    ZQ[30] = ZQ[549] + ZQ[22];

    ZQ[31] = ZMa(ZQ[29], ZQ[28], ZQ[30]) + ZR30(ZQ[30]);
    ZQ[181] = ZQ[180] + ZQ[24];

    ZQ[182] = ZQ[181] + ZQ[26];
    ZQ[183] = ZQ[181] + ZQ[31];
    ZQ[18] = ZQ[17] + 0xd807aa98U;

    ZQ[186] = (ZCh(ZQ[182], ZQ[23], ZQ[20]) + ZQ[18]) + ZR26(ZQ[182]);
    ZQ[184] = ZMa(ZQ[30], ZQ[29], ZQ[183]) + ZR30(ZQ[183]);

    ZQ[187] = ZQ[186] + ZQ[28];
    ZQ[188] = ZQ[186] + ZQ[184];
    ZQ[21] = ZQ[20] + 0x12835b01U;

    ZQ[191] = (ZCh(ZQ[187], ZQ[182], ZQ[23]) + ZQ[21]) + ZR26(ZQ[187]);
    ZQ[189] = ZMa(ZQ[183], ZQ[30], ZQ[188]) + ZR30(ZQ[188]);

    ZQ[192] = ZQ[191] + ZQ[29];
    ZQ[193] = ZQ[191] + ZQ[189];
    ZQ[25] = ZQ[23] + 0x243185beU;

    ZQ[196] = (ZCh(ZQ[192], ZQ[187], ZQ[182]) + ZQ[25]) + ZR26(ZQ[192]);
    ZQ[194] = ZMa(ZQ[188], ZQ[183], ZQ[193]) + ZR30(ZQ[193]);

    ZQ[197] = ZQ[196] + ZQ[30];
    ZQ[198] = ZQ[196] + ZQ[194];
    ZQ[185] = ZQ[182] + 0x550c7dc3U;

    ZQ[201] = (ZCh(ZQ[197], ZQ[192], ZQ[187]) + ZQ[185]) + ZR26(ZQ[197]);
    ZQ[199] = ZMa(ZQ[193], ZQ[188], ZQ[198]) + ZR30(ZQ[198]);

    ZQ[202] = ZQ[201] + ZQ[183];
    ZQ[203] = ZQ[201] + ZQ[199];
    ZQ[190] = ZQ[187] + 0x72be5d74U;

    ZQ[206] = (ZCh(ZQ[202], ZQ[197], ZQ[192]) + ZQ[190]) + ZR26(ZQ[202]);
    ZQ[204] = ZMa(ZQ[198], ZQ[193], ZQ[203]) + ZR30(ZQ[203]);

    ZQ[207] = ZQ[206] + ZQ[188];
    ZQ[208] = ZQ[206] + ZQ[204];
    ZQ[195] = ZQ[192] + 0x80deb1feU;

    ZQ[211] = (ZCh(ZQ[207], ZQ[202], ZQ[197]) + ZQ[195]) + ZR26(ZQ[207]);
    ZQ[209] = ZMa(ZQ[203], ZQ[198], ZQ[208]) + ZR30(ZQ[208]);

    ZQ[212] = ZQ[193] + ZQ[211];
    ZQ[213] = ZQ[211] + ZQ[209];
    ZQ[200] = ZQ[197] + 0x9bdc06a7U;

    ZQ[216] = (ZCh(ZQ[212], ZQ[207], ZQ[202]) + ZQ[200]) + ZR26(ZQ[212]);
    ZQ[214] = ZMa(ZQ[208], ZQ[203], ZQ[213]) + ZR30(ZQ[213]);

    ZQ[217] = ZQ[198] + ZQ[216];
    ZQ[218] = ZQ[216] + ZQ[214];
    ZQ[205] = ZQ[202] + 0xc19bf3f4U;

    ZQ[220] = (ZCh(ZQ[217], ZQ[212], ZQ[207]) + ZQ[205]) + ZR26(ZQ[217]);
    ZQ[219] = ZMa(ZQ[213], ZQ[208], ZQ[218]) + ZR30(ZQ[218]);

    ZQ[222] = ZQ[203] + ZQ[220];
    ZQ[223] = ZQ[220] + ZQ[219];
    ZQ[210] = ZQ[207] + W16_plus_K16;

    ZQ[226] = (ZCh(ZQ[222], ZQ[217], ZQ[212]) + ZQ[210]) + ZR26(ZQ[222]);
    ZQ[225] = ZMa(ZQ[218], ZQ[213], ZQ[223]) + ZR30(ZQ[223]);

    ZQ[0] = ZR25(Znonce) + W18;
    ZQ[228] = ZQ[226] + ZQ[225];
    ZQ[227] = ZQ[208] + ZQ[226];
    ZQ[215] = ZQ[212] + W17_plus_K17;

    ZQ[231] = (ZCh(ZQ[227], ZQ[222], ZQ[217]) + ZQ[215]) + ZR26(ZQ[227]);
    ZQ[229] = ZMa(ZQ[223], ZQ[218], ZQ[228]) + ZR30(ZQ[228]);
    ZQ[1] = ZQ[0] + 0x0fc19dc6U;

    ZQ[232] = ZQ[213] + ZQ[231];
    ZQ[233] = ZQ[231] + ZQ[229];
    ZQ[221] = ZQ[217] + ZQ[1];
    ZQ[32] = Znonce + W19;

    ZQ[236] = (ZCh(ZQ[232], ZQ[227], ZQ[222]) + ZQ[221]) + ZR26(ZQ[232]);
    ZQ[234] = ZMa(ZQ[228], ZQ[223], ZQ[233]) + ZR30(ZQ[233]);
    ZQ[33] = ZQ[32] + 0x240ca1ccU;

    ZQ[3] = ZR15(ZQ[0]) + 0x80000000U;
    ZQ[238] = ZQ[236] + ZQ[234];
    ZQ[237] = ZQ[218] + ZQ[236];
    ZQ[224] = ZQ[222] + ZQ[33];

    ZQ[241] = (ZCh(ZQ[237], ZQ[232], ZQ[227]) + ZQ[224]) + ZR26(ZQ[237]);
    ZQ[239] = ZMa(ZQ[233], ZQ[228], ZQ[238]) + ZR30(ZQ[238]);
    ZQ[4] = ZQ[3] + 0x2de92c6fU;

    ZQ[35] = ZR15(ZQ[32]);
    ZQ[243] = ZQ[241] + ZQ[239];
    ZQ[242] = ZQ[223] + ZQ[241];
    ZQ[230] = ZQ[227] + ZQ[4];

    ZQ[246] = (ZCh(ZQ[242], ZQ[237], ZQ[232]) + ZQ[230]) + ZR26(ZQ[242]);
    ZQ[244] = ZMa(ZQ[238], ZQ[233], ZQ[243]) + ZR30(ZQ[243]);
    ZQ[36] = ZQ[35] + 0x4a7484aaU;

    ZQ[7] = ZR15(ZQ[3]) + 0x00000280U;
    ZQ[248] = ZQ[246] + ZQ[244];
    ZQ[247] = ZQ[228] + ZQ[246];
    ZQ[235] = ZQ[232] + ZQ[36];

    ZQ[251] = (ZCh(ZQ[247], ZQ[242], ZQ[237]) + ZQ[235]) + ZR26(ZQ[247]);
    ZQ[249] = ZMa(ZQ[243], ZQ[238], ZQ[248]) + ZR30(ZQ[248]);
    ZQ[8] = ZQ[7] + 0x5cb0a9dcU;

    ZQ[38] = ZR15(ZQ[35]) + W16;
    ZQ[253] = ZQ[251] + ZQ[249];
    ZQ[252] = ZQ[233] + ZQ[251];
    ZQ[240] = ZQ[237] + ZQ[8];

    ZQ[256] = (ZCh(ZQ[252], ZQ[247], ZQ[242]) + ZQ[240]) + ZR26(ZQ[252]);
    ZQ[254] = ZMa(ZQ[248], ZQ[243], ZQ[253]) + ZR30(ZQ[253]);
    ZQ[40] = ZQ[38] + 0x76f988daU;

    ZQ[10] = ZR15(ZQ[7]) + W17;
    ZQ[258] = ZQ[256] + ZQ[254];
    ZQ[257] = ZQ[238] + ZQ[256];
    ZQ[245] = ZQ[242] + ZQ[40];

    ZQ[261] = (ZCh(ZQ[257], ZQ[252], ZQ[247]) + ZQ[245]) + ZR26(ZQ[257]);
    ZQ[259] = ZMa(ZQ[253], ZQ[248], ZQ[258]) + ZR30(ZQ[258]);
    ZQ[13] = ZQ[10] + 0x983e5152U;

    ZQ[43] = ZR15(ZQ[38]) + ZQ[0];
    ZQ[263] = ZQ[261] + ZQ[259];
    ZQ[262] = ZQ[243] + ZQ[261];
    ZQ[250] = ZQ[247] + ZQ[13];

    ZQ[266] = (ZCh(ZQ[262], ZQ[257], ZQ[252]) + ZQ[250]) + ZR26(ZQ[262]);
    ZQ[264] = ZMa(ZQ[258], ZQ[253], ZQ[263]) + ZR30(ZQ[263]);
    ZQ[11] = ZR15(ZQ[10]);
    ZQ[45] = ZQ[43] + 0xa831c66dU;

    ZQ[52] = ZQ[11] + ZQ[32];
    ZQ[267] = ZQ[248] + ZQ[266];
    ZQ[255] = ZQ[252] + ZQ[45];
    ZQ[268] = ZQ[266] + ZQ[264];

    ZQ[271] = (ZCh(ZQ[267], ZQ[262], ZQ[257]) + ZQ[255]) + ZR26(ZQ[267]);
    ZQ[269] = ZMa(ZQ[263], ZQ[258], ZQ[268]) + ZR30(ZQ[268]);
    ZQ[54] = ZQ[52] + 0xb00327c8U;

    ZQ[48] = ZR15(ZQ[43]) + ZQ[3];
    ZQ[273] = ZQ[271] + ZQ[269];
    ZQ[272] = ZQ[253] + ZQ[271];
    ZQ[260] = ZQ[257] + ZQ[54];

    ZQ[276] = (ZCh(ZQ[272], ZQ[267], ZQ[262]) + ZQ[260]) + ZR26(ZQ[272]);
    ZQ[274] = ZMa(ZQ[268], ZQ[263], ZQ[273]) + ZR30(ZQ[273]);
    ZQ[49] = ZQ[48] + 0xbf597fc7U;

    ZQ[61] = ZR15(ZQ[52]) + ZQ[35];
    ZQ[278] = ZQ[276] + ZQ[274];
    ZQ[277] = ZQ[258] + ZQ[276];
    ZQ[265] = ZQ[262] + ZQ[49];

    ZQ[281] = (ZCh(ZQ[277], ZQ[272], ZQ[267]) + ZQ[265]) + ZR26(ZQ[277]);
    ZQ[279] = ZMa(ZQ[273], ZQ[268], ZQ[278]) + ZR30(ZQ[278]);
    ZQ[62] = ZQ[61] + 0xc6e00bf3U;

    ZQ[53] = ZR15(ZQ[48]) + ZQ[7];
    ZQ[283] = ZQ[281] + ZQ[279];
    ZQ[282] = ZQ[263] + ZQ[281];
    ZQ[270] = ZQ[267] + ZQ[62];

    ZQ[286] = (ZCh(ZQ[282], ZQ[277], ZQ[272]) + ZQ[270]) + ZR26(ZQ[282]);
    ZQ[284] = ZMa(ZQ[278], ZQ[273], ZQ[283]) + ZR30(ZQ[283]);
    ZQ[39] = ZQ[38] + 0x00A00055U;
    ZQ[55] = ZQ[53] + 0xd5a79147U;

    ZQ[66] = ZR15(ZQ[61]) + ZQ[39];
    ZQ[288] = ZQ[286] + ZQ[284];
    ZQ[287] = ZQ[268] + ZQ[286];
    ZQ[275] = ZQ[272] + ZQ[55];

    ZQ[291] = (ZCh(ZQ[287], ZQ[282], ZQ[277]) + ZQ[275]) + ZR26(ZQ[287]);
    ZQ[289] = ZMa(ZQ[283], ZQ[278], ZQ[288]) + ZR30(ZQ[288]);
    ZQ[12] = ZQ[10] + W31;
    ZQ[68] = ZQ[66] + 0x06ca6351U;

    ZQ[67] = ZR15(ZQ[53]) + ZQ[12];
    ZQ[293] = ZQ[291] + ZQ[289];
    ZQ[292] = ZQ[273] + ZQ[291];
    ZQ[280] = ZQ[277] + ZQ[68];

    ZQ[296] = (ZCh(ZQ[292], ZQ[287], ZQ[282]) + ZQ[280]) + ZR26(ZQ[292]);
    ZQ[294] = ZMa(ZQ[288], ZQ[283], ZQ[293]) + ZR30(ZQ[293]);
    ZQ[2] = ZR25(ZQ[0]);
    ZQ[69] = ZQ[67] + 0x14292967U;
    ZQ[44] = ZQ[43] + W32;

    ZQ[75] = ZR15(ZQ[66]) + ZQ[44];
    ZQ[298] = ZQ[296] + ZQ[294];
    ZQ[297] = ZQ[278] + ZQ[296];
    ZQ[285] = ZQ[282] + ZQ[69];
    ZQ[5] = ZQ[2] + W17;

    ZQ[301] = (ZCh(ZQ[297], ZQ[292], ZQ[287]) + ZQ[285]) + ZR26(ZQ[297]);
    ZQ[299] = ZMa(ZQ[293], ZQ[288], ZQ[298]) + ZR30(ZQ[298]);
    ZQ[56] = ZQ[52] + ZQ[5];
    ZQ[76] = ZQ[75] + 0x27b70a85U;

    ZQ[34] = ZR25(ZQ[32]) + ZQ[0];
    ZQ[70] = ZR15(ZQ[67]) + ZQ[56];
    ZQ[302] = ZQ[283] + ZQ[301];
    ZQ[303] = ZQ[301] + ZQ[299];
    ZQ[290] = ZQ[287] + ZQ[76];

    ZQ[306] = (ZCh(ZQ[302], ZQ[297], ZQ[292]) + ZQ[290]) + ZR26(ZQ[302]);
    ZQ[304] = ZMa(ZQ[298], ZQ[293], ZQ[303]) + ZR30(ZQ[303]);
    ZQ[6] = ZR25(ZQ[3]);
    ZQ[77] = ZQ[70] + 0x2e1b2138U;
    ZQ[50] = ZQ[34] + ZQ[48];

    ZQ[78] = ZR15(ZQ[75]) + ZQ[50];
    ZQ[308] = ZQ[306] + ZQ[304];
    ZQ[307] = ZQ[288] + ZQ[306];
    ZQ[295] = ZQ[292] + ZQ[77];
    ZQ[41] = ZQ[32] + ZQ[6];

    ZQ[311] = (ZCh(ZQ[307], ZQ[302], ZQ[297]) + ZQ[295]) + ZR26(ZQ[307]);
    ZQ[309] = ZMa(ZQ[303], ZQ[298], ZQ[308]) + ZR30(ZQ[308]);
    ZQ[63] = ZQ[41] + ZQ[61];
    ZQ[85] = ZQ[78] + 0x4d2c6dfcU;

    ZQ[37] = ZR25(ZQ[35]) + ZQ[3];
    ZQ[79] = ZR15(ZQ[70]) + ZQ[63];
    ZQ[312] = ZQ[293] + ZQ[311];
    ZQ[313] = ZQ[311] + ZQ[309];
    ZQ[300] = ZQ[297] + ZQ[85];

    ZQ[316] = (ZCh(ZQ[312], ZQ[307], ZQ[302]) + ZQ[300]) + ZR26(ZQ[312]);
    ZQ[314] = ZMa(ZQ[308], ZQ[303], ZQ[313]) + ZR30(ZQ[313]);
    ZQ[9] = ZR25(ZQ[7]);
    ZQ[86] = ZQ[79] + 0x53380d13U;
    ZQ[57] = ZQ[37] + ZQ[53];

    ZQ[87] = ZR15(ZQ[78]) + ZQ[57];
    ZQ[318] = ZQ[316] + ZQ[314];
    ZQ[317] = ZQ[298] + ZQ[316];
    ZQ[305] = ZQ[302] + ZQ[86];
    ZQ[46] = ZQ[35] + ZQ[9];

    ZQ[321] = (ZCh(ZQ[317], ZQ[312], ZQ[307]) + ZQ[305]) + ZR26(ZQ[317]);
    ZQ[319] = ZMa(ZQ[313], ZQ[308], ZQ[318]) + ZR30(ZQ[318]);
    ZQ[71] = ZQ[46] + ZQ[66];
    ZQ[92] = ZQ[87] + 0x650a7354U;

    ZQ[42] = ZR25(ZQ[38]) + ZQ[7];
    ZQ[88] = ZR15(ZQ[79]) + ZQ[71];
    ZQ[322] = ZQ[303] + ZQ[321];
    ZQ[323] = ZQ[321] + ZQ[319];
    ZQ[310] = ZQ[307] + ZQ[92];

    ZQ[326] = (ZCh(ZQ[322], ZQ[317], ZQ[312]) + ZQ[310]) + ZR26(ZQ[322]);
    ZQ[324] = ZMa(ZQ[318], ZQ[313], ZQ[323]) + ZR30(ZQ[323]);
    ZQ[14] = ZR25(ZQ[10]);
    ZQ[93] = ZQ[88] + 0x766a0abbU;
    ZQ[72] = ZQ[42] + ZQ[67];

    ZQ[94] = ZR15(ZQ[87]) + ZQ[72];
    ZQ[328] = ZQ[326] + ZQ[324];
    ZQ[327] = ZQ[308] + ZQ[326];
    ZQ[315] = ZQ[312] + ZQ[93];
    ZQ[51] = ZQ[38] + ZQ[14];

    ZQ[331] = (ZCh(ZQ[327], ZQ[322], ZQ[317]) + ZQ[315]) + ZR26(ZQ[327]);
    ZQ[329] = ZMa(ZQ[323], ZQ[318], ZQ[328]) + ZR30(ZQ[328]);
    ZQ[80] = ZQ[51] + ZQ[75];
    ZQ[100] = ZQ[94] + 0x81c2c92eU;

    ZQ[47] = ZR25(ZQ[43]) + ZQ[10];
    ZQ[95] = ZR15(ZQ[88]) + ZQ[80];
    ZQ[332] = ZQ[313] + ZQ[331];
    ZQ[333] = ZQ[331] + ZQ[329];
    ZQ[320] = ZQ[317] + ZQ[100];

    ZQ[336] = (ZCh(ZQ[332], ZQ[327], ZQ[322]) + ZQ[320]) + ZR26(ZQ[332]);
    ZQ[334] = ZMa(ZQ[328], ZQ[323], ZQ[333]) + ZR30(ZQ[333]);
    ZQ[81] = ZQ[47] + ZQ[70];
    ZQ[101] = ZQ[95] + 0x92722c85U;

    ZQ[58] = ZR25(ZQ[52]) + ZQ[43];
    ZQ[102] = ZR15(ZQ[94]) + ZQ[81];
    ZQ[337] = ZQ[318] + ZQ[336];
    ZQ[338] = ZQ[336] + ZQ[334];
    ZQ[325] = ZQ[322] + ZQ[101];

    ZQ[341] = (ZCh(ZQ[337], ZQ[332], ZQ[327]) + ZQ[325]) + ZR26(ZQ[337]);
    ZQ[339] = ZMa(ZQ[333], ZQ[328], ZQ[338]) + ZR30(ZQ[338]);
    ZQ[89] = ZQ[58] + ZQ[78];
    ZQ[108] = ZQ[102] + 0xa2bfe8a1U;

    ZQ[59] = ZR25(ZQ[48]) + ZQ[52];
    ZQ[103] = ZR15(ZQ[95]) + ZQ[89];
    ZQ[342] = ZQ[323] + ZQ[341];
    ZQ[343] = ZQ[341] + ZQ[339];
    ZQ[330] = ZQ[327] + ZQ[108];

    ZQ[346] = (ZCh(ZQ[342], ZQ[337], ZQ[332]) + ZQ[330]) + ZR26(ZQ[342]);
    ZQ[344] = ZMa(ZQ[338], ZQ[333], ZQ[343]) + ZR30(ZQ[343]);
    ZQ[90] = ZQ[59] + ZQ[79];
    ZQ[109] = ZQ[103] + 0xa81a664bU;

    ZQ[64] = ZR25(ZQ[61]) + ZQ[48];
    ZQ[110] = ZR15(ZQ[102]) + ZQ[90];
    ZQ[347] = ZQ[328] + ZQ[346];
    ZQ[348] = ZQ[346] + ZQ[344];
    ZQ[335] = ZQ[332] + ZQ[109];

    ZQ[351] = (ZCh(ZQ[347], ZQ[342], ZQ[337]) + ZQ[335]) + ZR26(ZQ[347]);
    ZQ[349] = ZMa(ZQ[343], ZQ[338], ZQ[348]) + ZR30(ZQ[348]);
    ZQ[60] = ZR25(ZQ[53]);
    ZQ[116] = ZQ[110] + 0xc24b8b70U;
    ZQ[96] = ZQ[87] + ZQ[64];

    ZQ[111] = ZR15(ZQ[103]) + ZQ[96];
    ZQ[353] = ZQ[351] + ZQ[349];
    ZQ[352] = ZQ[333] + ZQ[351];
    ZQ[340] = ZQ[337] + ZQ[116];
    ZQ[65] = ZQ[60] + ZQ[61];

    ZQ[356] = (ZCh(ZQ[352], ZQ[347], ZQ[342]) + ZQ[340]) + ZR26(ZQ[352]);
    ZQ[354] = ZMa(ZQ[348], ZQ[343], ZQ[353]) + ZR30(ZQ[353]);
    ZQ[97] = ZQ[88] + ZQ[65];
    ZQ[117] = ZQ[111] + 0xc76c51a3U;

    ZQ[73] = ZR25(ZQ[66]) + ZQ[53];
    ZQ[118] = ZR15(ZQ[110]) + ZQ[97];
    ZQ[357] = ZQ[338] + ZQ[356];
    ZQ[358] = ZQ[356] + ZQ[354];
    ZQ[345] = ZQ[342] + ZQ[117];

    ZQ[361] = (ZCh(ZQ[357], ZQ[352], ZQ[347]) + ZQ[345]) + ZR26(ZQ[357]);
    ZQ[359] = ZMa(ZQ[353], ZQ[348], ZQ[358]) + ZR30(ZQ[358]);
    ZQ[104] = ZQ[73] + ZQ[94];
    ZQ[124] = ZQ[118] + 0xd192e819U;

    ZQ[74] = ZR25(ZQ[67]) + ZQ[66];
    ZQ[119] = ZR15(ZQ[111]) + ZQ[104];
    ZQ[362] = ZQ[343] + ZQ[361];
    ZQ[363] = ZQ[361] + ZQ[359];
    ZQ[350] = ZQ[347] + ZQ[124];

    ZQ[366] = (ZCh(ZQ[362], ZQ[357], ZQ[352]) + ZQ[350]) + ZR26(ZQ[362]);
    ZQ[364] = ZMa(ZQ[358], ZQ[353], ZQ[363]) + ZR30(ZQ[363]);
    ZQ[105] = ZQ[74] + ZQ[95];
    ZQ[125] = ZQ[119] + 0xd6990624U;

    ZQ[82] = ZR25(ZQ[75]) + ZQ[67];
    ZQ[126] = ZR15(ZQ[118]) + ZQ[105];
    ZQ[367] = ZQ[348] + ZQ[366];
    ZQ[368] = ZQ[366] + ZQ[364];
    ZQ[355] = ZQ[352] + ZQ[125];

    ZQ[371] = (ZCh(ZQ[367], ZQ[362], ZQ[357]) + ZQ[355]) + ZR26(ZQ[367]);
    ZQ[369] = ZMa(ZQ[363], ZQ[358], ZQ[368]) + ZR30(ZQ[368]);
    ZQ[112] = ZQ[102] + ZQ[82];
    ZQ[132] = ZQ[126] + 0xf40e3585U;

    ZQ[83] = ZR25(ZQ[70]) + ZQ[75];
    ZQ[127] = ZR15(ZQ[119]) + ZQ[112];
    ZQ[372] = ZQ[353] + ZQ[371];
    ZQ[373] = ZQ[371] + ZQ[369];
    ZQ[360] = ZQ[357] + ZQ[132];

    ZQ[376] = (ZCh(ZQ[372], ZQ[367], ZQ[362]) + ZQ[360]) + ZR26(ZQ[372]);
    ZQ[374] = ZMa(ZQ[368], ZQ[363], ZQ[373]) + ZR30(ZQ[373]);
    ZQ[113] = ZQ[103] + ZQ[83];
    ZQ[133] = ZQ[127] + 0x106aa070U;

    ZQ[84] = ZR25(ZQ[78]) + ZQ[70];
    ZQ[134] = ZR15(ZQ[126]) + ZQ[113];
    ZQ[377] = ZQ[358] + ZQ[376];
    ZQ[378] = ZQ[376] + ZQ[374];
    ZQ[365] = ZQ[362] + ZQ[133];

    ZQ[381] = (ZCh(ZQ[377], ZQ[372], ZQ[367]) + ZQ[365]) + ZR26(ZQ[377]);
    ZQ[379] = ZMa(ZQ[373], ZQ[368], ZQ[378]) + ZR30(ZQ[378]);
    ZQ[120] = ZQ[110] + ZQ[84];
    ZQ[140] = ZQ[134] + 0x19a4c116U;

    ZQ[91] = ZR25(ZQ[79]) + ZQ[78];
    ZQ[135] = ZR15(ZQ[127]) + ZQ[120];
    ZQ[382] = ZQ[363] + ZQ[381];
    ZQ[383] = ZQ[381] + ZQ[379];
    ZQ[370] = ZQ[367] + ZQ[140];

    ZQ[386] = (ZCh(ZQ[382], ZQ[377], ZQ[372]) + ZQ[370]) + ZR26(ZQ[382]);
    ZQ[384] = ZMa(ZQ[378], ZQ[373], ZQ[383]) + ZR30(ZQ[383]);
    ZQ[121] = ZQ[111] + ZQ[91];
    ZQ[141] = ZQ[135] + 0x1e376c08U;

    ZQ[98] = ZR25(ZQ[87]) + ZQ[79];
    ZQ[142] = ZR15(ZQ[134]) + ZQ[121];
    ZQ[387] = ZQ[368] + ZQ[386];
    ZQ[388] = ZQ[386] + ZQ[384];
    ZQ[375] = ZQ[372] + ZQ[141];

    ZQ[391] = (ZCh(ZQ[387], ZQ[382], ZQ[377]) + ZQ[375]) + ZR26(ZQ[387]);
    ZQ[389] = ZMa(ZQ[383], ZQ[378], ZQ[388]) + ZR30(ZQ[388]);
    ZQ[128] = ZQ[118] + ZQ[98];
    ZQ[147] = ZQ[142] + 0x2748774cU;

    ZQ[99] = ZR25(ZQ[88]) + ZQ[87];
    ZQ[143] = ZR15(ZQ[135]) + ZQ[128];
    ZQ[392] = ZQ[373] + ZQ[391];
    ZQ[393] = ZQ[391] + ZQ[389];
    ZQ[380] = ZQ[377] + ZQ[147];

    ZQ[396] = (ZCh(ZQ[392], ZQ[387], ZQ[382]) + ZQ[380]) + ZR26(ZQ[392]);
    ZQ[394] = ZMa(ZQ[388], ZQ[383], ZQ[393]) + ZR30(ZQ[393]);
    ZQ[129] = ZQ[119] + ZQ[99];
    ZQ[148] = ZQ[143] + 0x34b0bcb5U;

    ZQ[106] = ZR25(ZQ[94]) + ZQ[88];
    ZQ[149] = ZR15(ZQ[142]) + ZQ[129];
    ZQ[397] = ZQ[378] + ZQ[396];
    ZQ[398] = ZQ[396] + ZQ[394];
    ZQ[385] = ZQ[382] + ZQ[148];

    ZQ[401] = (ZCh(ZQ[397], ZQ[392], ZQ[387]) + ZQ[385]) + ZR26(ZQ[397]);
    ZQ[399] = ZMa(ZQ[393], ZQ[388], ZQ[398]) + ZR30(ZQ[398]);
    ZQ[136] = ZQ[126] + ZQ[106];
    ZQ[153] = ZQ[149] + 0x391c0cb3U;

    ZQ[107] = ZR25(ZQ[95]) + ZQ[94];
    ZQ[150] = ZR15(ZQ[143]) + ZQ[136];
    ZQ[402] = ZQ[383] + ZQ[401];
    ZQ[403] = ZQ[401] + ZQ[399];
    ZQ[390] = ZQ[387] + ZQ[153];

    ZQ[406] = (ZCh(ZQ[402], ZQ[397], ZQ[392]) + ZQ[390]) + ZR26(ZQ[402]);
    ZQ[404] = ZMa(ZQ[398], ZQ[393], ZQ[403]) + ZR30(ZQ[403]);
    ZQ[137] = ZQ[127] + ZQ[107];
    ZQ[154] = ZQ[150] + 0x4ed8aa4aU;

    ZQ[114] = ZR25(ZQ[102]) + ZQ[95];
    ZQ[155] = ZR15(ZQ[149]) + ZQ[137];
    ZQ[407] = ZQ[388] + ZQ[406];
    ZQ[408] = ZQ[406] + ZQ[404];
    ZQ[395] = ZQ[392] + ZQ[154];

    ZQ[411] = (ZCh(ZQ[407], ZQ[402], ZQ[397]) + ZQ[395]) + ZR26(ZQ[407]);
    ZQ[409] = ZMa(ZQ[403], ZQ[398], ZQ[408]) + ZR30(ZQ[408]);
    ZQ[144] = ZQ[134] + ZQ[114];
    ZQ[159] = ZQ[155] + 0x5b9cca4fU;

    ZQ[115] = ZR25(ZQ[103]) + ZQ[102];
    ZQ[156] = ZR15(ZQ[150]) + ZQ[144];
    ZQ[412] = ZQ[393] + ZQ[411];
    ZQ[413] = ZQ[411] + ZQ[409];
    ZQ[400] = ZQ[397] + ZQ[159];

    ZQ[416] = (ZCh(ZQ[412], ZQ[407], ZQ[402]) + ZQ[400]) + ZR26(ZQ[412]);
    ZQ[414] = ZMa(ZQ[408], ZQ[403], ZQ[413]) + ZR30(ZQ[413]);
    ZQ[145] = ZQ[135] + ZQ[115];
    ZQ[160] = ZQ[156] + 0x682e6ff3U;

    ZQ[122] = ZR25(ZQ[110]) + ZQ[103];
    ZQ[161] = ZR15(ZQ[155]) + ZQ[145];
    ZQ[417] = ZQ[398] + ZQ[416];
    ZQ[418] = ZQ[416] + ZQ[414];
    ZQ[405] = ZQ[402] + ZQ[160];

    ZQ[421] = (ZCh(ZQ[417], ZQ[412], ZQ[407]) + ZQ[405]) + ZR26(ZQ[417]);
    ZQ[419] = ZMa(ZQ[413], ZQ[408], ZQ[418]) + ZR30(ZQ[418]);
    ZQ[151] = ZQ[142] + ZQ[122];
    ZQ[165] = ZQ[161] + 0x748f82eeU;

    ZQ[123] = ZR25(ZQ[111]) + ZQ[110];
    ZQ[162] = ZR15(ZQ[156]) + ZQ[151];
    ZQ[422] = ZQ[403] + ZQ[421];
    ZQ[423] = ZQ[421] + ZQ[419];
    ZQ[410] = ZQ[407] + ZQ[165];

    ZQ[426] = (ZCh(ZQ[422], ZQ[417], ZQ[412]) + ZQ[410]) + ZR26(ZQ[422]);
    ZQ[424] = ZMa(ZQ[418], ZQ[413], ZQ[423]) + ZR30(ZQ[423]);
    ZQ[152] = ZQ[143] + ZQ[123];
    ZQ[166] = ZQ[162] + 0x78a5636fU;

    ZQ[130] = ZR25(ZQ[118]) + ZQ[111];
    ZQ[167] = ZR15(ZQ[161]) + ZQ[152];
    ZQ[427] = ZQ[408] + ZQ[426];
    ZQ[428] = ZQ[426] + ZQ[424];
    ZQ[415] = ZQ[412] + ZQ[166];

    ZQ[431] = (ZCh(ZQ[427], ZQ[422], ZQ[417]) + ZQ[415]) + ZR26(ZQ[427]);
    ZQ[429] = ZMa(ZQ[423], ZQ[418], ZQ[428]) + ZR30(ZQ[428]);
    ZQ[157] = ZQ[149] + ZQ[130];
    ZQ[170] = ZQ[167] + 0x84c87814U;

    ZQ[131] = ZR25(ZQ[119]) + ZQ[118];
    ZQ[168] = ZR15(ZQ[162]) + ZQ[157];
    ZQ[432] = ZQ[413] + ZQ[431];
    ZQ[433] = ZQ[431] + ZQ[429];
    ZQ[420] = ZQ[417] + ZQ[170];

    ZQ[436] = (ZCh(ZQ[432], ZQ[427], ZQ[422]) + ZQ[420]) + ZR26(ZQ[432]);
    ZQ[434] = ZMa(ZQ[428], ZQ[423], ZQ[433]) + ZR30(ZQ[433]);
    ZQ[158] = ZQ[150] + ZQ[131];
    ZQ[171] = ZQ[168] + 0x8cc70208U;

    ZQ[138] = ZR25(ZQ[126]) + ZQ[119];
    ZQ[172] = ZR15(ZQ[167]) + ZQ[158];
    ZQ[437] = ZQ[418] + ZQ[436];
    ZQ[438] = ZQ[436] + ZQ[434];
    ZQ[425] = ZQ[422] + ZQ[171];

    ZQ[441] = (ZCh(ZQ[437], ZQ[432], ZQ[427]) + ZQ[425]) + ZR26(ZQ[437]);
    ZQ[439] = ZMa(ZQ[433], ZQ[428], ZQ[438]) + ZR30(ZQ[438]);
    ZQ[163] = ZQ[155] + ZQ[138];
    ZQ[174] = ZQ[172] + 0x90befffaU;

    ZQ[139] = ZR25(ZQ[127]) + ZQ[126];
    ZQ[173] = ZR15(ZQ[168]) + ZQ[163];
    ZQ[442] = ZQ[423] + ZQ[441];
    ZQ[443] = ZQ[441] + ZQ[439];
    ZQ[430] = ZQ[427] + ZQ[174];

    ZQ[445] = (ZCh(ZQ[442], ZQ[437], ZQ[432]) + ZQ[430]) + ZR26(ZQ[442]);
    ZQ[444] = ZMa(ZQ[438], ZQ[433], ZQ[443]) + ZR30(ZQ[443]);
    ZQ[164] = ZQ[156] + ZQ[139];
    ZQ[175] = ZQ[173] + 0xa4506cebU;

    ZQ[146] = ZR25(ZQ[134]) + ZQ[127];
    ZQ[176] = ZR15(ZQ[172]) + ZQ[164];
    ZQ[446] = ZQ[428] + ZQ[445];
    ZQ[447] = ZQ[445] + ZQ[444];
    ZQ[435] = ZQ[432] + ZQ[175];

    ZQ[449] = (ZCh(ZQ[446], ZQ[442], ZQ[437]) + ZQ[435]) + ZR26(ZQ[446]);
    ZQ[448] = ZMa(ZQ[443], ZQ[438], ZQ[447]) + ZR30(ZQ[447]);
    ZQ[169] = ZQ[161] + ZQ[146];
    ZQ[178] = ZQ[176] + 0xbef9a3f7U;

    ZQ[177] = ZR15(ZQ[173]) + ZQ[169];
    ZQ[451] = ZQ[449] + ZQ[448];
    ZQ[450] = ZQ[433] + ZQ[449];
    ZQ[440] = ZQ[437] + ZQ[178];

    ZQ[453] = (ZCh(ZQ[450], ZQ[446], ZQ[442]) + ZQ[440]) + ZR26(ZQ[450]);
    ZQ[452] = ZMa(ZQ[447], ZQ[443], ZQ[451]) + ZR30(ZQ[451]);
    ZQ[179] = ZQ[177] + 0xc67178f2U;

    ZQ[454] = ZQ[438] + ZQ[453];
    ZQ[494] = ZQ[442] + ZQ[179];
    ZQ[455] = ZQ[453] + ZQ[452];

    ZQ[457] = (ZCh(ZQ[454], ZQ[450], ZQ[446]) + ZQ[494]) + ZR26(ZQ[454]);
    ZQ[456] = ZMa(ZQ[451], ZQ[447], ZQ[455]) + ZR30(ZQ[455]);

    ZQ[459] = ZQ[457] + ZQ[456];

    ZQ[461] = ZQ[455] + state1;
    ZQ[460] = ZQ[459] + state0;

    ZQ[495] = ZQ[460] + 0x98c7e2a2U;
    ZQ[469] = ZQ[461] + 0x90bb1e3cU;

    ZQ[498] = (ZCh(ZQ[495], 0x510e527fU, 0x9b05688cU) + ZQ[469]) + ZR26(ZQ[495]);
    ZQ[462] = ZQ[451] + state2;

    ZQ[496] = ZQ[460] + 0xfc08884dU;
    ZQ[506] = ZQ[498] + 0x3c6ef372U;
    ZQ[470] = ZQ[462] + 0x50c6645bU;

    ZQ[507] = (ZCh(ZQ[506], ZQ[495], 0x510e527fU) + ZQ[470]) + ZR26(ZQ[506]);
    ZQ[500] = ZMa(0x6a09e667U, 0xbb67ae85U, ZQ[496]) + ZR30(ZQ[496]);
    ZQ[463] = ZQ[447] + state3;

    ZQ[458] = ZQ[443] + ZQ[457];
    ZQ[499] = ZQ[498] + ZQ[500];
    ZQ[508] = ZQ[507] + 0xbb67ae85U;
    ZQ[473] = ZQ[463] + 0x3ac42e24U;

    ZQ[510] = (ZCh(ZQ[508], ZQ[506], ZQ[495]) + ZQ[473]) + ZR26(ZQ[508]);
    ZQ[928] = ZMa(ZQ[496], 0x6a09e667U, ZQ[499]) + ZR30(ZQ[499]);
    ZQ[464] = ZQ[458] + state4;

    ZQ[476] = ZQ[464] + ZQ[460] + 0xd21ea4fdU;
    ZQ[511] = ZQ[510] + 0x6a09e667U;
    ZQ[509] = ZQ[928] + ZQ[507];
    ZQ[465] = ZQ[454] + state5;

    ZQ[514] = (ZCh(ZQ[511], ZQ[508], ZQ[506]) + ZQ[476]) + ZR26(ZQ[511]);
    ZQ[512] = ZMa(ZQ[499], ZQ[496], ZQ[509]) + ZR30(ZQ[509]);
    ZQ[478] = ZQ[465] + 0x59f111f1U;

    ZQ[519] = ZQ[506] + ZQ[478];
    ZQ[516] = ZQ[496] + ZQ[514];
    ZQ[513] = ZQ[510] + ZQ[512];
    ZQ[466] = ZQ[450] + state6;

    ZQ[520] = (ZCh(ZQ[516], ZQ[511], ZQ[508]) + ZQ[519]) + ZR26(ZQ[516]);
    ZQ[515] = ZMa(ZQ[509], ZQ[499], ZQ[513]) + ZR30(ZQ[513]);
    ZQ[480] = ZQ[466] + 0x923f82a4U;

    ZQ[524] = ZQ[508] + ZQ[480];
    ZQ[521] = ZQ[499] + ZQ[520];
    ZQ[517] = ZQ[514] + ZQ[515];
    ZQ[467] = ZQ[446] + state7;

    ZQ[525] = (ZCh(ZQ[521], ZQ[516], ZQ[511]) + ZQ[524]) + ZR26(ZQ[521]);
    ZQ[522] = ZMa(ZQ[513], ZQ[509], ZQ[517]) + ZR30(ZQ[517]);
    ZQ[484] = ZQ[467] + 0xab1c5ed5U;

    ZQ[529] = ZQ[511] + ZQ[484];
    ZQ[526] = ZQ[509] + ZQ[525];
    ZQ[523] = ZQ[520] + ZQ[522];

    ZQ[530] = (ZCh(ZQ[526], ZQ[521], ZQ[516]) + ZQ[529]) + ZR26(ZQ[526]);
    ZQ[550] = ZMa(ZQ[517], ZQ[513], ZQ[523]) + ZR30(ZQ[523]);

    ZQ[531] = ZQ[513] + ZQ[530];
    ZQ[533] = ZQ[516] + 0x5807aa98U;
    ZQ[527] = ZQ[550] + ZQ[525];

    ZQ[534] = (ZCh(ZQ[531], ZQ[526], ZQ[521]) + ZQ[533]) + ZR26(ZQ[531]);
    ZQ[551] = ZMa(ZQ[523], ZQ[517], ZQ[527]) + ZR30(ZQ[527]);

    ZQ[535] = ZQ[517] + ZQ[534];
    ZQ[538] = ZQ[521] + 0x12835b01U;
    ZQ[532] = ZQ[551] + ZQ[530];

    ZQ[539] = (ZCh(ZQ[535], ZQ[531], ZQ[526]) + ZQ[538]) + ZR26(ZQ[535]);
    ZQ[552] = ZMa(ZQ[527], ZQ[523], ZQ[532]) + ZR30(ZQ[532]);

    ZQ[540] = ZQ[523] + ZQ[539];
    ZQ[542] = ZQ[526] + 0x243185beU;
    ZQ[536] = ZQ[552] + ZQ[534];

    ZQ[543] = (ZCh(ZQ[540], ZQ[535], ZQ[531]) + ZQ[542]) + ZR26(ZQ[540]);
    ZQ[553] = ZMa(ZQ[532], ZQ[527], ZQ[536]) + ZR30(ZQ[536]);

    ZQ[544] = ZQ[527] + ZQ[543];
    ZQ[555] = ZQ[531] + 0x550c7dc3U;
    ZQ[541] = ZQ[553] + ZQ[539];

    ZQ[558] = (ZCh(ZQ[544], ZQ[540], ZQ[535]) + ZQ[555]) + ZR26(ZQ[544]);
    ZQ[547] = ZMa(ZQ[536], ZQ[532], ZQ[541]) + ZR30(ZQ[541]);

    ZQ[559] = ZQ[532] + ZQ[558];
    ZQ[556] = ZQ[535] + 0x72be5d74U;
    ZQ[545] = ZQ[547] + ZQ[543];

    ZQ[562] = (ZCh(ZQ[559], ZQ[544], ZQ[540]) + ZQ[556]) + ZR26(ZQ[559]);
    ZQ[561] = ZMa(ZQ[541], ZQ[536], ZQ[545]) + ZR30(ZQ[545]);

    ZQ[563] = ZQ[536] + ZQ[562];
    ZQ[560] = ZQ[561] + ZQ[558];
    ZQ[557] = ZQ[540] + 0x80deb1feU;

    ZQ[568] = (ZCh(ZQ[563], ZQ[559], ZQ[544]) + ZQ[557]) + ZR26(ZQ[563]);
    ZQ[564] = ZMa(ZQ[545], ZQ[541], ZQ[560]) + ZR30(ZQ[560]);

    ZQ[569] = ZQ[541] + ZQ[568];
    ZQ[572] = ZQ[544] + 0x9bdc06a7U;
    ZQ[565] = ZQ[562] + ZQ[564];

    ZQ[574] = (ZCh(ZQ[569], ZQ[563], ZQ[559]) + ZQ[572]) + ZR26(ZQ[569]);
    ZQ[570] = ZMa(ZQ[560], ZQ[545], ZQ[565]) + ZR30(ZQ[565]);
    ZQ[468] = ZR25(ZQ[461]);

    ZQ[497] = ZQ[468] + ZQ[460];
    ZQ[575] = ZQ[545] + ZQ[574];
    ZQ[571] = ZQ[568] + ZQ[570];
    ZQ[573] = ZQ[559] + 0xc19bf274U;

    ZQ[578] = (ZCh(ZQ[575], ZQ[569], ZQ[563]) + ZQ[573]) + ZR26(ZQ[575]);
    ZQ[576] = ZMa(ZQ[565], ZQ[560], ZQ[571]) + ZR30(ZQ[571]);
    ZQ[929] = ZR25(ZQ[462]);
    ZQ[503] = ZQ[497] + 0xe49b69c1U;

    ZQ[471] = ZQ[929] + ZQ[461] + 0x00a00000U;
    ZQ[582] = ZQ[563] + ZQ[503];
    ZQ[579] = ZQ[560] + ZQ[578];
    ZQ[577] = ZQ[574] + ZQ[576];

    ZQ[583] = (ZCh(ZQ[579], ZQ[575], ZQ[569]) + ZQ[582]) + ZR26(ZQ[579]);
    ZQ[580] = ZMa(ZQ[571], ZQ[565], ZQ[577]) + ZR30(ZQ[577]);
    ZQ[488] = ZQ[471] + 0xefbe4786U;

    ZQ[472] = ZR25(ZQ[463]) + ZQ[462];
    ZQ[587] = ZQ[569] + ZQ[488];
    ZQ[584] = ZQ[565] + ZQ[583];
    ZQ[581] = ZQ[578] + ZQ[580];

    ZQ[588] = (ZCh(ZQ[584], ZQ[579], ZQ[575]) + ZQ[587]) + ZR26(ZQ[584]);
    ZQ[586] = ZMa(ZQ[577], ZQ[571], ZQ[581]) + ZR30(ZQ[581]);
    ZQ[501] = ZR15(ZQ[497]) + ZQ[472];
    ZQ[475] = ZR15(ZQ[471]);
    ZQ[926] = ZQ[575] + 0x0fc19dc6U;

    ZQ[474] = ZQ[475] + ZQ[463] + ZR25(ZQ[464]);
    ZQ[927] = ZQ[926] + ZQ[501];
    ZQ[589] = ZQ[571] + ZQ[588];
    ZQ[585] = ZQ[583] + ZQ[586];

    ZQ[592] = (ZCh(ZQ[589], ZQ[584], ZQ[579]) + ZQ[927]) + ZR26(ZQ[589]);
    ZQ[590] = ZMa(ZQ[581], ZQ[577], ZQ[585]) + ZR30(ZQ[585]);
    ZQ[477] = ZR25(ZQ[465]) + ZQ[464];
    ZQ[489] = ZQ[474] + 0x240ca1ccU;

    ZQ[518] = ZR15(ZQ[501]) + ZQ[477];
    ZQ[479] = ZR25(ZQ[466]);
    ZQ[596] = ZQ[579] + ZQ[489];
    ZQ[593] = ZQ[577] + ZQ[592];
    ZQ[591] = ZQ[588] + ZQ[590];

    ZQ[597] = (ZCh(ZQ[593], ZQ[589], ZQ[584]) + ZQ[596]) + ZR26(ZQ[593]);
    ZQ[594] = ZMa(ZQ[585], ZQ[581], ZQ[591]) + ZR30(ZQ[591]);
    ZQ[481] = ZQ[479] + ZQ[465];
    ZQ[601] = ZQ[518] + 0x2de92c6fU;

    ZQ[482] = ZR15(ZQ[474]) + ZQ[481];
    ZQ[602] = ZQ[584] + ZQ[601];
    ZQ[598] = ZQ[581] + ZQ[597];
    ZQ[595] = ZQ[592] + ZQ[594];

    ZQ[632] = (ZCh(ZQ[598], ZQ[593], ZQ[589]) + ZQ[602]) + ZR26(ZQ[598]);
    ZQ[599] = ZMa(ZQ[591], ZQ[585], ZQ[595]) + ZR30(ZQ[595]);
    ZQ[483] = ZQ[466] + 0x00000100U + ZR25(ZQ[467]);
    ZQ[490] = ZQ[482] + 0x4a7484aaU;

    ZQ[528] = ZR15(ZQ[518]) + ZQ[483];
    ZQ[736] = ZQ[585] + ZQ[632];
    ZQ[605] = ZQ[589] + ZQ[490];
    ZQ[600] = ZQ[597] + ZQ[599];
    ZQ[485] = ZQ[467] + 0x11002000U;

    ZQ[738] = (ZCh(ZQ[736], ZQ[598], ZQ[593]) + ZQ[605]) + ZR26(ZQ[736]);
    ZQ[744] = ZMa(ZQ[595], ZQ[591], ZQ[600]) + ZR30(ZQ[600]);
    ZQ[487] = ZR15(ZQ[482]) + ZQ[485];
    ZQ[603] = ZQ[528] + 0x5cb0a9dcU;

    ZQ[502] = ZQ[497] + ZQ[487];
    ZQ[739] = ZQ[591] + ZQ[738];
    ZQ[604] = ZQ[593] + ZQ[603];
    ZQ[737] = ZQ[744] + ZQ[632];

    ZQ[741] = (ZCh(ZQ[739], ZQ[736], ZQ[598]) + ZQ[604]) + ZR26(ZQ[739]);
    ZQ[745] = ZMa(ZQ[600], ZQ[595], ZQ[737]) + ZR30(ZQ[737]);
    ZQ[486] = ZQ[471] + 0x80000000U;
    ZQ[606] = ZQ[502] + 0x76f988daU;

    ZQ[537] = ZR15(ZQ[528]) + ZQ[486];
    ZQ[742] = ZQ[595] + ZQ[741];
    ZQ[613] = ZQ[598] + ZQ[606];
    ZQ[740] = ZQ[745] + ZQ[738];

    ZQ[747] = (ZCh(ZQ[742], ZQ[739], ZQ[736]) + ZQ[613]) + ZR26(ZQ[742]);
    ZQ[746] = ZMa(ZQ[737], ZQ[600], ZQ[740]) + ZR30(ZQ[740]);
    ZQ[607] = ZQ[537] + 0x983e5152U;

    ZQ[546] = ZR15(ZQ[502]) + ZQ[501];
    ZQ[751] = ZQ[736] + ZQ[607];
    ZQ[748] = ZQ[600] + ZQ[747];
    ZQ[743] = ZQ[746] + ZQ[741];

    ZQ[752] = (ZCh(ZQ[748], ZQ[742], ZQ[739]) + ZQ[751]) + ZR26(ZQ[748]);
    ZQ[749] = ZMa(ZQ[740], ZQ[737], ZQ[743]) + ZR30(ZQ[743]);
    ZQ[608] = ZQ[546] + 0xa831c66dU;

    ZQ[554] = ZR15(ZQ[537]) + ZQ[474];
    ZQ[756] = ZQ[739] + ZQ[608];
    ZQ[753] = ZQ[737] + ZQ[752];
    ZQ[750] = ZQ[747] + ZQ[749];

    ZQ[757] = (ZCh(ZQ[753], ZQ[748], ZQ[742]) + ZQ[756]) + ZR26(ZQ[753]);
    ZQ[754] = ZMa(ZQ[743], ZQ[740], ZQ[750]) + ZR30(ZQ[750]);
    ZQ[609] = ZQ[554] + 0xb00327c8U;

    ZQ[566] = ZR15(ZQ[546]) + ZQ[518];
    ZQ[761] = ZQ[742] + ZQ[609];
    ZQ[758] = ZQ[740] + ZQ[757];
    ZQ[755] = ZQ[752] + ZQ[754];

    ZQ[762] = (ZCh(ZQ[758], ZQ[753], ZQ[748]) + ZQ[761]) + ZR26(ZQ[758]);
    ZQ[759] = ZMa(ZQ[750], ZQ[743], ZQ[755]) + ZR30(ZQ[755]);
    ZQ[610] = ZQ[566] + 0xbf597fc7U;

    ZQ[567] = ZR15(ZQ[554]) + ZQ[482];
    ZQ[766] = ZQ[748] + ZQ[610];
    ZQ[763] = ZQ[743] + ZQ[762];
    ZQ[760] = ZQ[757] + ZQ[759];

    ZQ[767] = (ZCh(ZQ[763], ZQ[758], ZQ[753]) + ZQ[766]) + ZR26(ZQ[763]);
    ZQ[764] = ZMa(ZQ[755], ZQ[750], ZQ[760]) + ZR30(ZQ[760]);
    ZQ[611] = ZQ[567] + 0xc6e00bf3U;

    ZQ[614] = ZR15(ZQ[566]) + ZQ[528];
    ZQ[771] = ZQ[753] + ZQ[611];
    ZQ[768] = ZQ[750] + ZQ[767];
    ZQ[765] = ZQ[762] + ZQ[764];

    ZQ[772] = (ZCh(ZQ[768], ZQ[763], ZQ[758]) + ZQ[771]) + ZR26(ZQ[768]);
    ZQ[769] = ZMa(ZQ[760], ZQ[755], ZQ[765]) + ZR30(ZQ[765]);
    ZQ[612] = ZQ[502] + 0x00400022U;
    ZQ[615] = ZQ[614] + 0xd5a79147U;

    ZQ[616] = ZR15(ZQ[567]) + ZQ[612];
    ZQ[504] = ZR25(ZQ[497]) + 0x00000100U;
    ZQ[776] = ZQ[758] + ZQ[615];
    ZQ[773] = ZQ[755] + ZQ[772];
    ZQ[770] = ZQ[767] + ZQ[769];

    ZQ[777] = (ZCh(ZQ[773], ZQ[768], ZQ[763]) + ZQ[776]) + ZR26(ZQ[773]);
    ZQ[774] = ZMa(ZQ[765], ZQ[760], ZQ[770]) + ZR30(ZQ[770]);
    ZQ[492] = ZR25(ZQ[471]);
    ZQ[618] = ZQ[537] + ZQ[504];
    ZQ[617] = ZQ[616] + 0x06ca6351U;

    ZQ[619] = ZR15(ZQ[614]) + ZQ[618];
    ZQ[781] = ZQ[763] + ZQ[617];
    ZQ[778] = ZQ[760] + ZQ[777];
    ZQ[775] = ZQ[772] + ZQ[774];
    ZQ[505] = ZQ[492] + ZQ[497];

    ZQ[782] = (ZCh(ZQ[778], ZQ[773], ZQ[768]) + ZQ[781]) + ZR26(ZQ[778]);
    ZQ[779] = ZMa(ZQ[770], ZQ[765], ZQ[775]) + ZR30(ZQ[775]);
    ZQ[621] = ZQ[505] + ZQ[546];
    ZQ[620] = ZQ[619] + 0x14292967U;

    ZQ[622] = ZR15(ZQ[616]) + ZQ[621];
    ZQ[625] = ZR25(ZQ[501]);
    ZQ[786] = ZQ[768] + ZQ[620];
    ZQ[783] = ZQ[765] + ZQ[782];
    ZQ[624] = ZQ[554] + ZQ[471];
    ZQ[780] = ZQ[777] + ZQ[779];

    ZQ[787] = (ZCh(ZQ[783], ZQ[778], ZQ[773]) + ZQ[786]) + ZR26(ZQ[783]);
    ZQ[784] = ZMa(ZQ[775], ZQ[770], ZQ[780]) + ZR30(ZQ[780]);
    ZQ[493] = ZR25(ZQ[474]);
    ZQ[626] = ZQ[625] + ZQ[624];
    ZQ[623] = ZQ[622] + 0x27b70a85U;

    ZQ[627] = ZR15(ZQ[619]) + ZQ[626];
    ZQ[791] = ZQ[773] + ZQ[623];
    ZQ[788] = ZQ[770] + ZQ[787];
    ZQ[785] = ZQ[782] + ZQ[784];
    ZQ[629] = ZQ[493] + ZQ[501];

    ZQ[792] = (ZCh(ZQ[788], ZQ[783], ZQ[778]) + ZQ[791]) + ZR26(ZQ[788]);
    ZQ[789] = ZMa(ZQ[780], ZQ[775], ZQ[785]) + ZR30(ZQ[785]);
    ZQ[630] = ZQ[566] + ZQ[629];
    ZQ[628] = ZQ[627] + 0x2e1b2138U;

    ZQ[634] = ZR25(ZQ[518]) + ZQ[474];
    ZQ[631] = ZR15(ZQ[622]) + ZQ[630];
    ZQ[796] = ZQ[778] + ZQ[628];
    ZQ[793] = ZQ[775] + ZQ[792];
    ZQ[790] = ZQ[787] + ZQ[789];

    ZQ[797] = (ZCh(ZQ[793], ZQ[788], ZQ[783]) + ZQ[796]) + ZR26(ZQ[793]);
    ZQ[794] = ZMa(ZQ[785], ZQ[780], ZQ[790]) + ZR30(ZQ[790]);
    ZQ[491] = ZR25(ZQ[482]);
    ZQ[635] = ZQ[567] + ZQ[634];
    ZQ[633] = ZQ[631] + 0x4d2c6dfcU;

    ZQ[636] = ZR15(ZQ[627]) + ZQ[635];
    ZQ[801] = ZQ[783] + ZQ[633];
    ZQ[798] = ZQ[780] + ZQ[797];
    ZQ[795] = ZQ[792] + ZQ[794];
    ZQ[638] = ZQ[491] + ZQ[518];

    ZQ[802] = (ZCh(ZQ[798], ZQ[793], ZQ[788]) + ZQ[801]) + ZR26(ZQ[798]);
    ZQ[799] = ZMa(ZQ[790], ZQ[785], ZQ[795]) + ZR30(ZQ[795]);
    ZQ[639] = ZQ[638] + ZQ[614];
    ZQ[637] = ZQ[636] + 0x53380d13U;

    ZQ[642] = ZR25(ZQ[528]) + ZQ[482];
    ZQ[640] = ZR15(ZQ[631]) + ZQ[639];
    ZQ[806] = ZQ[788] + ZQ[637];
    ZQ[803] = ZQ[785] + ZQ[802];
    ZQ[800] = ZQ[797] + ZQ[799];

    ZQ[807] = (ZCh(ZQ[803], ZQ[798], ZQ[793]) + ZQ[806]) + ZR26(ZQ[803]);
    ZQ[804] = ZMa(ZQ[795], ZQ[790], ZQ[800]) + ZR30(ZQ[800]);
    ZQ[643] = ZQ[616] + ZQ[642];
    ZQ[641] = ZQ[640] + 0x650a7354U;

    ZQ[646] = ZR25(ZQ[502]) + ZQ[528];
    ZQ[644] = ZR15(ZQ[636]) + ZQ[643];
    ZQ[811] = ZQ[793] + ZQ[641];
    ZQ[808] = ZQ[790] + ZQ[807];
    ZQ[805] = ZQ[802] + ZQ[804];

    ZQ[812] = (ZCh(ZQ[808], ZQ[803], ZQ[798]) + ZQ[811]) + ZR26(ZQ[808]);
    ZQ[809] = ZMa(ZQ[800], ZQ[795], ZQ[805]) + ZR30(ZQ[805]);
    ZQ[647] = ZQ[619] + ZQ[646];
    ZQ[645] = ZQ[644] + 0x766a0abbU;

    ZQ[650] = ZR25(ZQ[537]) + ZQ[502];
    ZQ[648] = ZR15(ZQ[640]) + ZQ[647];
    ZQ[816] = ZQ[798] + ZQ[645];
    ZQ[813] = ZQ[795] + ZQ[812];
    ZQ[810] = ZQ[807] + ZQ[809];

    ZQ[817] = (ZCh(ZQ[813], ZQ[808], ZQ[803]) + ZQ[816]) + ZR26(ZQ[813]);
    ZQ[814] = ZMa(ZQ[805], ZQ[800], ZQ[810]) + ZR30(ZQ[810]);
    ZQ[925] = ZQ[622] + ZQ[650];
    ZQ[649] = ZQ[648] + 0x81c2c92eU;

    ZQ[653] = ZR25(ZQ[546]) + ZQ[537];
    ZQ[651] = ZR15(ZQ[644]) + ZQ[925];
    ZQ[821] = ZQ[803] + ZQ[649];
    ZQ[818] = ZQ[800] + ZQ[817];
    ZQ[815] = ZQ[812] + ZQ[814];

    ZQ[822] = (ZCh(ZQ[818], ZQ[813], ZQ[808]) + ZQ[821]) + ZR26(ZQ[818]);
    ZQ[819] = ZMa(ZQ[810], ZQ[805], ZQ[815]) + ZR30(ZQ[815]);
    ZQ[654] = ZQ[627] + ZQ[653];
    ZQ[652] = ZQ[651] + 0x92722c85U;

    ZQ[657] = ZR25(ZQ[554]) + ZQ[546];
    ZQ[655] = ZR15(ZQ[648]) + ZQ[654];
    ZQ[826] = ZQ[808] + ZQ[652];
    ZQ[823] = ZQ[805] + ZQ[822];
    ZQ[820] = ZQ[817] + ZQ[819];

    ZQ[827] = (ZCh(ZQ[823], ZQ[818], ZQ[813]) + ZQ[826]) + ZR26(ZQ[823]);
    ZQ[824] = ZMa(ZQ[815], ZQ[810], ZQ[820]) + ZR30(ZQ[820]);
    ZQ[658] = ZQ[631] + ZQ[657];
    ZQ[656] = ZQ[655] + 0xa2bfe8a1U;

    ZQ[661] = ZR25(ZQ[566]) + ZQ[554];
    ZQ[659] = ZR15(ZQ[651]) + ZQ[658];
    ZQ[831] = ZQ[813] + ZQ[656];
    ZQ[828] = ZQ[810] + ZQ[827];
    ZQ[825] = ZQ[822] + ZQ[824];

    ZQ[832] = (ZCh(ZQ[828], ZQ[823], ZQ[818]) + ZQ[831]) + ZR26(ZQ[828]);
    ZQ[829] = ZMa(ZQ[820], ZQ[815], ZQ[825]) + ZR30(ZQ[825]);
    ZQ[662] = ZQ[636] + ZQ[661];
    ZQ[660] = ZQ[659] + 0xa81a664bU;

    ZQ[665] = ZR25(ZQ[567]) + ZQ[566];
    ZQ[663] = ZR15(ZQ[655]) + ZQ[662];
    ZQ[836] = ZQ[818] + ZQ[660];
    ZQ[833] = ZQ[815] + ZQ[832];
    ZQ[830] = ZQ[827] + ZQ[829];

    ZQ[837] = (ZCh(ZQ[833], ZQ[828], ZQ[823]) + ZQ[836]) + ZR26(ZQ[833]);
    ZQ[834] = ZMa(ZQ[825], ZQ[820], ZQ[830]) + ZR30(ZQ[830]);
    ZQ[666] = ZQ[640] + ZQ[665];
    ZQ[664] = ZQ[663] + 0xc24b8b70U;

    ZQ[669] = ZR25(ZQ[614]) + ZQ[567];
    ZQ[667] = ZR15(ZQ[659]) + ZQ[666];
    ZQ[841] = ZQ[823] + ZQ[664];
    ZQ[838] = ZQ[820] + ZQ[837];
    ZQ[835] = ZQ[832] + ZQ[834];

    ZQ[842] = (ZCh(ZQ[838], ZQ[833], ZQ[828]) + ZQ[841]) + ZR26(ZQ[838]);
    ZQ[839] = ZMa(ZQ[830], ZQ[825], ZQ[835]) + ZR30(ZQ[835]);
    ZQ[670] = ZQ[644] + ZQ[669];
    ZQ[668] = ZQ[667] + 0xc76c51a3U;

    ZQ[677] = ZR25(ZQ[616]) + ZQ[614];
    ZQ[671] = ZR15(ZQ[663]) + ZQ[670];
    ZQ[846] = ZQ[828] + ZQ[668];
    ZQ[843] = ZQ[825] + ZQ[842];
    ZQ[840] = ZQ[837] + ZQ[839];

    ZQ[847] = (ZCh(ZQ[843], ZQ[838], ZQ[833]) + ZQ[846]) + ZR26(ZQ[843]);
    ZQ[844] = ZMa(ZQ[835], ZQ[830], ZQ[840]) + ZR30(ZQ[840]);
    ZQ[678] = ZQ[648] + ZQ[677];
    ZQ[676] = ZQ[671] + 0xd192e819U;

    ZQ[682] = ZR25(ZQ[619]) + ZQ[616];
    ZQ[679] = ZR15(ZQ[667]) + ZQ[678];
    ZQ[851] = ZQ[833] + ZQ[676];
    ZQ[848] = ZQ[830] + ZQ[847];
    ZQ[845] = ZQ[842] + ZQ[844];

    ZQ[852] = (ZCh(ZQ[848], ZQ[843], ZQ[838]) + ZQ[851]) + ZR26(ZQ[848]);
    ZQ[849] = ZMa(ZQ[840], ZQ[835], ZQ[845]) + ZR30(ZQ[845]);
    ZQ[683] = ZQ[651] + ZQ[682];
    ZQ[680] = ZQ[679] + 0xd6990624U;

    ZQ[686] = ZR25(ZQ[622]) + ZQ[619];
    ZQ[684] = ZR15(ZQ[671]) + ZQ[683];
    ZQ[856] = ZQ[838] + ZQ[680];
    ZQ[853] = ZQ[835] + ZQ[852];
    ZQ[850] = ZQ[847] + ZQ[849];

    ZQ[857] = (ZCh(ZQ[853], ZQ[848], ZQ[843]) + ZQ[856]) + ZR26(ZQ[853]);
    ZQ[854] = ZMa(ZQ[845], ZQ[840], ZQ[850]) + ZR30(ZQ[850]);
    ZQ[687] = ZQ[655] + ZQ[686];
    ZQ[685] = ZQ[684] + 0xf40e3585U;

    ZQ[690] = ZR25(ZQ[627]) + ZQ[622];
    ZQ[688] = ZR15(ZQ[679]) + ZQ[687];
    ZQ[861] = ZQ[843] + ZQ[685];
    ZQ[858] = ZQ[840] + ZQ[857];
    ZQ[855] = ZQ[852] + ZQ[854];

    ZQ[862] = (ZCh(ZQ[858], ZQ[853], ZQ[848]) + ZQ[861]) + ZR26(ZQ[858]);
    ZQ[859] = ZMa(ZQ[850], ZQ[845], ZQ[855]) + ZR30(ZQ[855]);
    ZQ[691] = ZQ[659] + ZQ[690];
    ZQ[689] = ZQ[688] + 0x106aa070U;

    ZQ[694] = ZR25(ZQ[631]) + ZQ[627];
    ZQ[692] = ZR15(ZQ[684]) + ZQ[691];
    ZQ[866] = ZQ[848] + ZQ[689];
    ZQ[863] = ZQ[845] + ZQ[862];
    ZQ[860] = ZQ[857] + ZQ[859];

    ZQ[867] = (ZCh(ZQ[863], ZQ[858], ZQ[853]) + ZQ[866]) + ZR26(ZQ[863]);
    ZQ[864] = ZMa(ZQ[855], ZQ[850], ZQ[860]) + ZR30(ZQ[860]);
    ZQ[695] = ZQ[663] + ZQ[694];
    ZQ[693] = ZQ[692] + 0x19a4c116U;

    ZQ[698] = ZR25(ZQ[636]) + ZQ[631];
    ZQ[696] = ZR15(ZQ[688]) + ZQ[695];
    ZQ[871] = ZQ[853] + ZQ[693];
    ZQ[868] = ZQ[850] + ZQ[867];
    ZQ[865] = ZQ[862] + ZQ[864];

    ZQ[873] = (ZCh(ZQ[868], ZQ[863], ZQ[858]) + ZQ[871]) + ZR26(ZQ[868]);
    ZQ[869] = ZMa(ZQ[860], ZQ[855], ZQ[865]) + ZR30(ZQ[865]);
    ZQ[699] = ZQ[667] + ZQ[698];
    ZQ[697] = ZQ[696] + 0x1e376c08U;

    ZQ[702] = ZR25(ZQ[640]) + ZQ[636];
    ZQ[700] = ZR15(ZQ[692]) + ZQ[699];
    ZQ[877] = ZQ[858] + ZQ[697];
    ZQ[874] = ZQ[855] + ZQ[873];
    ZQ[870] = ZQ[867] + ZQ[869];

    ZQ[878] = (ZCh(ZQ[874], ZQ[868], ZQ[863]) + ZQ[877]) + ZR26(ZQ[874]);
    ZQ[875] = ZMa(ZQ[865], ZQ[860], ZQ[870]) + ZR30(ZQ[870]);
    ZQ[703] = ZQ[671] + ZQ[702];
    ZQ[701] = ZQ[700] + 0x2748774cU;

    ZQ[706] = ZR25(ZQ[644]) + ZQ[640];
    ZQ[704] = ZR15(ZQ[696]) + ZQ[703];
    ZQ[882] = ZQ[863] + ZQ[701];
    ZQ[879] = ZQ[860] + ZQ[878];
    ZQ[876] = ZQ[873] + ZQ[875];

    ZQ[883] = (ZCh(ZQ[879], ZQ[874], ZQ[868]) + ZQ[882]) + ZR26(ZQ[879]);
    ZQ[880] = ZMa(ZQ[870], ZQ[865], ZQ[876]) + ZR30(ZQ[876]);
    ZQ[707] = ZQ[679] + ZQ[706];
    ZQ[705] = ZQ[704] + 0x34b0bcb5U;

    ZQ[710] = ZR25(ZQ[648]) + ZQ[644];
    ZQ[708] = ZR15(ZQ[700]) + ZQ[707];
    ZQ[887] = ZQ[868] + ZQ[705];
    ZQ[884] = ZQ[865] + ZQ[883];
    ZQ[881] = ZQ[878] + ZQ[880];

    ZQ[888] = (ZCh(ZQ[884], ZQ[879], ZQ[874]) + ZQ[887]) + ZR26(ZQ[884]);
    ZQ[885] = ZMa(ZQ[876], ZQ[870], ZQ[881]) + ZR30(ZQ[881]);
    ZQ[711] = ZQ[684] + ZQ[710];
    ZQ[709] = ZQ[708] + 0x391c0cb3U;

    ZQ[714] = ZR25(ZQ[651]) + ZQ[648];
    ZQ[712] = ZR15(ZQ[704]) + ZQ[711];
    ZQ[892] = ZQ[874] + ZQ[709];
    ZQ[889] = ZQ[870] + ZQ[888];
    ZQ[886] = ZQ[883] + ZQ[885];

    ZQ[893] = (ZCh(ZQ[889], ZQ[884], ZQ[879]) + ZQ[892]) + ZR26(ZQ[889]);
    ZQ[890] = ZMa(ZQ[881], ZQ[876], ZQ[886]) + ZR30(ZQ[886]);
    ZQ[715] = ZQ[688] + ZQ[714];
    ZQ[713] = ZQ[712] + 0x4ed8aa4aU;

    ZQ[718] = ZR25(ZQ[655]) + ZQ[651];
    ZQ[716] = ZR15(ZQ[708]) + ZQ[715];
    ZQ[897] = ZQ[879] + ZQ[713];
    ZQ[894] = ZQ[876] + ZQ[893];
    ZQ[891] = ZQ[888] + ZQ[890];

    ZQ[898] = (ZCh(ZQ[894], ZQ[889], ZQ[884]) + ZQ[897]) + ZR26(ZQ[894]);
    ZQ[895] = ZMa(ZQ[886], ZQ[881], ZQ[891]) + ZR30(ZQ[891]);
    ZQ[719] = ZQ[692] + ZQ[718];
    ZQ[717] = ZQ[716] + 0x5b9cca4fU;

    ZQ[722] = ZR25(ZQ[659]) + ZQ[655];
    ZQ[720] = ZR15(ZQ[712]) + ZQ[719];
    ZQ[902] = ZQ[884] + ZQ[717];
    ZQ[899] = ZQ[881] + ZQ[898];
    ZQ[896] = ZQ[893] + ZQ[895];

    ZQ[903] = (ZCh(ZQ[899], ZQ[894], ZQ[889]) + ZQ[902]) + ZR26(ZQ[899]);
    ZQ[900] = ZMa(ZQ[891], ZQ[886], ZQ[896]) + ZR30(ZQ[896]);
    ZQ[723] = ZQ[696] + ZQ[722];
    ZQ[721] = ZQ[720] + 0x682e6ff3U;

    ZQ[672] = ZR25(ZQ[663]) + ZQ[659];
    ZQ[724] = ZR15(ZQ[716]) + ZQ[723];
    ZQ[907] = ZQ[889] + ZQ[721];
    ZQ[904] = ZQ[886] + ZQ[903];
    ZQ[901] = ZQ[898] + ZQ[900];

    ZQ[908] = (ZCh(ZQ[904], ZQ[899], ZQ[894]) + ZQ[907]) + ZR26(ZQ[904]);
    ZQ[905] = ZMa(ZQ[896], ZQ[891], ZQ[901]) + ZR30(ZQ[901]);
    ZQ[673] = ZR25(ZQ[667]) + ZQ[663];
    ZQ[726] = ZQ[700] + ZQ[672];
    ZQ[725] = ZQ[724] + 0x748f82eeU;

    ZQ[727] = ZR15(ZQ[720]) + ZQ[726];
    ZQ[912] = ZQ[894] + ZQ[725];
    ZQ[909] = ZQ[891] + ZQ[908];
    ZQ[906] = ZQ[903] + ZQ[905];
    ZQ[675] = ZQ[667] + 0x8cc70208U;
    ZQ[729] = ZQ[704] + ZQ[673];

    ZQ[913] = (ZCh(ZQ[909], ZQ[904], ZQ[899]) + ZQ[912]) + ZR26(ZQ[909]);
    ZQ[910] = ZMa(ZQ[901], ZQ[896], ZQ[906]) + ZR30(ZQ[906]);
    ZQ[674] = ZR25(ZQ[671]) + ZQ[675];
    ZQ[730] = ZR15(ZQ[724]) + ZQ[729];
    ZQ[728] = ZQ[727] + 0x78a5636fU;

    ZQ[681] = ZR25(ZQ[679]) + ZQ[671];
    ZQ[917] = ZQ[899] + ZQ[901] + ZQ[728];
    ZQ[914] = ZQ[896] + ZQ[913];
    ZQ[911] = ZQ[908] + ZQ[910];
    ZQ[732] = ZQ[708] + ZQ[674];
    ZQ[731] = ZQ[730] + 0x84c87814U;

    ZQ[918] = (ZCh(ZQ[914], ZQ[909], ZQ[904]) + ZQ[917]) + ZR26(ZQ[914]);
    ZQ[915] = ZMa(ZQ[906], ZQ[901], ZQ[911]) + ZR30(ZQ[911]);
    ZQ[733] = ZR15(ZQ[727]) + ZQ[732];
    ZQ[919] = ZQ[906] + ZQ[904] + ZQ[731];
    ZQ[734] = ZQ[712] + ZQ[681];

    ZQ[920] = (ZCh(ZQ[918], ZQ[914], ZQ[909]) + ZQ[919]) + ZR26(ZQ[918]);
    ZQ[735] = ZR15(ZQ[730]) + ZQ[734];
    ZQ[921] = ZQ[911] + ZQ[909] + ZQ[733];
    ZQ[916] = ZQ[913] + ZQ[915];

    ZQ[922] = (ZCh(ZQ[920], ZQ[918], ZQ[914]) + ZQ[921]) + ZR26(ZQ[920]);
    ZQ[923] = ZQ[916] + ZQ[914] + ZQ[735];

    ZQ[924] = (ZCh(ZQ[922], ZQ[920], ZQ[918]) + ZQ[923]) + ZR26(ZQ[922]);

    bool Zio = any(ZQ[924] == (z)0x136032EDU);

    bool io = false;
    io = (Zio) ? Zio : io;

    nonce = Znonce;

  #ifdef DOLOOPS
    loopout = (io) ? nonce : loopout;

    Znonce += (z)1;
  }

  nonce = loopout;

  bool io = any(nonce > (uintzz)0);
  #endif

  #ifdef VSTORE
  if(io) { vstorezz(nonce, 0, output); }
  #else
  if(io) { output[0] = (uintzz)nonce; }
  #endif
}

// vim: set ft=c
