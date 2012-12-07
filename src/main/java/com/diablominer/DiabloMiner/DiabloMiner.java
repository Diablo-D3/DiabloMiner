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

package com.diablominer.DiabloMiner;

import java.net.Authenticator;
import java.net.InetSocketAddress;
import java.net.MalformedURLException;
import java.net.PasswordAuthentication;
import java.net.Proxy;
import java.net.Proxy.Type;
import java.net.URL;
import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.Formatter;
import java.util.List;
import java.util.Set;
import java.util.HashSet;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;

import com.diablominer.DiabloMiner.DeviceState.DeviceState;
import com.diablominer.DiabloMiner.DeviceState.GPUHardwareType;
import com.diablominer.DiabloMiner.NetworkState.JSONRPCNetworkState;
import com.diablominer.DiabloMiner.NetworkState.NetworkState;

public class DiabloMiner {
	public final static long TWO32 = 4294967295L;
	public final static long TIME_OFFSET = 7500;

	NetworkState networkStateHead = null;
	NetworkState networkStateTail = null;
	Proxy proxy = null;
	int workLifetime = 5000;

	boolean debug = false;
	boolean debugtimer = false;

	double GPUTargetFPS = 30.0;
	double GPUTargetFPSBasis;
	int GPUForceWorkSize = 0;
	Integer GPUVectors[] = null;
	boolean GPUNoArray = false;
	boolean GPUDebugSource = false;

	String source;

	AtomicBoolean running = new AtomicBoolean(true);
	List<Thread> threads = new ArrayList<Thread>();

	long startTime;

	AtomicLong blocks = new AtomicLong(0);
	AtomicLong attempts = new AtomicLong(0);
	AtomicLong rejects = new AtomicLong(0);
	AtomicLong hwErrors = new AtomicLong(0);
	Set<String> enabledDevices = null;
	AtomicLong hashCount = new AtomicLong(0);

	final static String CLEAR = "																																						 ";

	public static void main(String[] args) throws Exception {
		DiabloMiner diabloMiner = new DiabloMiner();

		try {
			diabloMiner.execute(args);
		} catch(DiabloMinerFatalException e) {
			System.exit(-1);
		}
	}

	void execute(String[] args) throws Exception {
		threads.add(Thread.currentThread());

		Options options = new Options();
		options.addOption("u", "user", true, "bitcoin host username");
		options.addOption("p", "pass", true, "bitcoin host password");
		options.addOption("o", "host", true, "bitcoin host IP");
		options.addOption("r", "port", true, "bitcoin host port");
		options.addOption("l", "url", true, "bitcoin host url");
		options.addOption("x", "proxy", true, "optional proxy settings IP:PORT<:username:password>");
		options.addOption("g", "worklifetime", true, "maximum work lifetime in seconds");
		options.addOption("d", "debug", false, "enable debug output");
		options.addOption("dt", "debugtimer", false, "run for 1 minute and quit");
		options.addOption("D", "devices", true, "devices to enable, default all");
		options.addOption("f", "fps", true, "target GPU execution timing");
		options.addOption("na", "noarray", false, "turn GPU kernel array off");
		options.addOption("v", "vectors", true, "vector size in GPU kernel");
		options.addOption("w", "worksize", true, "override GPU worksize");
		options.addOption("ds", "ksource", false, "output GPU kernel source and quit");
		options.addOption("h", "help", false, "this help");

		PosixParser parser = new PosixParser();

		CommandLine line = null;

		try {
			line = parser.parse(options, args);

			if(line.hasOption("help")) {
				throw new ParseException("");
			}
		} catch(ParseException e) {
			System.out.println(e.getLocalizedMessage() + "\n");
			HelpFormatter formatter = new HelpFormatter();
			formatter.printHelp("DiabloMiner -u myuser -p mypassword [args]\n", "", options, "\nRemember to set rpcuser and rpcpassword in your ~/.bitcoin/bitcoin.conf " + "before starting bitcoind or bitcoin --daemon");
			return;
		}

		String splitUrl[] = null;
		String splitUser[] = null;
		String splitPass[] = null;
		String splitHost[] = null;
		String splitPort[] = null;

		if(line.hasOption("url"))
			splitUrl = line.getOptionValue("url").split(",");

		if(line.hasOption("user"))
			splitUser = line.getOptionValue("user").split(",");

		if(line.hasOption("pass"))
			splitPass = line.getOptionValue("pass").split(",");

		if(line.hasOption("host"))
			splitHost = line.getOptionValue("host").split(",");

		if(line.hasOption("port"))
			splitPort = line.getOptionValue("port").split(",");

		int networkStatesCount = 0;

		if(splitUrl != null)
			networkStatesCount = splitUrl.length;

		if(splitUser != null)
			networkStatesCount = Math.max(splitUser.length, networkStatesCount);

		if(splitPass != null)
			networkStatesCount = Math.max(splitPass.length, networkStatesCount);

		if(splitHost != null)
			networkStatesCount = Math.max(splitHost.length, networkStatesCount);

		if(splitPort != null)
			networkStatesCount = Math.max(splitPort.length, networkStatesCount);

		if(networkStatesCount == 0) {
			error("You forgot to give any bitcoin connection info, please add either -l, or -u -p -o and -r");
			System.exit(-1);
		}

		int j = 0;

		for(int i = 0; j < networkStatesCount; i++, j++) {
			String protocol = "http";
			String host = "localhost";
			int port = 8332;
			String path = "/";
			String user = "diablominer";
			String pass = "diablominer";
			byte hostChain = 0;

			if(splitUrl != null && splitUrl.length > i) {
				String[] usernameFix = splitUrl[i].split("@", 3);
				if(usernameFix.length > 2)
					splitUrl[i] = usernameFix[0] + "+++++" + usernameFix[1] + "@" + usernameFix[2];

				URL url = new URL(splitUrl[i]);

				if(url.getProtocol() != null && url.getProtocol().length() > 1)
					protocol = url.getProtocol();

				if(url.getHost() != null && url.getHost().length() > 1)
					host = url.getHost();

				if(url.getPort() != -1)
					port = url.getPort();

				if(url.getPath() != null && url.getPath().length() > 1)
					path = url.getPath();

				if(url.getUserInfo() != null && url.getUserInfo().length() > 1) {
					String[] userPassSplit = url.getUserInfo().split(":");

					user = userPassSplit[0].replace("+++++", "@");

					if(userPassSplit.length > 1 && userPassSplit[1].length() > 1)
						pass = userPassSplit[1];
				}
			}

			if(splitUser != null && splitUser.length > i)
				user = splitUser[i];

			if(splitPass != null && splitPass.length > i)
				pass = splitPass[i];

			if(splitHost != null && splitHost.length > i)
				host = splitHost[i];

			if(splitPort != null && splitPort.length > i)
				port = Integer.parseInt(splitPort[i]);

			NetworkState networkState;

			try {
				networkState = new JSONRPCNetworkState(this, new URL(protocol, host, port, path), user, pass, hostChain);
			} catch(MalformedURLException e) {
				throw new DiabloMinerFatalException(this, "Malformed connection paramaters");
			}

			if(networkStateHead == null) {
				networkStateHead = networkStateTail = networkState;
			} else {
				networkStateTail.setNetworkStateNext(networkState);
				networkStateTail = networkState;
			}
		}

		networkStateTail.setNetworkStateNext(networkStateHead);

		if(line.hasOption("proxy")) {
			final String[] proxySettings = line.getOptionValue("proxy").split(":");

			if(proxySettings.length >= 2) {
				proxy = new Proxy(Type.HTTP, new InetSocketAddress(proxySettings[0], Integer.valueOf(proxySettings[1])));
			}

			if(proxySettings.length >= 3) {
				Authenticator.setDefault(new Authenticator() {
					protected PasswordAuthentication getPasswordAuthentication() {
						return new PasswordAuthentication(proxySettings[2], proxySettings[3].toCharArray());
					}
				});
			}
		}

		if(line.hasOption("worklifetime"))
			workLifetime = Integer.parseInt(line.getOptionValue("worklifetime")) * 1000;

		if(line.hasOption("debug"))
			debug = true;

		if(line.hasOption("debugtimer")) {
			debugtimer = true;
		}

		if(line.hasOption("devices")) {
			String devices[] = line.getOptionValue("devices").split(",");
			enabledDevices = new HashSet<String>();
			for(String s : devices) {
				enabledDevices.add(s);

				if(Integer.parseInt(s) == 0) {
					error("Do not use 0 with -D, devices start at 1");
					System.exit(-1);
				}
			}
		}

		if(line.hasOption("fps")) {
			GPUTargetFPS = Float.parseFloat(line.getOptionValue("fps"));

			if(GPUTargetFPS < 0.1) {
				error("--fps argument is too low, adjusting to 0.1");
				GPUTargetFPS = 0.1;
			}
		}

		if(line.hasOption("noarray")) {
			GPUNoArray = true;
		}

		if(line.hasOption("worksize"))
			GPUForceWorkSize = Integer.parseInt(line.getOptionValue("worksize"));

		if(line.hasOption("vectors")) {
			String tempVectors[] = line.getOptionValue("vectors").split(",");

			GPUVectors = new Integer[tempVectors.length];

			try {
				for(int i = 0; i < GPUVectors.length; i++) {
					GPUVectors[i] = Integer.parseInt(tempVectors[i]);

					if(GPUVectors[i] > 16) {
						error("DiabloMiner now uses comma-seperated vector layouts, use those instead");
						System.exit(-1);
					} else if(GPUVectors[i] != 1 && GPUVectors[i] != 2 && GPUVectors[i] != 3 && GPUVectors[i] != 4 && GPUVectors[i] != 8 && GPUVectors[i] != 16) {
						error(GPUVectors[i] + " is not a vector length of 1, 2, 3, 4, 8, or 16");
						System.exit(-1);
					}
				}

				Arrays.sort(GPUVectors, Collections.reverseOrder());
			} catch(NumberFormatException e) {
				error("Cannot parse --vector argument(s)");
				System.exit(-1);
			}
		} else {
			GPUVectors = new Integer[1];
			GPUVectors[0] = 1;
		}

		if(line.hasOption("ds"))
			GPUDebugSource = true;

		info("Started");

		StringBuilder list = new StringBuilder(networkStateHead.getQueryUrl().toString());
		NetworkState networkState = networkStateHead.getNetworkStateNext();

		while(networkState != networkStateHead) {
			list.append(", " + networkState.getQueryUrl());
			networkState = networkState.getNetworkStateNext();
		}

		info("Connecting to: " + list);

		long previousHashCount = 0;
		double previousAdjustedHashCount = 0.0;
		long previousAdjustedStartTime = startTime = (now()) - 1;
		StringBuilder hashMeter = new StringBuilder(80);
		Formatter hashMeterFormatter = new Formatter(hashMeter);

		int deviceCount = 0;

		List<List<? extends DeviceState>> allDeviceStates = new ArrayList<List<? extends DeviceState>>();

		List<? extends DeviceState> GPUDeviceStates = new GPUHardwareType(this).getDeviceStates();
		deviceCount += GPUDeviceStates.size();
		allDeviceStates.add(GPUDeviceStates);

		while(running.get()) {
			for(List<? extends DeviceState> deviceStates : allDeviceStates) {
				for(DeviceState deviceState : deviceStates) {
					deviceState.checkDevice();
				}
			}

			long now = now();
			long currentHashCount = hashCount.get();
			double adjustedHashCount = (double) (currentHashCount - previousHashCount) / (double) (now - previousAdjustedStartTime);
			double hashLongCount = (double) currentHashCount / (double) (now - startTime) / 1000.0;

			if(now - startTime > TIME_OFFSET * 2) {
				double averageHashCount = (adjustedHashCount + previousAdjustedHashCount) / 2.0 / 1000.0;

				hashMeter.setLength(0);

				if(!debug) {
					hashMeterFormatter.format("\rmhash: %.1f/%.1f | accept: %d | reject: %d | hw error: %d", averageHashCount, hashLongCount, blocks.get(), rejects.get(), hwErrors.get());
				} else {
					hashMeterFormatter.format("\rmh: %.1f/%.1f | a/r/hwe: %d/%d/%d | gh: ", averageHashCount, hashLongCount, blocks.get(), rejects.get(), hwErrors.get());

					double basisAverage = 0.0;

					for(List<? extends DeviceState> deviceStates : allDeviceStates) {
						for(DeviceState deviceState : deviceStates) {
							hashMeterFormatter.format("%.1f ", deviceState.getDeviceHashCount() / 1000.0 / 1000.0 / 1000.0);
							basisAverage += deviceState.getBasis();
						}
					}

					basisAverage = 1000 / (basisAverage / deviceCount);

					hashMeterFormatter.format("| fps: %.1f", basisAverage);
				}

				System.out.print(hashMeter);
			} else {
				System.out.print("\rWaiting...");
			}

			if(now() - TIME_OFFSET * 2 > previousAdjustedStartTime) {
				previousHashCount = currentHashCount;
				previousAdjustedHashCount = adjustedHashCount;
				previousAdjustedStartTime = now - 1;
			}

			if(debugtimer && now() > startTime + 60 * 1000) {
				System.out.print("\n");
				info("Debug timer is up, quitting...");
				System.exit(0);
			}

			try {
				if(now - startTime > TIME_OFFSET)
					Thread.sleep(1000);
				else
					Thread.sleep(1);
			} catch(InterruptedException e) {
			}
		}

		hashMeterFormatter.close();
	}

	public static int rot(int x, int y) {
		return (x >>> y) | (x << (32 - y));
	}

	public static void sharound(int out[], int na, int nb, int nc, int nd, int ne, int nf, int ng, int nh, int x, int K) {
		int a = out[na];
		int b = out[nb];
		int c = out[nc];
		int d = out[nd];
		int e = out[ne];
		int f = out[nf];
		int g = out[ng];
		int h = out[nh];

		int t1 = h + (rot(e, 6) ^ rot(e, 11) ^ rot(e, 25)) + ((e & f) ^ ((~e) & g)) + K + x;
		int t2 = (rot(a, 2) ^ rot(a, 13) ^ rot(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));

		out[nd] = d + t1;
		out[nh] = t1 + t2;
	}

	public static String dateTime() {
		return "[" + DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.MEDIUM).format(new Date()) + "]";
	}

	public void info(String msg) {
		System.out.println("\r" + CLEAR + "\r" + dateTime() + " " + msg);
		threads.get(0).interrupt();
	}

	public void debug(String msg) {
		if(debug) {
			System.out.println("\r" + CLEAR + "\r" + dateTime() + " DEBUG: " + msg);
			threads.get(0).interrupt();
		}
	}

	public void error(String msg) {
		System.err.println("\r" + CLEAR + "\r" + dateTime() + " ERROR: " + msg);
		threads.get(0).interrupt();
	}

	public void addThread(Thread thread) {
		threads.add(thread);
	}

	public long incrementBlocks() {
		return blocks.incrementAndGet();
	}

	public long incrementAttempts() {
		return attempts.incrementAndGet();
	}

	public long incrementRejects() {
		return rejects.incrementAndGet();
	}

	public long incrementHWErrors() {
		return hwErrors.incrementAndGet();
	}

	public long addAndGetHashCount(long delta) {
		return hashCount.addAndGet(delta);
	}

	public static long now() {
		return System.nanoTime() / 1000000;
	}

	public void halt() {
		running.set(false);

		for(int i = 0; i < threads.size(); i++) {
			Thread thread = threads.get(i);
			if(thread != Thread.currentThread())
				thread.interrupt();
		}
	}

	public boolean getDebug() {
		return debug;
	}

	public Set<String> getEnabledDevices() {
		return enabledDevices;
	}

	public NetworkState getNetworkStateHead() {
		return networkStateHead;
	}

	public Proxy getProxy() {
		return proxy;
	}

	public int getWorkLifetime() {
		return workLifetime;
	}

	public boolean getRunning() {
		return running.get();
	}

	public double getGPUTargetFPS() {
		return GPUTargetFPS;
	}

	public int getGPUForceWorkSize() {
		return GPUForceWorkSize;
	}

	public Integer[] getGPUVectors() {
		return GPUVectors;
	}

	public boolean getGPUNoArray() {
		return GPUNoArray;
	}

	public boolean getGPUDebugSource() {
		return GPUDebugSource;
	}
}
