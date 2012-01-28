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

package com.diablominer.DiabloMiner;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.net.Authenticator;
import java.net.HttpURLConnection;
import java.net.InetSocketAddress;
import java.net.MalformedURLException;
import java.net.PasswordAuthentication;
import java.net.Proxy;
import java.net.Proxy.Type;
import java.net.URL;
import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.Formatter;
import java.util.List;
import java.util.Set;
import java.util.HashSet;
import java.util.concurrent.LinkedBlockingDeque;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.GZIPInputStream;
import java.util.zip.InflaterInputStream;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.codec.binary.Base64;
import org.codehaus.jackson.JsonNode;
import org.codehaus.jackson.JsonProcessingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.codehaus.jackson.node.ArrayNode;
import org.codehaus.jackson.node.NullNode;
import org.codehaus.jackson.node.ObjectNode;
import org.lwjgl.BufferUtils;
import org.lwjgl.PointerBuffer;
import org.lwjgl.opencl.CL;
import org.lwjgl.opencl.CL10;
import org.lwjgl.opencl.CLCommandQueue;
import org.lwjgl.opencl.CLContext;
import org.lwjgl.opencl.CLContextCallback;
import org.lwjgl.opencl.CLDevice;
import org.lwjgl.opencl.CLKernel;
import org.lwjgl.opencl.CLMem;
import org.lwjgl.opencl.CLPlatform;
import org.lwjgl.opencl.CLProgram;

import com.diablominer.DiabloMiner.DiabloMiner.DeviceState.ExecutionState;
import com.diablominer.DiabloMiner.DiabloMiner.DeviceState.ExecutionState.GetWorkParser;
import com.diablominer.DiabloMiner.DiabloMiner.NetworkState.GetWorkItem;

class DiabloMiner {
  final static int EXECUTION_TOTAL = 3;
  final static long TIME_OFFSET = 7500;
  final static int OUTPUTS = 16;
  final static long TWO32 = 4294967295L;
  final static byte[] EMPTY_BUFFER = new byte[4 * OUTPUTS];

  NetworkState[] networkStates;
  int networkStatesCount;
  Proxy proxy = null;
  int getWorkRefresh = 5000;
  final ObjectMapper mapper = new ObjectMapper();
  final ObjectNode getWorkMessage = mapper.createObjectNode();

  boolean hwcheck = true;
  boolean debug = false;
  boolean edebug = false;
  boolean debugtimer = false;
  boolean array = false;
  boolean altArray = false;
  boolean donate = false;

  double targetFPS = 30.0;
  double targetFPSBasis;

  int forceWorkSize = 0;
  int zloops = 1;
  Integer vectors[];
  int totalVectors = 0;
  boolean vstore = false;

  String source;

  AtomicBoolean running = new AtomicBoolean(true);
  List<Thread> threads = new ArrayList<Thread>();

  List<DeviceState> deviceStates = new ArrayList<DeviceState>();
  int deviceStatesCount;

  long startTime;

  AtomicLong hashCount = new AtomicLong(0);

  AtomicLong currentBlocks = new AtomicLong(0);
  AtomicLong currentAttempts = new AtomicLong(0);
  AtomicLong currentRejects = new AtomicLong(0);
  AtomicLong currentHWErrors = new AtomicLong(0);
  Set<String> enabledDevices = null;

  final static String UPPER[] = { "X", "Y", "Z", "W", "T", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "k" };
  final static String LOWER[] = { "x", "y", "z", "w", "t", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k" };
  final static String CLEAR = "                                                                             ";

  public static void main(String [] args) throws Exception {
    DiabloMiner diabloMiner = new DiabloMiner();

    try {
      diabloMiner.execute(args);
    } catch (DiabloMinerFatalException e) {
      System.exit(-1);
    }
  }

  void execute(String[] args) throws Exception {
    threads.add(Thread.currentThread());

    getWorkMessage.put("method", "getwork");
    getWorkMessage.putArray("params");
    getWorkMessage.put("id", 1);

    Options options = new Options();
    options.addOption("a", "array", false, "use arrays to force register layout");
    options.addOption("aa", "altarray", false, "use alternate array layout");
    options.addOption("u", "user", true, "bitcoin host username");
    options.addOption("p", "pass", true, "bitcoin host password");
    options.addOption("f", "fps", true, "target execution timing");
    options.addOption("w", "worksize", true, "override worksize");
    options.addOption("o", "host", true, "bitcoin host IP");
    options.addOption("r", "port", true, "bitcoin host port");
    options.addOption("g", "getWork", true, "seconds between getWork refresh");
    options.addOption("D", "devices", true, "devices to enable");
    options.addOption("x", "proxy", true, "optional proxy settings IP:PORT<:username:password>");
    options.addOption("l", "url", true, "bitcoin host url");
    options.addOption("z", "loops", true, "kernel loops (PoT exp, 0 is off)");
    options.addOption("v", "vectors", true, "vector size in kernel");
    options.addOption("vs", "vstore", false, "use vstore instead of array set");
    options.addOption("d", "debug", false, "enable debug output");
    options.addOption("dd", "edebug", false, "enable extra debug output");
    options.addOption("ds", "ksource", false, "output kernel source and quit");
    options.addOption("dt", "debugtimer", false, "run for 1 minute and quit");
    options.addOption("b", "donate", false, "donate BTC to DiabloMiner development");
    options.addOption("h", "help", false, "this help");

    PosixParser parser = new PosixParser();

    CommandLine line = null;

    try {
      line = parser.parse(options, args);

      if(line.hasOption("help")) {
        throw new ParseException("A wise man once said, '↑ ↑ ↓ ↓ ← → ← → B A'");
      }
    } catch (ParseException e) {
      System.out.println(e.getLocalizedMessage() + "\n");
      HelpFormatter formatter = new HelpFormatter();
      formatter.printHelp("DiabloMiner -u myuser -p mypassword [args]\n", "", options,
          "\nRemember to set rpcuser and rpcpassword in your ~/.bitcoin/bitcoin.conf " +
          "before starting bitcoind or bitcoin --daemon");
      return;
    }

    if(line.hasOption("fps")) {
      targetFPS = Float.parseFloat(line.getOptionValue("fps"));

      if(targetFPS < 0.01) {
        error("--fps argument is too low, adjusting to 0.01");
        targetFPS = 0.01;
      }
    }

    if(line.hasOption("worksize"))
      forceWorkSize = Integer.parseInt(line.getOptionValue("worksize"));

    if(line.hasOption("getWork"))
      getWorkRefresh = Integer.parseInt(line.getOptionValue("getWork")) * 1000;

    if(line.hasOption("debug"))
      debug = true;

    if(line.hasOption("edebug")) {
      debug = true;
      edebug = true;
    }

    if(line.hasOption("debugtimer")) {
      debugtimer = true;
    }

    if(line.hasOption("loops"))
      zloops = (int) Math.pow(2, Integer.parseInt(line.getOptionValue("loops")));

    if(line.hasOption("array"))
      array = true;

    if(line.hasOption("altarray"))
      altArray = true;

    if(array && altArray) {
      error("Cannot use array and altarray at the same time");
      System.exit(-1);
    }

    if(line.hasOption("donate"))
      donate = true;

    if(line.hasOption("vectors")) {
      String tempVectors[] = line.getOptionValue("vectors").split(",");

      vectors = new Integer[tempVectors.length];

      try {
        for(int i = 0; i < vectors.length; i++) {
          vectors[i] = Integer.parseInt(tempVectors[i]);
          totalVectors += vectors[i];

          if(vectors[i] > 16) {
            error("DiabloMiner now uses comma-seperated vector layouts, use those instead");
            System.exit(-1);
          } else if(vectors[i] != 1 &&
                    vectors[i] != 2 &&
                    vectors[i] != 3 &&
                    vectors[i] != 4 &&
                    vectors[i] != 8 &&
                    vectors[i] != 16) {
            error(vectors[i] + " is not a vector length of 1, 2, 3, 4, 8, or 16");
            System.exit(-1);
          }
        }

        if(totalVectors > 16) {
          error("DiabloMiner does not support more than 16 total vectors yet");
          System.exit(-1);
        }

        int powtwo = 1 << (32 - Integer.numberOfLeadingZeros(totalVectors) - 1);

        if(totalVectors != powtwo)
          totalVectors = 1 << (32 - Integer.numberOfLeadingZeros(totalVectors));

        Arrays.sort(vectors, Collections.reverseOrder());
      } catch(NumberFormatException e) {
        error("Cannot parse --vector argument(s)");
        System.exit(-1);
      }
    } else {
      vectors = new Integer[1];
      vectors[0] = 1;
      totalVectors = 1;
    }

    if(line.hasOption("vstore")) {
      vstore = true;
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

    networkStatesCount = 0;

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

    if(donate) {
      j++;
      networkStatesCount++;

      networkStates = new NetworkState[networkStatesCount];

      networkStates[0] = new NetworkState(new URL("http", "mining.eligius.st", 8337, "/"),
            "1L12ACGxLH8kL2Zp7Sy6P8wgfQopDVyaoe", "", 0);

      info("You are donating to DiabloMiner, thank you!");
    } else {
      networkStates = new NetworkState[networkStatesCount];
    }

    for(int i = 0; j < networkStatesCount; i++, j++) {
      String protocol = "http";
      String host = "localhost";
      int port = 8332;
      String path = "/";
      String user = "diablominer";
      String pass = "diablominer";

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
          String [] userPassSplit = url.getUserInfo().split(":");

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

      try {
        networkStates[j] = new NetworkState(new URL(protocol, host, port, path), user, pass, j);
      } catch(MalformedURLException e) {
        throw new DiabloMinerFatalException("Malformed connection paramaters");
      }
    }

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
      throw new DiabloMinerFatalException("Unable to read DiabloMiner.cl");

    source = new String(data).trim();
    stream.close();

    String sourceLines[] = source.split("\n");
    source = "";
    long vectorOffset = (TWO32 / totalVectors);
    long vectorBase = 0;

    for(int x = 0; x < sourceLines.length; x++) {
      String sourceLine = sourceLines[x];

      if(sourceLine.contains("zz")) {
        if(totalVectors > 1)
          sourceLine = sourceLine.replaceAll("zz", String.valueOf(totalVectors));
        else
          sourceLine = sourceLine.replaceAll("zz", "");
      }

      if(sourceLine.contains("nonce = Znonce")) {
        int count = 0;
        sourceLine = "    nonce = (uintzz)(";

        for(int z = 0; z < vectors.length; z++) {
          sourceLine += UPPER[z] + "nonce";
          count += vectors[z];

          if(z != vectors.length - 1)
            sourceLine += ", ";
        }

        for(int z = 0; z < totalVectors - count; z++)
          sourceLine += ", 0";

        sourceLine += ");";

        if(totalVectors > 1)
          sourceLine = sourceLine.replaceAll("zz", String.valueOf(totalVectors));
        else
          sourceLine = sourceLine.replaceAll("zz", "");

        source += sourceLine + "\n";
      } else if((sourceLine.contains("Z") || sourceLine.contains("z")) && !sourceLine.contains("__")) {
        for(int y = 0; y < vectors.length; y++) {
          String replace = sourceLine;

          if(vectors[y] > 1 && replace.contains("typedef")) {
            replace = replace.replace("uint", "uint" + vectors[y]);
          } else if(replace.contains("z Znonce")) {
            String vectorGlobal;

            if(vectors[y] > 1)
              vectorGlobal = " + (uint" + vectors[y] + ")(";
            else
              vectorGlobal = " + (uint)(";

            for(int i = 0; i < vectors[y]; i++) {
              vectorGlobal += Long.toString((vectorBase + vectorOffset * i));

            if(i != vectors[y] - 1)
              vectorGlobal += ", ";
            }

            vectorGlobal += ");";

            replace = replace.replace(";", vectorGlobal);

            vectorBase += vectorOffset * vectors[y];
          } else if(altArray && y % 2 == 1 && replace.contains("+")) {
            replace = replace.replace(";", "");

            String[] split = replace.split("[^+]=");

            if(split.length > 1) {
              replace = "    " + split[0].trim() + " = ";

              split = split[1].split("\\+");

              for(int z = split.length - 1; z > -1; z--) {
                replace += split[z].trim();

                if(z != 0)
                  replace += " + ";
              }

              replace += ";";
            } else {
              replace = replace + ";";
            }
          }

          if(altArray && vectors[y] < 3) {
            if(vectors[y] == 1) {
              replace = replace.replaceAll("z Z([A-Z])\\[[0-9]\\]", "uint4 Z$1");
              replace = replace.replaceAll("Z([A-Z])\\[([0-9])\\]", "Z$1.s$2");
            } else {
              replace = replace.replaceAll("z Z([A-Z])\\[[0-9]\\]", "uint4 Z$10; uint4 Z$11");

              StringBuffer sb = new StringBuffer();
              Pattern p = Pattern.compile("Z([A-Z])\\[([0-9])\\]");
              Matcher m = p.matcher(replace);
              while(m.find()) {
                int index = Integer.parseInt(m.group(2));

                if(index % 2 == 0)
                  m.appendReplacement(sb, "Z$1" + (index / 2) + ".hi");
                else
                  m.appendReplacement(sb, "Z$1" + (index / 2) + ".lo");
              }

              m.appendTail(sb);
              replace = sb.toString();
            }
          } else if(!array) {
            replace = replace.replaceAll("z Z([A-Z])\\[[0-9]\\]", "z Z$10; z Z$11; z Z$12; z Z$13")
                             .replaceAll("Z([A-Z])\\[([0-9])\\]", "Z$1$2");
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
          source += sourceLine.replaceAll("uint", "uint" + totalVectors) + "\n";
        else
          source += sourceLine + "\n";
      } else {
        source += sourceLine + "\n";
      }
    }

    if(line.hasOption("ds")) {
      System.out.println("\n---\n" + source);
      throw new DiabloMinerFatalException("Debug kernel source output, quitting");
    }

    targetFPSBasis = 1000.0 / (targetFPS * EXECUTION_TOTAL);

    info("Started");

    StringBuilder list = new StringBuilder(networkStates[0].queryUrl.toString());

    if(!donate) {
      for(int i = 1; i < networkStatesCount; i++)
        list.append(", " + networkStates[i].queryUrl);
    } else {
      for(int i = 1; i < networkStatesCount - 1; i++)
        list.append(", " + networkStates[i].queryUrl);
    }

    info("Connecting to: " + list);

    List<CLPlatform> platforms = null;

    try {
      CL.create();

      platforms = CLPlatform.getPlatforms();
    } catch (Exception e) {
      throw new DiabloMinerFatalException("Failed to initialize OpenCL, make sure your environment is setup correctly");
    }

    if(platforms == null || platforms.isEmpty())
      throw new DiabloMinerFatalException("No OpenCL platforms found");

    int count = 1;
    int platformCount = 0;

    for(CLPlatform platform : platforms) {
      info("Using " + platform.getInfoString(CL10.CL_PLATFORM_NAME).trim() + " " +
            platform.getInfoString(CL10.CL_PLATFORM_VERSION));

      List<CLDevice> devices = platform.getDevices(CL10.CL_DEVICE_TYPE_GPU | CL10.CL_DEVICE_TYPE_ACCELERATOR);

      if(devices == null || devices.isEmpty())
        error("OpenCL platform " + platform.getInfoString(CL10.CL_PLATFORM_NAME).trim() + " contains no devices");

      if(devices != null) {
        for(CLDevice device : devices) {
          if(enabledDevices == null || enabledDevices.contains(platformCount + "." + count) || enabledDevices.contains(Integer.toString(count)))
            deviceStates.add(this.new DeviceState(platform, device, count));
          count++;
        }
      }

      platformCount++;
    }

    CL10.clUnloadCompiler();

    deviceStatesCount = deviceStates.size();

    if(deviceStatesCount == 0)
      throw new DiabloMinerFatalException("No OpenCL devices found");

    long previousHashCount = 0;
    double previousAdjustedHashCount = 0.0;
    long previousAdjustedStartTime = startTime = (getNow()) - 1;
    StringBuilder hashMeter = new StringBuilder(80);
    Formatter hashMeterFormatter = new Formatter(hashMeter);

    while(running.get()) {
      for(int i = 0; i < deviceStatesCount; i++)
        deviceStates.get(i).checkDevice();

      long now = getNow();
      long currentHashCount = hashCount.get();
      double adjustedHashCount = (double)(currentHashCount - previousHashCount) / (double)(now - previousAdjustedStartTime);
      double hashLongCount = (double)currentHashCount / (double)(now - startTime) / 1000.0;

      if(now - startTime > TIME_OFFSET * 2) {
        double averageHashCount = (double)(adjustedHashCount + previousAdjustedHashCount) / 2.0 / 1000.0;

        hashMeter.setLength(0);

        if(!debug) {
          hashMeterFormatter.format("\rmhash: %.1f/%.1f | accept: %d | reject: %d | hw error: %d",
                averageHashCount, hashLongCount, currentBlocks.get(), currentRejects.get(), currentHWErrors.get());
        } else {
          hashMeterFormatter.format("\rmh: %.1f/%.1f | a/r/hwe: %d/%d/%d | gh: ",
                averageHashCount, hashLongCount, currentBlocks.get(), currentRejects.get(), currentHWErrors.get());

          double basisAverage = 0.0;

          for(int i = 0; i < deviceStates.size(); i++) {
            DeviceState deviceState = deviceStates.get(i);

            hashMeterFormatter.format("%.1f ", deviceState.deviceHashCount.get() / 1000.0 / 1000.0 / 1000.0);
            basisAverage += deviceState.basis;
          }

          basisAverage = 1000 / (basisAverage / deviceStates.size() * EXECUTION_TOTAL);

          hashMeterFormatter.format("| fps: %.1f", basisAverage);
        }

        System.out.print(hashMeter);
      } else {
        System.out.print("\rWaiting...");
      }

      if(getNow() - TIME_OFFSET * 2 > previousAdjustedStartTime) {
        previousHashCount = currentHashCount;
        previousAdjustedHashCount = adjustedHashCount;
        previousAdjustedStartTime = now - 1;
      }

      if(debugtimer && getNow() > startTime + 60 * 1000) {
        System.out.print("\n");
        info("Debug timer is up, quitting...");
        System.exit(0);
      }

      try {
        if(now - startTime > TIME_OFFSET)
          Thread.sleep(1000);
        else
          Thread.sleep(1);
      } catch (InterruptedException e) { }
    }
  }

  static int rot(int x, int y) {
    return (x >>> y) | (x << (32 - y));
  }

  static void sharound(int out[], int na, int nb, int nc, int nd, int ne, int nf, int ng, int nh, int x, int K) {
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

  static String getDateTime() {
    return "[" + DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.MEDIUM).format(new Date()) + "]";
  }

  long getNow() {
    return System.nanoTime() / 1000000;
  }

  void info(String msg) {
    System.out.println("\r" + CLEAR + "\r" + getDateTime() + " " + msg);
    threads.get(0).interrupt();
  }

  void debug(String msg) {
    if(debug) {
      System.out.println("\r" + CLEAR + "\r" + getDateTime() + " DEBUG: " + msg);
      threads.get(0).interrupt();
    }
  }

  void edebug(String msg) {
    if(edebug) {
      System.out.println("\r" + CLEAR + "\r" + getDateTime() + " DEBUG: " + msg);
      threads.get(0).interrupt();
    }
  }

  void error(String msg) {
    System.err.println("\r" + CLEAR + "\r" + getDateTime() + " ERROR: " + msg);
    threads.get(0).interrupt();
  }


  class DiabloMinerFatalException extends Exception {
    public DiabloMinerFatalException(String reason) {
      super(reason);
      error(reason);
      running.set(false);

      for(int i = 0; i < threads.size(); i++) {
        Thread thread = threads.get(i);
        if(thread != Thread.currentThread())
          thread.interrupt();
      }
    }

    private static final long serialVersionUID = -9022549833049053386L;
  }

  class NetworkState {
    URL queryUrl;
    URL longPollUrl;
    String userPass;
    int index;

    final GetWorkAsync getWorkAsync = this.new GetWorkAsync();
    final SendWorkAsync sendWorkAsync = this.new SendWorkAsync();
    LongPollAsync longPollAsync = null;
    int refresh;
    boolean rollNTime = false;
    boolean noDelay = false;
    String rejectReason = null;

    NetworkState(URL url, String user, String pass, int index) {
      this.queryUrl = url;
      this.userPass = "Basic " + Base64.encodeBase64String((user + ":" + pass).getBytes()).trim().replace("\r\n", "");
      this.index = index;
      this.refresh = getWorkRefresh;

      Thread thread = new Thread(getWorkAsync, "DiabloMiner GetWorkAsync for " + url.getHost());
      thread.start();
      threads.add(thread);

      thread = new Thread(sendWorkAsync, "DiabloMiner SendWorkAsync for " + url.getHost());
      thread.start();
      threads.add(thread);
    }

    JsonNode doJSONRPC(boolean longPoll, boolean sendWork, ObjectNode requestMessage) throws IOException {
      HttpURLConnection connection;
      URL url;

      if(longPoll)
        url = longPollUrl;
      else
        url = queryUrl;

      if(proxy == null)
        connection = (HttpURLConnection) url.openConnection();
      else
        connection = (HttpURLConnection) url.openConnection(proxy);

      if(longPoll) {
        connection.setConnectTimeout(10 * 60 * 1000);
        connection.setReadTimeout(10 * 60 * 1000);
      } else {
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(15000);
      }

      connection.setRequestProperty("Authorization", userPass);
      connection.setRequestProperty("Accept", "application/json");
      connection.setRequestProperty("Accept-Encoding", "gzip,deflate");
      connection.setRequestProperty("Content-Type", "application/json");
      connection.setRequestProperty("Cache-Control", "no-cache");
      connection.setRequestProperty("User-Agent", "DiabloMiner");
      connection.setRequestProperty("X-Mining-Extensions", "longpoll rollntime switchto");
      connection.setDoOutput(true);

      OutputStream requestStream = connection.getOutputStream();
      Writer request = new OutputStreamWriter(requestStream);
      request.write(requestMessage.toString());
      request.close();
      requestStream.close();

      ObjectNode responseMessage = null;

      InputStream responseStream = null;

      try {
        if(!sendWork) {
          String xLongPolling = connection.getHeaderField("X-Long-Polling");

          if(xLongPolling != null && !"".equals(xLongPolling)) {
            if(xLongPolling.startsWith("http"))
              longPollUrl = new URL(xLongPolling);
            else if(xLongPolling.startsWith("/"))
              longPollUrl = new URL(queryUrl.getProtocol(), queryUrl.getHost(), queryUrl.getPort(),
                    xLongPolling);
            else
              longPollUrl = new URL(queryUrl.getProtocol(), queryUrl.getHost(), queryUrl.getPort(),
                    (url.getFile() + "/" + xLongPolling).replace("//", "/"));

            if(longPollAsync == null) {
              longPollAsync = new LongPollAsync();
              Thread thread = new Thread(longPollAsync, "DiabloMiner LongPollAsync for " + url.getHost());
              thread.start();
              threads.add(thread);

              refresh = 60000;

              debug(queryUrl.getHost() + ": Enabling long poll support");
            }
          }

          if(!rollNTime) {
            String xRollNTime = connection.getHeaderField("X-Roll-NTime");

            if(xRollNTime != null && !"n".equalsIgnoreCase(xRollNTime)) {
              rollNTime = true;

              if(xRollNTime.startsWith("expire=")) {
                try {
                  refresh = Integer.parseInt(xRollNTime.substring(7))  * 1000;
                } catch (NumberFormatException ex) { }
              } else {
                refresh = 60000;
              }

              debug(queryUrl.getHost() + ": Enabling roll ntime support, expire after " + (refresh / 1000) + " seconds");
            }
          } else {
            String xRollNTime = connection.getHeaderField("X-Roll-NTime");

            if(xRollNTime == null) {
              rollNTime = false;

              if(longPoll)
                refresh = 60000;
              else
                refresh = getWorkRefresh;

              debug(queryUrl.getHost() + ": Disabling roll ntime support");
            }
          }
        }

        String xSwitchTo = connection.getHeaderField("X-Switch-To");

        if(xSwitchTo != null &&  !"".equals(xSwitchTo)) {
          String oldHost = queryUrl.getHost();
          JsonNode newHost = mapper.readTree(xSwitchTo);

          queryUrl = new URL(queryUrl.getProtocol(), newHost.get("host").asText(),
                newHost.get("port").getIntValue(), queryUrl.getPath());

          if(longPollUrl != null)
            longPollUrl = new URL(longPollUrl.getProtocol(), newHost.get("host").asText(),
                  newHost.get("port").getIntValue(), longPollUrl.getPath());

          info(oldHost + ": Switched to " + queryUrl.getHost());
        }

        String xRejectReason = connection.getHeaderField("X-Reject-Reason");

        if(xRejectReason != null && !"".equals(xRejectReason)) {
          rejectReason = xRejectReason;
        }

        String xIsP2Pool = connection.getHeaderField("X-Is-P2Pool");

        if(xIsP2Pool != null && !"".equals(xIsP2Pool)) {
          if(!noDelay)
            info("P2Pool no delay mode enabled");

          noDelay = true;
        }

        if(connection.getContentEncoding() != null) {
          if(connection.getContentEncoding().equalsIgnoreCase("gzip"))
            responseStream = new GZIPInputStream(connection.getInputStream());
          else if(connection.getContentEncoding().equalsIgnoreCase("deflate"))
            responseStream = new InflaterInputStream(connection.getInputStream());
        } else {
          responseStream = connection.getInputStream();
        }

        if(responseStream == null)
          throw new IOException("Drop to error handler");

        Object output = mapper.readTree(responseStream);

        if(NullNode.class.equals(output.getClass()))
          throw new IOException("Bitcoin returned unparsable JSON") ;
        else
          responseMessage = (ObjectNode) output;

        responseStream.close();
      } catch (JsonProcessingException e) {
        throw new IOException("Bitcoin returned unparsable JSON");
      } catch (IOException e) {
        InputStream errorStream = null;
        IOException e2 = null;

        if(connection.getErrorStream() == null)
          throw new IOException("Bitcoin disconnected during response: "
                + connection.getResponseCode() + " " + connection.getResponseMessage());

        if(connection.getContentEncoding() != null) {
          if(connection.getContentEncoding().equalsIgnoreCase("gzip"))
            errorStream = new GZIPInputStream(connection.getErrorStream());
          else if(connection.getContentEncoding().equalsIgnoreCase("deflate"))
            errorStream = new InflaterInputStream(connection.getErrorStream());
        } else {
          errorStream = connection.getErrorStream();
        }

        if(errorStream == null)
          throw new IOException("Bitcoin disconnected during response: "
              + connection.getResponseCode() + " " + connection.getResponseMessage());

        byte[] errorbuf = new byte[8192];

        if(errorStream.read(errorbuf) < 1)
          throw new IOException("Bitcoin returned an error, but with no message");

        String error = new String(errorbuf).trim();

        if(error.startsWith("{")) {
          try {
            Object output = mapper.readTree(error);

            if(NullNode.class.equals(output.getClass()))
              throw new IOException("Bitcoin returned an error message: " + error);
            else
              responseMessage = (ObjectNode) output;

            if(responseMessage.get("error") != null) {
              if(responseMessage.get("error").get("message") != null &&
                    responseMessage.get("error").get("message").asText() != null) {
                error = responseMessage.get("error").get("message").asText().trim();
                e2 = new IOException("Bitcoin returned error message: " + error);
              } else if(responseMessage.get("error").asText() != null) {
                error = responseMessage.get("error").asText().trim();

                if(!"null".equals(error) && !"".equals(error))
                  e2 = new IOException("Bitcoin returned an error message: " + error);
              }
            }
          } catch(JsonProcessingException f) {
            e2 = new IOException("Bitcoin returned unparsable JSON");
          }
        } else {
          e2 = new IOException("Bitcoin returned an error message: " + error);
        }

        errorStream.close();

        if(responseStream != null)
          responseStream.close();

        if(e2 == null)
          e2 = new IOException("Bitcoin returned an error, but with no message");

        throw e2;
      }

      if(responseMessage.get("error") != null) {
        if(responseMessage.get("error").get("message") != null &&
              responseMessage.get("error").get("message").asText() != null) {
          String error = responseMessage.get("error").get("message").asText().trim();
            throw new IOException("Bitcoin returned error message: " + error);
        } else if(responseMessage.get("error").asText() != null) {
          String error = responseMessage.get("error").asText().trim();

          if(!"null".equals(error) && !"".equals(error))
            throw new IOException("Bitcoin returned error message: " + error);
        }
      }

      JsonNode result;

      try {
        result = responseMessage.get("result");
      } catch(Exception e) {
        throw new IOException("Bitcoin returned unparsable JSON");
      }

      if(result == null)
        throw new IOException("Bitcoin did not return a result or an error");

      return result;
    }

    void forceUpdate() {
      ExecutionState[] executions;

      for(int i = 0; i < deviceStatesCount; i++) {
        executions = deviceStates.get(i).executions;
        for(int j = 0; j < EXECUTION_TOTAL; j++) {
          GetWorkParser getWorkParser = executions[j].currentWork;
          if(getWorkParser != null && this.equals(getWorkParser.networkState))
            getWorkParser.lastPulled = 0;
        }
      }

      sendWorkAsync.sendWorkQueue.clear();
    }

    class GetWorkItem {
      JsonNode json;
      boolean rollNtime;
      long pulled = getNow();

      GetWorkItem(JsonNode json, boolean rollNTime) {
        this.json = json;
        this.rollNtime = rollNTime;
      }
    }

    class SendWorkItem {
      ObjectNode message;
      String deviceName;
      GetWorkParser getWork;

      SendWorkItem(ObjectNode message, String deviceName, GetWorkParser getWork) {
        this.message = message;
        this.deviceName = deviceName;
        this.getWork = getWork;
      }
    }

    class GetWorkAsync implements Runnable {
      LinkedBlockingDeque<GetWorkParser> getWorkQueue = new LinkedBlockingDeque<GetWorkParser>();
      AtomicReference<GetWorkItem> queueIncoming = new AtomicReference<GetWorkItem>(null);

      public void run() {
        while(running.get()) {
          GetWorkParser getWorkParser = null;

          if(queueIncoming.get() == null) {
            try {
              GetWorkItem getWorkItem = new GetWorkItem(doJSONRPC(false, false, getWorkMessage), rollNTime);
              queueIncoming.compareAndSet(null, getWorkItem);
            } catch (IOException e) {
              error("Cannot connect to " + queryUrl.getHost() + ": " + e.getLocalizedMessage());
            }
          }

          try {
            getWorkParser = getWorkQueue.take();
          } catch (InterruptedException e) {
            continue;
          }

          if(getWorkParser != null) {
            if(getWorkParser.resetTime < getNow() - 100 * 60 * 1000) {
              getWorkParser.networkState = networkStates[0];
              getWorkParser.networkState.getWorkAsync.add(getWorkParser);
              getWorkParser.resetTime = getNow();
            } else if(donate && getWorkParser.networkState.index == 0 &&
                  getWorkParser.resetTime < getNow() - 60 * 1000){
                getWorkParser.networkState = networkStates[1];
                getWorkParser.networkState.getWorkAsync.add(getWorkParser);
                getWorkParser.resetTime = getNow();
            }

            if(queueIncoming.get() != null) {
              GetWorkItem getWorkItem = queueIncoming.getAndSet(null);

              if(getWorkItem.pulled + refresh + 1000 > getNow()) {
                getWorkParser.getWorkIncoming.push(getWorkItem);
              } else {
                getWorkQueue.push(getWorkParser);
              }
            } else {
              if(getWorkParser.networkState.index < networkStatesCount - 1)
                getWorkParser.networkState = networkStates[getWorkParser.networkState.index + 1];
              else
                getWorkParser.networkState = networkStates[0];

              getWorkParser.networkState.getWorkAsync.add(getWorkParser);

              try {
                if(!noDelay)
                  Thread.sleep(250);
              } catch (InterruptedException e1) { }
            }
          }
        }
      }

      void add(GetWorkParser getWorkParser) {
        if(!getWorkQueue.contains(getWorkParser))
          getWorkQueue.add(getWorkParser);
      }
    }

    class SendWorkAsync implements Runnable {
      LinkedBlockingDeque<SendWorkItem> sendWorkQueue = new LinkedBlockingDeque<SendWorkItem>();

      public void run() {
        while(running.get()) {
          SendWorkItem sendWorkItem = null;
          boolean error = false;

          try {
            sendWorkItem = sendWorkQueue.take();
          } catch (InterruptedException e) {
            continue;
          }

          while(sendWorkItem != null) {
            try {
              boolean accepted = doJSONRPC(false, true, sendWorkItem.message).getBooleanValue();

              if(accepted) {
                info(queryUrl.getHost() + " accepted block " + currentBlocks.incrementAndGet() + " from " + sendWorkItem.deviceName);
              } else {
                info(queryUrl.getHost() + " rejected block " + currentRejects.incrementAndGet() + " from " + sendWorkItem.deviceName);
                edebug("Rejected block " + (float)((getNow() - sendWorkItem.getWork.lastPulled) / 1000.0) +
                      " seconds old, roll ntime set to " + sendWorkItem.getWork.rollNTime + ", rolled " +
                      sendWorkItem.getWork.rolledNTime + " times");
                sendWorkItem.getWork.networkState.getWorkAsync.add(sendWorkItem.getWork);
              }

              if(rejectReason != null) {
                info("Reject reason: " + rejectReason);
                rejectReason = null;
              }

              sendWorkItem = null;
            } catch (IOException e) {
              if(!error) {
                error("Cannot connect to " + queryUrl.getHost() + ": " + e.getLocalizedMessage());
                error = true;
              }

              try {
                if(!noDelay)
                  Thread.sleep(250);
              } catch (InterruptedException f) { }
            }
          }
        }
      }

      void add(ObjectNode json, String deviceName, GetWorkParser getWork) {
        sendWorkQueue.add(new SendWorkItem(json, deviceName, getWork));
      }
    }

    class LongPollAsync implements Runnable {
      public void run() {
        while(running.get()) {
          try {
            GetWorkItem getWorkItem = new GetWorkItem(doJSONRPC(true, false, getWorkMessage), rollNTime);
            getWorkAsync.queueIncoming.set(getWorkItem);
            debug(queryUrl.getHost() + ": Long poll returned");
          } catch(IOException e) {
            error("Cannot connect to " + queryUrl.getHost() + ": " + e.getLocalizedMessage());
          }

          forceUpdate();

          try {
            if(!noDelay)
              Thread.sleep(250);
          } catch (InterruptedException e) {}
        }
      }
    }
  }

  class DeviceState {
    final String deviceName;

    final CLDevice device;
    final CLContext context;

    final CLKernel kernel;

    long workSize;
    long workSizeBase;
    double basis;

    final PointerBuffer localWorkSize = BufferUtils.createPointerBuffer(1);

    final ExecutionState executions[] = new ExecutionState[EXECUTION_TOTAL];

    AtomicLong deviceHashCount = new AtomicLong(0);

    AtomicLong runs = new AtomicLong(0);
    long lastRuns = 0;
    long lastTime = startTime;

    int loops = 1;

    DeviceState(CLPlatform platform, CLDevice device, int count) throws Exception {
      boolean hasBitAlign;
      boolean hasBFI_INT = false;
      CLProgram program;

      this.device = device;

      PointerBuffer properties = BufferUtils.createPointerBuffer(3);
      properties.put(CL10.CL_CONTEXT_PLATFORM).put(platform.getPointer()).put(0).flip();
      int err = 0;

      deviceName = device.getInfoString(CL10.CL_DEVICE_NAME).trim() + " (#" + count + ")";
      int deviceCU = device.getInfoInt(CL10.CL_DEVICE_MAX_COMPUTE_UNITS);
      long deviceWorkSize = device.getInfoSize(CL10.CL_DEVICE_MAX_WORK_GROUP_SIZE);

      context = CL10.clCreateContext(properties, device, new CLContextCallback() {
        protected void handleMessage(String errinfo, ByteBuffer private_info) {
          error(errinfo);
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
        if(deviceName.contains("Cedar")      ||
           deviceName.contains("Redwood")    ||
           deviceName.contains("Juniper")    ||
           deviceName.contains("Cypress")    ||
           deviceName.contains("Hemlock")    ||
           deviceName.contains("Caicos")     ||
           deviceName.contains("Turks")      ||
           deviceName.contains("Barts")      ||
           deviceName.contains("Cayman")     ||
           deviceName.contains("Antilles")   ||
           deviceName.contains("Palm")       ||
           deviceName.contains("Sumo")       ||
           deviceName.contains("Wrestler")   ||
           deviceName.contains("WinterPark") ||
           deviceName.contains("BeaverCreek"))
          hasBFI_INT = true;
      }

      if(zloops > 1)
        loops = zloops;
      else if(zloops <= 1)
        loops = 1;

      String compileOptions = "";

      if(forceWorkSize > 0)
        compileOptions = " -D WORKSIZE=" + forceWorkSize;
      else
        compileOptions = " -D WORKSIZE=" + deviceWorkSize;

      if(hasBitAlign)
        compileOptions += " -D BITALIGN";

      if(hasBFI_INT)
        compileOptions += " -D BFIINT";

      if(loops > 1) {
        compileOptions += " -D DOLOOPS";
        compileOptions += " -D LOOPS=" + loops;
      }

      if(vstore) {
        compileOptions += " -D VSTORE";
      }

      program = CL10.clCreateProgramWithSource(context, source, null);

      err = CL10.clBuildProgram(program, device, compileOptions, null);
      if(err != CL10.CL_SUCCESS) {
        ByteBuffer logBuffer = BufferUtils.createByteBuffer(1024);
        byte[] log = new byte[1024];

        CL10.clGetProgramBuildInfo(program, device, CL10.CL_PROGRAM_BUILD_LOG, logBuffer, null);

        logBuffer.get(log);

        System.out.println(new String(log));

        throw new DiabloMinerFatalException("Failed to build program on " + deviceName);
      }

      if(hasBFI_INT) {
        info("BFI_INT patching enabled, disabling hardware check errors");
        hwcheck = false;

        int binarySize = (int)program.getInfoSizeArray(CL10.CL_PROGRAM_BINARY_SIZES)[0];

        ByteBuffer binary = BufferUtils.createByteBuffer(binarySize);
        program.getInfoBinaries(binary);

        for(int pos = 0; pos < binarySize - 4; pos++) {
          if((long)(0xFFFFFFFF & binary.getInt(pos)) == 0x464C457FL &&
             (long)(0xFFFFFFFF & binary.getInt(pos + 4)) == 0x64010101L) {
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

              if((long)(0xFFFFFFFF & binary.getInt(name)) == 0x7865742E) {
                if(firstText) {
                  firstText = false;
                } else {
                  int sectionStart = pos + offset;
                  for(int i = 0; i < size / 8; i++) {
                    long instruction1 = (long)(0xFFFFFFFF & binary.getInt(sectionStart + i * 8));
                    long instruction2 = (long)(0xFFFFFFFF & binary.getInt(sectionStart + i * 8 + 4));

                    if((instruction1 & 0x02001000L) == 0x00000000L &&
                       (instruction2 & 0x9003F000L) == 0x0001A000L) {
                      instruction2 ^= (0x0001A000L ^ 0x0000C000L);

                      binary.putInt(sectionStart + i * 8 + 4, (int)instruction2);
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
          throw new DiabloMinerFatalException("Failed to BFI_INT patch kernel on " + deviceName);
        }
      }

      kernel = CL10.clCreateKernel(program, "search", null);
      if(kernel == null) {
        throw new DiabloMinerFatalException("Failed to create kernel on " + deviceName);

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

      info("Added " + deviceName + " (" + deviceCU + " CU, local work size of " + localWorkSize.get(0) + ")");

      workSizeBase = 64 * 512;

      workSize = workSizeBase * 16;

      for(int i = 0; i < EXECUTION_TOTAL; i++) {
        executions[i] = this.new ExecutionState();
        Thread thread = new Thread(executions[i], "DiabloMiner Executor (" + deviceName + "/" + i + ")");
        thread.start();
        threads.add(thread);
      }
    }

    void checkDevice() {
      long now = getNow();
      long elapsed = now - lastTime;
      long currentRuns = runs.get();

      if(now > startTime + TIME_OFFSET * 2 && currentRuns > lastRuns + targetFPS) {
        basis = (double)elapsed / (double)(currentRuns - lastRuns);

        if(basis < targetFPSBasis / EXECUTION_TOTAL * 1.5)
          workSize += workSizeBase * EXECUTION_TOTAL * 5;
        else if(basis < targetFPSBasis / EXECUTION_TOTAL)
          workSize += workSizeBase * EXECUTION_TOTAL * 3;
        else if(basis < targetFPSBasis)
          workSize += workSizeBase;
        else if(basis > targetFPSBasis * EXECUTION_TOTAL * 1.5)
          workSize -= workSizeBase * EXECUTION_TOTAL * 5;
        else if(basis > targetFPSBasis * EXECUTION_TOTAL)
          workSize -= workSizeBase * EXECUTION_TOTAL * 3;
        else if(basis > targetFPSBasis)
          workSize -= workSizeBase;

        if(workSize < workSizeBase)
          workSize = workSizeBase;
        else if(workSize > TWO32 / zloops / totalVectors - 1)
          workSize = TWO32 / zloops / totalVectors - 1;

        lastRuns = currentRuns;
        lastTime = now;
      }
    }

    class ExecutionState implements Runnable {
      final CLCommandQueue queue;
      ByteBuffer buffer[] = new ByteBuffer[2];
      final CLMem output[] = new CLMem[2];
      int bufferIndex = 0;

      final int[] midstate2 = new int[16];

      final MessageDigest digestInside = MessageDigest.getInstance("SHA-256");
      final MessageDigest digestOutside = MessageDigest.getInstance("SHA-256");
      final ByteBuffer digestInput = ByteBuffer.allocate(80);
      byte[] digestOutput;

      GetWorkParser currentWork;

      final PointerBuffer workSizeTemp = BufferUtils.createPointerBuffer(1);

      final IntBuffer errBuf = BufferUtils.createIntBuffer(1);
      int err;

      ExecutionState() throws NoSuchAlgorithmException, DiabloMinerFatalException {
        queue = CL10.clCreateCommandQueue(context, device, 0, errBuf);

        if(queue == null || errBuf.get(0) != CL10.CL_SUCCESS) {
          throw new DiabloMinerFatalException("Failed to allocate queue");
        }

        buffer[0] = BufferUtils.createByteBuffer(4 * OUTPUTS);
        buffer[1] = BufferUtils.createByteBuffer(4 * OUTPUTS);

        for(int i = 0; i < 2; i++) {
          output[i] = CL10.clCreateBuffer(context, CL10.CL_MEM_WRITE_ONLY, 4 * OUTPUTS, errBuf);

          if(output == null || errBuf.get(0) != CL10.CL_SUCCESS) {
            throw new DiabloMinerFatalException("Failed to allocate output buffer");
          }

          buffer[i].put(EMPTY_BUFFER, 0, 4 * OUTPUTS);
          buffer[i].position(0);

          CL10.clEnqueueWriteBuffer(queue, output[i], CL10.CL_FALSE, 0, buffer[i], null, null);
        }
      }

      public void run() {
        boolean submittedBlock;
        boolean resetBuffer;
        boolean skip = false;

        currentWork = this.new GetWorkParser();

        while(running.get()) {
          submittedBlock = false;
          resetBuffer = false;

          if(skip == false) {
            boolean hwError = false;

            for(int z = 0; z < OUTPUTS; z++) {
              int nonce = buffer[bufferIndex].getInt(z * 4);

              if(nonce != 0) {
                for(int j = 0; j < 19; j++)
                  digestInput.putInt(j*4, currentWork.data[j]);

                digestInput.putInt(19*4, nonce);

                digestOutput = digestOutside.digest(digestInside.digest(digestInput.array()));

                long G =
                      ((long)(0xFF & digestOutput[27]) << 24) |
                      ((long)(0xFF & digestOutput[26]) << 16) |
                      ((long)(0xFF & digestOutput[25]) << 8) |
                      ((long)(0xFF & digestOutput[24]));

                long H =
                      ((long)(0xFF & digestOutput[31]) << 24) |
                      ((long)(0xFF & digestOutput[30]) << 16) |
                      ((long)(0xFF & digestOutput[29]) << 8)  |
                      ((long)(0xFF & digestOutput[28]));

                if(H == 0) {
                  edebug("Attempt " + currentAttempts.incrementAndGet() + " from " + deviceName);

                  if(currentWork.target[7] != 0 || G <= currentWork.target[6]) {
                    currentWork.sendWork(nonce);
                    submittedBlock = true;
                  }
                } else {
                  hwError = true;
                }

                resetBuffer = true;
              }
            }

            if(hwError && submittedBlock == false) {
              if(hwcheck)
                error("Invalid solution " + currentHWErrors.incrementAndGet() + " from " + deviceName + ", possible driver or hardware issue");
              else
                edebug("Invalid solution " + currentHWErrors.incrementAndGet() + " from " + deviceName + ", possible driver or hardware issue");
            }

            if(resetBuffer) {
              buffer[bufferIndex].put(EMPTY_BUFFER, 0, 4 * OUTPUTS);
              buffer[bufferIndex].position(0);
              CL10.clEnqueueWriteBuffer(queue, output[bufferIndex], CL10.CL_FALSE, 0, buffer[bufferIndex], null, null);
            }

            if(submittedBlock) {
              if(currentWork.networkState.longPollAsync == null) {
                edebug("Forcing getwork update due to block submission");
                currentWork.networkState.forceUpdate();
              }
            }
          }

          skip = false;

          bufferIndex = (bufferIndex == 0) ? 1 : 0;

          workSizeTemp.put(0, workSize);
          currentWork.update(workSizeTemp.get(0) * loops * totalVectors);

          System.arraycopy(currentWork.midstate, 0, midstate2, 0, 8);

          sharound(midstate2, 0, 1, 2, 3, 4, 5, 6, 7, currentWork.data[16], 0x428A2F98);
          sharound(midstate2, 7, 0, 1, 2, 3, 4, 5, 6, currentWork.data[17], 0x71374491);
          sharound(midstate2, 6, 7, 0, 1, 2, 3, 4, 5, currentWork.data[18], 0xB5C0FBCF);

          int W16 = currentWork.data[16] + (rot(currentWork.data[17], 7) ^ rot(currentWork.data[17], 18) ^
                (currentWork.data[17] >>> 3));
          int W17 = currentWork.data[17] + (rot(currentWork.data[18], 7) ^ rot(currentWork.data[18], 18) ^
                (currentWork.data[18] >>> 3)) + 0x01100000;
          int W18 = currentWork.data[18] + (rot(W16, 17) ^ rot(W16, 19) ^ (W16 >>> 10)) ;
          int W19 = 0x11002000 + (rot(W17, 17) ^ rot(W17, 19) ^ (W17 >>> 10));
          int W31 = 0x00000280 + (rot(W16, 7) ^ rot(W16, 18) ^ (W16 >>> 3));
          int W32 = W16 + (rot(W17, 7) ^ rot(W17, 18) ^ (W17 >>> 3));

          int PreVal4 = currentWork.midstate[4] + (rot(midstate2[1], 6) ^ rot(midstate2[1], 11) ^ rot(midstate2[1], 25)) +
                (midstate2[3] ^ (midstate2[1] & (midstate2[2] ^ midstate2[3]))) + 0xe9b5dba5;
          int T1 = (rot(midstate2[5], 2) ^ rot(midstate2[5], 13) ^ rot(midstate2[5], 22)) + ((midstate2[5] & midstate2[6]) |
                (midstate2[7] & (midstate2[5] | midstate2[6])));

          int PreVal4_plus_state0 = PreVal4 + currentWork.midstate[0];
          int PreVal4_plus_T1 = PreVal4 + T1;
          int B1_plus_K6 = midstate2[1] + 0x923f82a4;
          int C1_plus_K5 = midstate2[2] + 0x59f111f1;

          kernel.setArg(0, currentWork.midstate[0])
                .setArg(1, currentWork.midstate[1])
                .setArg(2, currentWork.midstate[2])
                .setArg(3, currentWork.midstate[3])
                .setArg(4, currentWork.midstate[4])
                .setArg(5, currentWork.midstate[5])
                .setArg(6, currentWork.midstate[6])
                .setArg(7, currentWork.midstate[7])
                .setArg(8, midstate2[1])
                .setArg(9, midstate2[2])
                .setArg(10, midstate2[3] + 0xB956c25b)
                .setArg(11, midstate2[5])
                .setArg(12, midstate2[6])
                .setArg(13, midstate2[7])
                .setArg(14, (int)(currentWork.base / loops / totalVectors))
                .setArg(15, W16)
                .setArg(16, W17)
                .setArg(17, W18)
                .setArg(18, W19)
                .setArg(19, W31)
                .setArg(20, W32)
                .setArg(21, PreVal4_plus_state0)
                .setArg(22, PreVal4_plus_T1)
                .setArg(23, B1_plus_K6)
                .setArg(24, C1_plus_K5)
                .setArg(25, output[bufferIndex]);

          err = CL10.clEnqueueNDRangeKernel(queue, kernel, 1, null, workSizeTemp, localWorkSize, null, null);

          if(err !=  CL10.CL_SUCCESS && err != CL10.CL_INVALID_KERNEL_ARGS) {
            try {
              throw new DiabloMinerFatalException("Failed to queue kernel, error " + err);
            } catch (DiabloMinerFatalException e) {}
          } else {
            if(err != CL10.CL_SUCCESS) {
              debug("Spurious CL_INVALID_KERNEL_ARGS error, ignoring");
              skip = true;
            } else {
              err = CL10.clEnqueueReadBuffer(queue, output[bufferIndex], CL10.CL_TRUE, 0, buffer[bufferIndex], null, null);

              if(err != CL10.CL_SUCCESS)
                error("Failed to queue read buffer, error " + err);
            }

            long increment = workSizeTemp.get(0) * loops * totalVectors;

            hashCount.addAndGet(increment);
            deviceHashCount.addAndGet(increment);
            currentWork.base += increment;
            runs.incrementAndGet();
          }
        }
      }

      class GetWorkParser {
        final int[] data = new int[32];
        final int[] midstate = new int[8];
        final long[] target = new long[8];

        StringBuilder dataOutput = new StringBuilder(8*32 + 1);
        Formatter dataFormatter = new Formatter(dataOutput);

        long lastPulled = 1;
        long base = 0;
        boolean rollNTime = false;
        int rolledNTime = 0;

        NetworkState networkState = networkStates[0];
        LinkedBlockingDeque<GetWorkItem> getWorkIncoming = new LinkedBlockingDeque<GetWorkItem>();
        long resetTime;

        GetWorkParser() {
          getWork(false, true);
        }

        void update(long delta) {
          if(getWorkIncoming.peek() != null) {
            recieveWork();
          } else if(base + delta > TWO32) {
            getWork(true, true);
          } else if(getNow() - networkState.refresh >= lastPulled) {
            getWork(false, true);
          } else if(getNow() - networkState.refresh + 1000 >= lastPulled) {
            getWork(false, false);
          }
        }

        void recieveWork() {
          GetWorkItem workItem = null;

          while(workItem == null) {
            try {
              workItem = getWorkIncoming.take();
            } catch (InterruptedException e) { }
          }

          if(workItem != null) {
            parse(workItem.json);
            lastPulled = workItem.pulled;
            rollNTime = workItem.rollNtime;
            base = 0;
            rolledNTime = 0;
          }
        }

        void getWork(boolean nonceSaturation, boolean forceSync) {
          if(nonceSaturation) {
            if(rollNTime && networkState.rollNTime) {
              base = 0;
              data[17] = Integer.reverseBytes(Integer.reverseBytes(data[17]) + 1);
              rolledNTime++;

              if(rolledNTime * 1000 + 1000 < networkState.refresh) {
                debug("Deferring getwork update due to nonce saturation");
                return;
              } else if(rolledNTime * 1000 >= networkState.refresh) {
                debug("Forcing getwork update due to nonce saturation");
                forceSync = true;
              } else if(rolledNTime * 1000 + 1000 >= networkState.refresh) {
                if(debug && !networkState.getWorkAsync.getWorkQueue.contains(this))
                  debug("Async getwork update due to nonce saturation");
                nonceSaturation = false;
              }
            } else {
              debug("Forcing getwork update due to nonce saturation");
            }
          } else {
            if(!forceSync) {
              if(debug && !networkState.getWorkAsync.getWorkQueue.contains(this))
                debug("Async getwork update due to time");
            } else if(lastPulled == 0) {
              debug("Forcing getwork update due to long poll return");
            } else if(lastPulled != 1) {
              debug("Forcing getwork update due to time");
            }
          }

          networkState.getWorkAsync.add(this);

          if(nonceSaturation || forceSync)
            recieveWork();
        }

        void sendWork(int nonce) {
          data[19] = nonce;

          ObjectNode sendWorkMessage = mapper.createObjectNode();
          sendWorkMessage.put("method", "getwork");
          ArrayNode params = sendWorkMessage.putArray("params");
          params.add(encodeBlock());
          sendWorkMessage.put("id", 1);

          networkState.sendWorkAsync.add(sendWorkMessage, deviceName, this);
        }

        void parse(JsonNode responseMessage) {
          String datas = responseMessage.get("data").asText();
          String midstates = responseMessage.get("midstate").asText();
          String targets = responseMessage.get("target").asText();

          String parse;

          for(int i = 0; i < 32; i++) {
            parse = datas.substring(i*8, (i*8)+8);
            data[i] = Integer.reverseBytes((int)Long.parseLong(parse, 16));
          }

          for(int i = 0; i < 8; i++) {
            parse = midstates.substring(i*8, (i*8)+8);
            midstate[i] = Integer.reverseBytes((int)Long.parseLong(parse, 16));
          }

          for(int i = 0; i < 8; i++) {
            parse = targets.substring(i*8, (i*8)+8);
            target[i] = (Long.reverseBytes(Long.parseLong(parse, 16) << 16)) >>> 16;
          }
        }

        String encodeBlock() {
          dataOutput.setLength(0);

          dataFormatter.format(
                "%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x" +
                "%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x",
                Integer.reverseBytes(data[0]), Integer.reverseBytes(data[1]),
                Integer.reverseBytes(data[2]), Integer.reverseBytes(data[3]),
                Integer.reverseBytes(data[4]), Integer.reverseBytes(data[5]),
                Integer.reverseBytes(data[6]), Integer.reverseBytes(data[7]),
                Integer.reverseBytes(data[8]), Integer.reverseBytes(data[9]),
                Integer.reverseBytes(data[10]), Integer.reverseBytes(data[11]),
                Integer.reverseBytes(data[12]), Integer.reverseBytes(data[13]),
                Integer.reverseBytes(data[14]), Integer.reverseBytes(data[15]),
                Integer.reverseBytes(data[16]), Integer.reverseBytes(data[17]),
                Integer.reverseBytes(data[18]), Integer.reverseBytes(data[19]),
                Integer.reverseBytes(data[20]), Integer.reverseBytes(data[21]),
                Integer.reverseBytes(data[22]), Integer.reverseBytes(data[23]),
                Integer.reverseBytes(data[24]), Integer.reverseBytes(data[25]),
                Integer.reverseBytes(data[26]), Integer.reverseBytes(data[27]),
                Integer.reverseBytes(data[28]), Integer.reverseBytes(data[29]),
                Integer.reverseBytes(data[30]), Integer.reverseBytes(data[31]));

          return dataOutput.toString();
        }
      }
    }
  }
}
