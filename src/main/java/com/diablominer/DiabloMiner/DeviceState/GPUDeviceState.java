/*
 * DiabloMiner - OpenCL miner for Bitcoin
 * Copyright (C) 2010, 2011, 2012 Patrick McFarland <diablod3@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.	If not, see <http://www.gnu.org/licenses/>.
 */

package com.diablominer.DiabloMiner.DeviceState;

import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.concurrent.atomic.AtomicLong;

import org.lwjgl.BufferUtils;
import org.lwjgl.LWJGLUtil;
import org.lwjgl.PointerBuffer;
import org.lwjgl.opencl.CL10;
import org.lwjgl.opencl.CL12;
import org.lwjgl.opencl.CLCommandQueue;
import org.lwjgl.opencl.CLContext;
import org.lwjgl.opencl.CLContextCallback;
import org.lwjgl.opencl.CLDevice;
import org.lwjgl.opencl.CLKernel;
import org.lwjgl.opencl.CLMem;
import org.lwjgl.opencl.CLPlatform;
import org.lwjgl.opencl.CLProgram;

import com.diablominer.DiabloMiner.DiabloMiner;
import com.diablominer.DiabloMiner.DiabloMinerFatalException;
import com.diablominer.DiabloMiner.NetworkState.WorkState;

public class GPUDeviceState extends DeviceState {
	final static int OUTPUTS = 16;

	final PlatformVersion platform_version;
	final CLDevice device;
	final CLContext context;
	final CLKernel kernel;

	AtomicLong workSize = new AtomicLong(0);
	long workSizeBase;
	boolean hwcheck;

	final PointerBuffer localWorkSize = BufferUtils.createPointerBuffer(1);

	final ExecutionState executions[];

	AtomicLong runs = new AtomicLong(0);
	long lastRuns = 0;
	long startTime = 0;
	long lastTime = 0;

	GPUHardwareType hardwareType;

	GPUDeviceState(GPUHardwareType hardwareType, String deviceName, CLPlatform platform, PlatformVersion platform_version, CLDevice device) throws DiabloMinerFatalException {
		this.platform_version = platform_version;
		this.hardwareType = hardwareType;
		this.diabloMiner = hardwareType.getDiabloMiner();
		this.deviceName = deviceName;

		this.resetNetworkState = DiabloMiner.now();

		this.executions = new ExecutionState[GPUHardwareType.EXECUTION_TOTAL];

		boolean hasBitAlign;
		boolean hasBFI_INT = false;
		CLProgram program;

		this.device = device;

		PointerBuffer properties = BufferUtils.createPointerBuffer(3);
		properties.put(CL10.CL_CONTEXT_PLATFORM).put(platform.getPointer()).put(0).flip();
		int err = 0;

		int deviceCU = device.getInfoInt(CL10.CL_DEVICE_MAX_COMPUTE_UNITS);
		long deviceWorkSize = device.getInfoSize(CL10.CL_DEVICE_MAX_WORK_GROUP_SIZE);

		context = CL10.clCreateContext(properties, device, new CLContextCallback() {
			protected void handleMessage(String errinfo, ByteBuffer private_info) {
				diabloMiner.error(errinfo);
			}
		}, null);

		ByteBuffer extb = BufferUtils.createByteBuffer(1024);
		CL10.clGetDeviceInfo(device, CL10.CL_DEVICE_EXTENSIONS, extb, null);
		byte[] exta = new byte[1024];
		extb.get(exta);

		if(new String(exta).contains("cl_amd_media_ops"))
			hasBitAlign = true;
		else
			hasBitAlign = false;

		if(hasBitAlign) {
			if(deviceName.contains("Cedar") || deviceName.contains("Redwood") || deviceName.contains("Juniper") || deviceName.contains("Cypress") || deviceName.contains("Hemlock") || deviceName.contains("Caicos") || deviceName.contains("Turks") || deviceName.contains("Barts") || deviceName.contains("Cayman") || deviceName.contains("Antilles") || deviceName.contains("Palm") || deviceName.contains("Sumo") || deviceName.contains("Wrestler") || deviceName.contains("WinterPark") || deviceName.contains("BeaverCreek"))
				hasBFI_INT = true;
		}

		// String compileOptions =
		// "-save-temps="+(device.getInfoString(CL10.CL_DEVICE_NAME).trim());
		String compileOptions = "";

		int forceWorkSize = diabloMiner.getGPUForceWorkSize();

		if(forceWorkSize > 0) {
			compileOptions += " -D WORKSIZE=" + forceWorkSize;
		} else {
			if(LWJGLUtil.getPlatform() == LWJGLUtil.PLATFORM_MACOSX)
				compileOptions += " -D WORKSIZE=64";
			else
				compileOptions += " -D WORKSIZE=" + deviceWorkSize;
		}

		if(hasBitAlign)
			compileOptions += " -D BITALIGN";

		if(hasBFI_INT)
			compileOptions += " -D BFIINT";

		program = CL10.clCreateProgramWithSource(context, hardwareType.getSource(), null);

		err = CL10.clBuildProgram(program, device, compileOptions, null);
		if(err != CL10.CL_SUCCESS) {
			ByteBuffer logBuffer = BufferUtils.createByteBuffer(1024);
			byte[] log = new byte[1024];

			CL10.clGetProgramBuildInfo(program, device, CL10.CL_PROGRAM_BUILD_LOG, logBuffer, null);

			logBuffer.get(log);

			System.out.println(new String(log));

			throw new DiabloMinerFatalException(diabloMiner, "Failed to build program on " + deviceName);
		}

		if(hasBFI_INT) {
			diabloMiner.info("BFI_INT patching enabled, disabling hardware check errors");
			hwcheck = false;

			int binarySize = (int) program.getInfoSizeArray(CL10.CL_PROGRAM_BINARY_SIZES)[0];

			ByteBuffer binary = BufferUtils.createByteBuffer(binarySize);
			program.getInfoBinaries(binary);

			for(int pos = 0; pos < binarySize - 4; pos++) {
				if((long) (0xFFFFFFFF & binary.getInt(pos)) == 0x464C457FL && (long) (0xFFFFFFFF & binary.getInt(pos + 4)) == 0x64010101L) {
					boolean firstText = true;

					int offset = binary.getInt(pos + 32);
					short entrySize = binary.getShort(pos + 46);
					short entryCount = binary.getShort(pos + 48);
					short index = binary.getShort(pos + 50);

					int header = pos + offset;

					int nameTableOffset = binary.getInt(header + index * entrySize + 16);
					int size = binary.getInt(header + index * entrySize + 20);

					int entry = header;

					for(int section = 0; section < entryCount; section++) {
						int nameIndex = binary.getInt(entry);
						offset = binary.getInt(entry + 16);
						size = binary.getInt(entry + 20);

						int name = pos + nameTableOffset + nameIndex;

						if((long) (0xFFFFFFFF & binary.getInt(name)) == 0x7865742E) {
							if(firstText) {
								firstText = false;
							} else {
								int sectionStart = pos + offset;
								for(int i = 0; i < size / 8; i++) {
									long instruction1 = (long) (0xFFFFFFFF & binary.getInt(sectionStart + i * 8));
									long instruction2 = (long) (0xFFFFFFFF & binary.getInt(sectionStart + i * 8 + 4));

									if((instruction1 & 0x02001000L) == 0x00000000L && (instruction2 & 0x9003F000L) == 0x0001A000L) {
										instruction2 ^= (0x0001A000L ^ 0x0000C000L);

										binary.putInt(sectionStart + i * 8 + 4, (int) instruction2);
									}
								}
							}
						}

						entry += entrySize;
					}

					break;
				}
			}

			IntBuffer binaryErr = BufferUtils.createIntBuffer(1);

			CL10.clReleaseProgram(program);
			program = CL10.clCreateProgramWithBinary(context, device, binary, binaryErr, null);

			err = CL10.clBuildProgram(program, device, compileOptions, null);

			if(err != CL10.CL_SUCCESS) {
				throw new DiabloMinerFatalException(diabloMiner, "Failed to BFI_INT patch kernel on " + deviceName);
			}
		}

		kernel = CL10.clCreateKernel(program, "search", null);
		if(kernel == null) {
			throw new DiabloMinerFatalException(diabloMiner, "Failed to create kernel on " + deviceName);

		}

		if(forceWorkSize == 0) {
			ByteBuffer rkwgs = BufferUtils.createByteBuffer(8);

			err = CL10.clGetKernelWorkGroupInfo(kernel, device, CL10.CL_KERNEL_WORK_GROUP_SIZE, rkwgs, null);

			localWorkSize.put(0, rkwgs.getLong(0));

			if(!(err == CL10.CL_SUCCESS) || localWorkSize.get(0) == 0)
				localWorkSize.put(0, deviceWorkSize);
		} else {
			localWorkSize.put(0, forceWorkSize);
		}

		diabloMiner.info("Added " + deviceName + " (" + deviceCU + " CU, local work size of " + localWorkSize.get(0) + ")");

		workSizeBase = 64 * 512;

		workSize.set(workSizeBase * 16);

		for(int i = 0; i < GPUHardwareType.EXECUTION_TOTAL; i++) {
			String executorName = deviceName + "/" + i;
			executions[i] = this.new GPUExecutionState(executorName);
			Thread thread = new Thread(executions[i], "DiabloMiner Executor (" + executorName + ")");
			thread.start();
			diabloMiner.addThread(thread);
		}
	}

	public void checkDevice() {
		long now = DiabloMiner.now();
		long elapsed = now - lastTime;
		long currentRuns = runs.get();
		double targetFPSBasis = hardwareType.getTargetFPSBasis();
		int totalVectors = hardwareType.getTotalVectors();
		long ws = workSize.get();

		if(now > startTime + DiabloMiner.TIME_OFFSET * 2 && currentRuns > lastRuns + diabloMiner.getGPUTargetFPS()) {
			basis = (double) elapsed / (double) (currentRuns - lastRuns);

			if(basis < targetFPSBasis / 4)
				ws += workSizeBase * 16;
			else if(basis < targetFPSBasis / 2)
				ws += workSizeBase * 4;
			else if(basis < targetFPSBasis)
				ws += workSizeBase;
			else if(basis > targetFPSBasis * 4)
				ws -= workSizeBase * 16;
			else if(basis > targetFPSBasis * 2)
				ws -= workSizeBase * 4;
			else if(basis > targetFPSBasis)
				ws -= workSizeBase;

			if(ws < workSizeBase)
				ws = workSizeBase;
			else if(ws > DiabloMiner.TWO32 / totalVectors - 1)
				ws = DiabloMiner.TWO32 / totalVectors - 1;

			lastRuns = currentRuns;
			lastTime = now;

			workSize.set(ws);
		}
	}

	public class GPUExecutionState extends ExecutionState {
		final CLCommandQueue queue;

		final CLMem output[] = new CLMem[2];
		final CLMem blank;
		ByteBuffer outputBuffer;
		int outputIndex = 0;

		final PointerBuffer workBaseBuffer = BufferUtils.createPointerBuffer(1);
		final PointerBuffer workSizeBuffer = BufferUtils.createPointerBuffer(1);

		final IntBuffer errBuffer = BufferUtils.createIntBuffer(1);
		int err;

		WorkState workState;
		boolean requestedNewWork;

		final int[] midstate2 = new int[16];
		final MessageDigest digestInside;
		final MessageDigest digestOutside;
		final ByteBuffer digestInput = ByteBuffer.allocate(80);
		byte[] digestOutput;

		public GPUExecutionState(String executionName) throws DiabloMinerFatalException {
			super(executionName);

			try {
				digestInside = MessageDigest.getInstance("SHA-256");
				digestOutside = MessageDigest.getInstance("SHA-256");
			} catch(NoSuchAlgorithmException e) {
				throw new DiabloMinerFatalException(diabloMiner, "Your Java implementation does not have a MessageDigest for SHA-256");
			}

			queue = CL10.clCreateCommandQueue(context, device, 0, errBuffer);

			if(queue == null || errBuffer.get(0) != CL10.CL_SUCCESS) {
				throw new DiabloMinerFatalException(diabloMiner, "Failed to allocate queue");
			}

			IntBuffer blankinit = BufferUtils.createIntBuffer(OUTPUTS * 4);

			for(int i = 0; i < OUTPUTS; i++)
				blankinit.put(0);

			blankinit.rewind();

			if(platform_version == PlatformVersion.V1_1)
				blank = CL10.clCreateBuffer(context, CL10.CL_MEM_COPY_HOST_PTR | CL10.CL_MEM_READ_ONLY, blankinit, errBuffer);
			else
				blank = CL10.clCreateBuffer(context, CL10.CL_MEM_COPY_HOST_PTR | CL10.CL_MEM_READ_ONLY | CL12.CL_MEM_HOST_NO_ACCESS, blankinit, errBuffer);

			if(blank == null || errBuffer.get(0) != CL10.CL_SUCCESS)
				throw new DiabloMinerFatalException(diabloMiner, "Failed to allocate blank buffer");

			blankinit.rewind();

			for(int i = 0; i < 2; i++) {
				if(platform_version == PlatformVersion.V1_1)
					output[i] = CL10.clCreateBuffer(context, CL10.CL_MEM_COPY_HOST_PTR | CL10.CL_MEM_WRITE_ONLY, blankinit, errBuffer);
				else
					output[i] = CL10.clCreateBuffer(context, CL10.CL_MEM_COPY_HOST_PTR | CL10.CL_MEM_WRITE_ONLY | CL12.CL_MEM_HOST_READ_ONLY, blankinit, errBuffer);

				blankinit.rewind();

				if(output[i] == null || errBuffer.get(0) != CL10.CL_SUCCESS) {
					throw new DiabloMinerFatalException(diabloMiner, "Failed to allocate output buffer");
				}
			}

			outputBuffer = CL10.clEnqueueMapBuffer(queue, output[outputIndex], 1, CL10.CL_MAP_READ, 0, OUTPUTS * 4, null, null, null);

			diabloMiner.getNetworkStateHead().addGetQueue(this);
			requestedNewWork = true;
		}

		public void run() {
			boolean submittedBlock;
			boolean resetBuffer;
			boolean hwError;
			boolean skipProcessing;
			boolean skipUnmap = false;

			while(diabloMiner.getRunning()) {
				submittedBlock = false;
				resetBuffer = false;
				hwError = false;
				skipProcessing = false;

				WorkState workIncoming = null;

				if(requestedNewWork) {
					try {
						workIncoming = incomingQueue.take();
					} catch(InterruptedException f) {
						continue;
					}
				} else {
					workIncoming = incomingQueue.poll();
				}

				if(workIncoming != null) {
					workState = workIncoming;
					requestedNewWork = false;
					resetBuffer = true;
					skipProcessing = true;
				}

				if(!skipProcessing | !skipUnmap) {
					for(int z = 0; z < OUTPUTS; z++) {
						int nonce = outputBuffer.getInt(z * 4);

						if(nonce != 0) {
							for(int j = 0; j < 19; j++)
								digestInput.putInt(j * 4, workState.getData(j));

							digestInput.putInt(19 * 4, nonce);

							digestOutput = digestOutside.digest(digestInside.digest(digestInput.array()));

							long G = ((long) (0xFF & digestOutput[27]) << 24) | ((long) (0xFF & digestOutput[26]) << 16) | ((long) (0xFF & digestOutput[25]) << 8) | ((long) (0xFF & digestOutput[24]));

							long H = ((long) (0xFF & digestOutput[31]) << 24) | ((long) (0xFF & digestOutput[30]) << 16) | ((long) (0xFF & digestOutput[29]) << 8) | ((long) (0xFF & digestOutput[28]));

							if(H == 0) {
								diabloMiner.debug("Attempt " + diabloMiner.incrementAttempts() + " from " + executionName);

								if(workState.getTarget(7) != 0 || G <= workState.getTarget(6)) {
									workState.submitNonce(nonce);
									submittedBlock = true;
								}
							} else {
								hwError = true;
							}

							resetBuffer = true;
						}
					}

					if(hwError && submittedBlock == false) {
						if(hwcheck && !diabloMiner.getDebug())
							diabloMiner.error("Invalid solution " + diabloMiner.incrementHWErrors() + " from " + deviceName + ", possible driver or hardware issue");
						else
							diabloMiner.debug("Invalid solution " + diabloMiner.incrementHWErrors() + " from " + executionName + ", possible driver or hardware issue");
					}
				}


				if(resetBuffer)
					CL10.clEnqueueCopyBuffer(queue, blank, output[outputIndex], 0, 0, OUTPUTS * 4, null, null);

				if(!skipUnmap) {
					CL10.clEnqueueUnmapMemObject(queue, output[outputIndex], outputBuffer, null, null);

					outputIndex = (outputIndex == 0) ? 1 : 0;
				}



				long workBase = workState.getBase();
				long increment = workSize.get();

				if(DiabloMiner.now() - 3600000 > resetNetworkState) {
					resetNetworkState = DiabloMiner.now();

					diabloMiner.getNetworkStateHead().addGetQueue(this);
					requestedNewWork = skipUnmap = true;
				} else {
					requestedNewWork = skipUnmap = workState.update(increment);
				}

				if(!requestedNewWork) {
					diabloMiner.addAndGetHashCount(increment);
					deviceHashCount.addAndGet(increment);
					runs.incrementAndGet();

					workSizeBuffer.put(0, increment);
					workBaseBuffer.put(0, workBase);

					System.arraycopy(workState.getMidstate(), 0, midstate2, 0, 8);

					DiabloMiner.sharound(midstate2, 0, 1, 2, 3, 4, 5, 6, 7, workState.getData(16), 0x428A2F98);
					DiabloMiner.sharound(midstate2, 7, 0, 1, 2, 3, 4, 5, 6, workState.getData(17), 0x71374491);
					DiabloMiner.sharound(midstate2, 6, 7, 0, 1, 2, 3, 4, 5, workState.getData(18), 0xB5C0FBCF);

					int W16 = workState.getData(16) + (DiabloMiner.rot(workState.getData(17), 7) ^ DiabloMiner.rot(workState.getData(17), 18) ^ (workState.getData(17) >>> 3));
					int W17 = workState.getData(17) + (DiabloMiner.rot(workState.getData(18), 7) ^ DiabloMiner.rot(workState.getData(18), 18) ^ (workState.getData(18) >>> 3)) + 0x01100000;
					int W18 = workState.getData(18) + (DiabloMiner.rot(W16, 17) ^ DiabloMiner.rot(W16, 19) ^ (W16 >>> 10));
					int W19 = 0x11002000 + (DiabloMiner.rot(W17, 17) ^ DiabloMiner.rot(W17, 19) ^ (W17 >>> 10));
					int W31 = 0x00000280 + (DiabloMiner.rot(W16, 7) ^ DiabloMiner.rot(W16, 18) ^ (W16 >>> 3));
					int W32 = W16 + (DiabloMiner.rot(W17, 7) ^ DiabloMiner.rot(W17, 18) ^ (W17 >>> 3));

					int PreVal4 = workState.getMidstate(4) + (DiabloMiner.rot(midstate2[1], 6) ^ DiabloMiner.rot(midstate2[1], 11) ^ DiabloMiner.rot(midstate2[1], 25)) + (midstate2[3] ^ (midstate2[1] & (midstate2[2] ^ midstate2[3]))) + 0xe9b5dba5;
					int T1 = (DiabloMiner.rot(midstate2[5], 2) ^ DiabloMiner.rot(midstate2[5], 13) ^ DiabloMiner.rot(midstate2[5], 22)) + ((midstate2[5] & midstate2[6]) | (midstate2[7] & (midstate2[5] | midstate2[6])));

					int PreVal4_state0 = PreVal4 + workState.getMidstate(0);
					int PreVal4_state0_k7 = (int) (PreVal4_state0 + 0xAB1C5ED5L);
					int PreVal4_T1 = PreVal4 + T1;
					int B1_plus_K6 = (int) (midstate2[1] + 0x923f82a4L);
					int C1_plus_K5 = (int) (midstate2[2] + 0x59f111f1L);
					int W16_plus_K16 = (int) (W16 + 0xe49b69c1L);
					int W17_plus_K17 = (int) (W17 + 0xefbe4786L);

					kernel.setArg(0, PreVal4_state0).setArg(1, PreVal4_state0_k7).setArg(2, PreVal4_T1).setArg(3, W18).setArg(4, W19).setArg(5, W16).setArg(6, W17).setArg(7, W16_plus_K16).setArg(8, W17_plus_K17).setArg(9, W31).setArg(10, W32).setArg(11, (int) (midstate2[3] + 0xB956c25bL)).setArg(12, midstate2[1]).setArg(13, midstate2[2]).setArg(14, midstate2[7]).setArg(15, midstate2[5]).setArg(16, midstate2[6]).setArg(17, C1_plus_K5).setArg(18, B1_plus_K6).setArg(19, workState.getMidstate(0)).setArg(20, workState.getMidstate(1)).setArg(21, workState.getMidstate(2)).setArg(22, workState.getMidstate(3)).setArg(23, workState.getMidstate(4)).setArg(24, workState.getMidstate(5)).setArg(25, workState.getMidstate(6)).setArg(26, workState.getMidstate(7)).setArg(27, output[outputIndex]);

					err = CL10.clEnqueueNDRangeKernel(queue, kernel, 1, workBaseBuffer, workSizeBuffer, localWorkSize, null, null);

					if(err != CL10.CL_SUCCESS && err != CL10.CL_INVALID_KERNEL_ARGS && err != CL10.CL_INVALID_GLOBAL_OFFSET) {
						try {
							throw new DiabloMinerFatalException(diabloMiner, "Failed to queue kernel, error " + err);
						} catch(DiabloMinerFatalException e) {
						}
					} else {
						if(err == CL10.CL_INVALID_KERNEL_ARGS) {
							diabloMiner.debug("Spurious CL_INVALID_KERNEL_ARGS error, ignoring");
							skipUnmap = true;
						} else if(err == CL10.CL_INVALID_GLOBAL_OFFSET) {
							diabloMiner.error("Spurious CL_INVALID_GLOBAL_OFFSET error, offset: " + workBase + ", work size: " + increment);
							skipUnmap = true;
						} else {
							outputBuffer = CL10.clEnqueueMapBuffer(queue, output[outputIndex], 1, CL10.CL_MAP_READ, 0, OUTPUTS * 4, null, null, null);
						}
					}
				}
			}
		}
	}
}
