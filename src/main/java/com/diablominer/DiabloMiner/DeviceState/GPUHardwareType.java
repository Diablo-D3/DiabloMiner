package com.diablominer.DiabloMiner.DeviceState;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import org.lwjgl.opencl.CL;
import org.lwjgl.opencl.CL10;
import org.lwjgl.opencl.CLDevice;
import org.lwjgl.opencl.CLPlatform;

import com.diablominer.DiabloMiner.DiabloMiner;
import com.diablominer.DiabloMiner.DiabloMinerFatalException;

public class GPUHardwareType extends HardwareType {
	final static int EXECUTION_TOTAL = 2;
	final static String UPPER[] = { "X", "Y", "Z", "W", "T", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "k" };
	final static String LOWER[] = { "x", "y", "z", "w", "t", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k" };

	String source;
	double targetFPSBasis;
	int totalVectors;

	List<GPUDeviceState> deviceStates = new ArrayList<GPUDeviceState>();

	public GPUHardwareType(DiabloMiner diabloMiner) throws DiabloMinerFatalException {
		super(diabloMiner);

		try {
			InputStream stream = DiabloMiner.class.getResourceAsStream("/DiabloMiner.cl");
			byte[] data = new byte[64 * 1024];
			int pos = 0;

			while(pos < data.length) {
				int ret = stream.read(data, pos, data.length - pos);

				if(ret < 1)
					break;
				else
					pos += ret;
			}

			if(pos == 0)
				throw new DiabloMinerFatalException(diabloMiner, "Unable to read DiabloMiner.cl");

			source = new String(data).trim();
			stream.close();
		} catch(IOException e) {
			throw new DiabloMinerFatalException(diabloMiner, "Unable to read DiabloMiner.cl");
		}

		String sourceLines[] = source.split("\n");
		source = "";

		long vectorBase = 0;

		Integer[] vectors = diabloMiner.getGPUVectors();
		totalVectors = 0;
		int totalVectorsPOT;

		for(Integer vector : vectors) {
			totalVectors += vector;
		}

		if(totalVectors > 16)
			throw new DiabloMinerFatalException(diabloMiner, "DiabloMiner does not support more than 16 total vectors yet");

		int powtwo = 1 << (32 - Integer.numberOfLeadingZeros(totalVectors) - 1);

		if(totalVectors != powtwo)
			totalVectorsPOT = 1 << (32 - Integer.numberOfLeadingZeros(totalVectors));
		else
			totalVectorsPOT = totalVectors;

		for(int x = 0; x < sourceLines.length; x++) {
			String sourceLine = sourceLines[x];

			if(diabloMiner.getGPUNoArray() && !sourceLine.contains("z ZA")) {
				sourceLine = sourceLine.replaceAll("ZA\\[([0-9]+)\\]", "ZA$1");
			}

			if(sourceLine.contains("zz")) {
				if(totalVectors > 1)
					sourceLine = sourceLine.replaceAll("zz", String.valueOf(totalVectorsPOT));
				else
					sourceLine = sourceLine.replaceAll("zz", "");
			}

			if(sourceLine.contains("= (io) ? Znonce")) {
				int count = 0;
				String change = "(uintzz)(";

				for(int z = 0; z < vectors.length; z++) {
					change += UPPER[z] + "nonce";
					count += vectors[z];

					if(z != vectors.length - 1)
						change += ", ";
				}

				for(int z = count; z < totalVectorsPOT; z++)
					change += ", 0";

				change += ")";

				sourceLine = sourceLine.replace("Znonce", change);

				if(totalVectors > 1)
					sourceLine = sourceLine.replaceAll("zz", String.valueOf(totalVectorsPOT));
				else
					sourceLine = sourceLine.replaceAll("zz", "");

				source += sourceLine + "\n";
			} else if((sourceLine.contains("Z") || sourceLine.contains("z")) && !sourceLine.contains("__")) {
				for(int y = 0; y < vectors.length; y++) {
					String replace = sourceLine;

					if(diabloMiner.getGPUNoArray() && replace.contains("z ZA")) {
						replace = "";

						for(int z = 0; z < 930; z += 5) {
							replace += "		 ";

							for(int w = 0; w < 5; w++)
								replace += "z ZA" + (z + w) + "; ";

							replace += "\n";
						}
					}

					if(vectors[y] > 1 && replace.contains("typedef")) {
						replace = replace.replace("uint", "uint" + vectors[y]);
					} else if(replace.contains("z Znonce")) {
						String vectorGlobal;

						if(vectors[y] > 1)
							vectorGlobal = " + (uint" + vectors[y] + ")(";
						else
							vectorGlobal = " + (uint)(";

						for(int i = 0; i < vectors[y]; i++) {
							vectorGlobal += Long.toString((vectorBase + i));

							if(i != vectors[y] - 1)
								vectorGlobal += ", ";
						}

						vectorGlobal += ");";

						replace = replace.replace(";", vectorGlobal);

						vectorBase += vectors[y];
					}

					if(vectors[y] == 1 && replace.contains("bool Zio")) {
						replace = replace.replace("any(", "(");
					}

					source += replace.replaceAll("Z", UPPER[y]).replaceAll("z", LOWER[y]) + "\n";
				}
			} else if(totalVectors == 1 && sourceLine.contains("any(nonce")) {
				source += sourceLine.replace("any", "") + "\n";
			} else if(sourceLine.contains("__global")) {
				if(totalVectors > 1)
					source += sourceLine.replaceAll("uint", "uint" + totalVectorsPOT) + "\n";
				else
					source += sourceLine + "\n";
			} else {
				source += sourceLine + "\n";
			}
		}

		if(diabloMiner.getGPUDebugSource()) {
			System.out.println("\n---\n" + source);
			throw new DiabloMinerFatalException(diabloMiner, "Debug kernel source output, quitting");
		}


		targetFPSBasis = 1000.0 / (diabloMiner.getGPUTargetFPS());

		List<CLPlatform> platforms = null;

		try {
			CL.create();

			platforms = CLPlatform.getPlatforms();
		} catch(Exception e) {
			throw new DiabloMinerFatalException(diabloMiner, "Failed to initialize OpenCL, make sure your environment is setup correctly");
		}

		if(platforms == null || platforms.isEmpty())
			throw new DiabloMinerFatalException(diabloMiner, "No OpenCL platforms found");

		Set<String> enabledDevices = diabloMiner.getEnabledDevices();
		int count = 1;
		int platformCount = 0;

		for(CLPlatform platform : platforms) {
			PlatformVersion version;

			diabloMiner.info("Using " + platform.getInfoString(CL10.CL_PLATFORM_NAME).trim() + " " + platform.getInfoString(CL10.CL_PLATFORM_VERSION));

			String versions = platform.getInfoString(CL10.CL_PLATFORM_VERSION);
			if(versions.contains("OpenCL 1.0"))
				version = PlatformVersion.V1_0;
			else if (versions.contains("OpenCL 1.1"))
				version = PlatformVersion.V1_1;
			else
				version = PlatformVersion.V1_2;

			if(version == PlatformVersion.V1_0) {
				diabloMiner.error("OpenCL platform " + platform.getInfoString(CL10.CL_PLATFORM_NAME).trim() + " is not OpenCL 1.1 or later");
				continue;
			}

			List<CLDevice> devices = platform.getDevices(CL10.CL_DEVICE_TYPE_GPU | CL10.CL_DEVICE_TYPE_ACCELERATOR);

			if(devices == null || devices.isEmpty()) {
				diabloMiner.error("OpenCL platform " + platform.getInfoString(CL10.CL_PLATFORM_NAME).trim() + " contains no devices");
				continue;
			}

			if(devices != null) {
				for(CLDevice device : devices) {
					if(enabledDevices == null || enabledDevices.contains(platformCount + "." + count) || enabledDevices.contains(Integer.toString(count))) {
						String deviceName = device.getInfoString(CL10.CL_DEVICE_NAME).trim() + " (#" + count + ")";
						deviceStates.add(new GPUDeviceState(this, deviceName, platform, version, device));
					}

					count++;
				}
			}

			platformCount++;
		}

		if(deviceStates.size() == 0)
			throw new DiabloMinerFatalException(diabloMiner, "No OpenCL devices found");
	}

	public String getSource() {
		return source;
	}

	public double getTargetFPSBasis() {
		return targetFPSBasis;
	}

	public int getTotalVectors() {
		return totalVectors;
	}

	public List<? extends DeviceState> getDeviceStates() {
	   return deviceStates;
   }
}
