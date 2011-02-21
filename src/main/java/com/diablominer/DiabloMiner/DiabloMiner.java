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

package com.diablominer.DiabloMiner;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.net.Authenticator;
import java.net.HttpURLConnection;
import java.net.InetSocketAddress;
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
import java.util.Date;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import java.util.zip.GZIPInputStream;
import java.util.zip.InflaterInputStream;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionBuilder;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.codec.binary.Base64;
import org.codehaus.jackson.JsonNode;
import org.codehaus.jackson.map.ObjectMapper;
import org.codehaus.jackson.node.ArrayNode;
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

class DiabloMiner {
  URL bitcoind;
  String userPass;
  float targetFPS = 60;
  int forceWorkSize = 64;
  boolean debug = false;
  int getworkRefresh = 5000;

  String source;

  boolean running = true;

  Proxy proxy = null;

  List<DeviceState> deviceStates = new ArrayList<DeviceState>();

  long startTime;

  AtomicLong hashCount = new AtomicLong(0);

  AtomicLong currentBlocks = new AtomicLong(0);
  AtomicLong currentAttempts = new AtomicLong(0);

  final static int EXECUTION_TOTAL = 3;
  final static long TIME_OFFSET = 7500;
  final static int LOOPS = 1024;
  final static int OUTPUTS = 256;

  public static void main(String [] args) throws Exception {
    DiabloMiner diabloMiner = new DiabloMiner();

    diabloMiner.execute(args);
  }

  void execute(String[] args) throws Exception {
    String user = "diablo";
    String pass = "miner";
    String ip = "127.0.0.1";
    String port = "8332";

    Options options = new Options();
    options.addOption("f", "fps", true, "target execution timing");
    options.addOption("w", "worksize", true, "override worksize");
    options.addOption("o", "host", true, "bitcoin host IP");
    options.addOption("r", "port", true," bitcoin host port");
    options.addOption("g", "getwork", true, "seconds between getwork refresh");
    options.addOption("x", "proxy", true, "optional proxy settings IP:PORT<:username:password>");
    options.addOption("d", "debug", false, "enable extra debug output");
    options.addOption("h", "help", false, "this help");

    Option option = OptionBuilder.create('u');
    option.setLongOpt("user");
    option.setArgs(1);
    option.setDescription("username for host");
    option.setRequired(true);
    options.addOption(option);

    option = OptionBuilder.create('p');
    option.setLongOpt("pass");
    option.setArgs(1);
    option.setDescription("password for host");
    option.setRequired(true);
    options.addOption(option);

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
      System.exit(0);
    }

    if(line.hasOption("user"))
      user = line.getOptionValue("user");

    if(line.hasOption("pass"))
      pass = line.getOptionValue("pass");

    if(line.hasOption("fps"))
      targetFPS = Float.parseFloat(line.getOptionValue("fps"));

    if(line.hasOption("worksize"))
      forceWorkSize = Integer.parseInt(line.getOptionValue("worksize"));

    if(line.hasOption("getwork"))
      getworkRefresh = Integer.parseInt(line.getOptionValue("getwork")) * 1000;

    if(line.hasOption("debug"))
      debug = true;

    if(line.hasOption("host"))
      ip = line.getOptionValue("host");

    if(line.hasOption("port"))
      port = line.getOptionValue("port");

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

    bitcoind = new URL("http://"+ ip + ":" + port + "/");
    userPass = "Basic " + Base64.encodeBase64String((user + ":" + pass).getBytes()).trim();

    InputStream stream = DiabloMiner.class.getResourceAsStream("/DiabloMiner.cl");
    byte[] data = new byte[64 * 1024];
    stream.read(data);
    source = new String(data).trim();
    stream.close();

    info("Started");

    CL.create();

    List<CLPlatform> platforms = CLPlatform.getPlatforms();

    if(platforms == null) {
      error("No OpenCL platforms found");
      System.exit(0);
    }

    int count = 1;

    for(CLPlatform platform : platforms) {
      List<CLDevice> devices = platform.getDevices(CL10.CL_DEVICE_TYPE_GPU | CL10.CL_DEVICE_TYPE_ACCELERATOR);

      if(devices == null) {
        error("OpenCL platform " + platform.getInfoString(CL10.CL_PLATFORM_NAME) + " contains no devices");
        System.exit(0);
      }

      for (CLDevice device : devices) {
        deviceStates.add(this.new DeviceState(platform, device, count));
        count++;
      }
    }

    long previousHashCount = 0;
    long previousAdjustedHashCount = 0;
    long previousAdjustedStartTime = startTime = (getNow()) - 1;

    while(running) {
      for(int i = 0; i < deviceStates.size(); i++)
        deviceStates.get(i).checkDevice();

      long now = getNow();
      long currentHashCount = hashCount.get();
      long adjustedHashCount = (currentHashCount - previousHashCount) / (now - previousAdjustedStartTime);
      long hashLongCount = currentHashCount / (now - startTime);

      if(now - startTime > TIME_OFFSET * 2) {
        long averageHashCount = (adjustedHashCount + previousAdjustedHashCount) / 2;
        System.out.print("\r" + averageHashCount + "/" + hashLongCount + " khash/sec");
      } else {
        System.out.print("\rWaiting...");
      }

      if(getNow() - TIME_OFFSET * 2 > previousAdjustedStartTime) {
        previousHashCount = currentHashCount;
        previousAdjustedHashCount = adjustedHashCount;
        previousAdjustedStartTime = now - 1;
      }

      try {
        if(now - startTime > TIME_OFFSET)
          Thread.sleep(1000);
        else
          Thread.sleep(1);
      } catch (InterruptedException e) {
        running = false;
      }
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

  void info(String msg) {
    System.out.println("\r" + getDateTime() + " " + msg);
  }

  void debug(String msg) {
    if(debug)
      System.out.println("\r" + getDateTime() + " DEBUG: " + msg);
  }

  void error(String msg) {
    System.err.println("\r" + getDateTime() + " ERROR: " + msg);
  }

  long getNow() {
    return System.nanoTime() / 1000000;
  }

  class DeviceState {
    final String deviceName;

    final CLDevice device;
    final CLContext context;

    final CLProgram program;
    final CLKernel kernel;

    long workSize;
    long workSizeBase;
    final PointerBuffer localWorkSize = BufferUtils.createPointerBuffer(1);

    final ExecutionState executions[] = new ExecutionState[EXECUTION_TOTAL];;

    AtomicLong runs = new AtomicLong(0);
    long lastRuns = 0;

    boolean hasBitAlign = false;
    int loops = 1;

    DeviceState(CLPlatform platform, CLDevice device, int count) throws Exception {
      this.device = device;

      PointerBuffer properties = BufferUtils.createPointerBuffer(3);
      properties.put(CL10.CL_CONTEXT_PLATFORM).put(platform.getPointer()).put(0).flip();
      int err = 0;

      deviceName = device.getInfoString(CL10.CL_DEVICE_NAME) + " (#" + count + ")";
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

      if(new String(exta).contains("cl_amd_media_ops")) {
        hasBitAlign = true;
        loops = LOOPS;
      }

      String compileOptions = "";

      if(hasBitAlign)
        compileOptions += " -D BITALIGN";

      if(loops > 1)
        compileOptions += " -D DOLOOPS";

      if(forceWorkSize > 0)
        compileOptions += " -D WORKGROUPSIZE=" + forceWorkSize;

      program = CL10.clCreateProgramWithSource(context, source, null);
      err = CL10.clBuildProgram(program, device, compileOptions, null);
      if(err != CL10.CL_SUCCESS) {
        ByteBuffer logBuffer = BufferUtils.createByteBuffer(1024);
        byte[] log = new byte[1024];

        CL10.clGetProgramBuildInfo(program, device, CL10.CL_PROGRAM_BUILD_LOG, logBuffer, null);

        logBuffer.get(log);

        System.out.println(new String(log));

        error("Failed to build program on " + deviceName);
        System.exit(0);
      }

      kernel = CL10.clCreateKernel(program, "search", null);
      if(kernel == null) {
        error("Failed to create kernel on " + deviceName);
        System.exit(0);
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

      workSizeBase = localWorkSize.get(0) * ((LOOPS + 1) - loops);
      workSize = workSizeBase;

      for(int i = 0; i < EXECUTION_TOTAL; i++) {
        executions[i] = this.new ExecutionState();
        new Thread(executions[i], "DiabloMiner Executor (" + deviceName + "/" + i + ")").start();
      }
    }

    void checkDevice() {
      long now = getNow();
      long elapsed = now - startTime;

      if(now > startTime + TIME_OFFSET && runs.get() > lastRuns + targetFPS) {
        float basis = elapsed / runs.get();
        float targetBasis = 1000 / (targetFPS * EXECUTION_TOTAL);

        if(basis < targetBasis / 2 && Integer.MAX_VALUE / loops > workSize + (workSizeBase * workSizeBase))
          workSize += workSizeBase * workSizeBase;
        else if(basis < targetBasis && Integer.MAX_VALUE / loops > workSize + workSizeBase)
          workSize += workSizeBase;
        else if(basis > targetBasis * 2 && workSize > (workSizeBase * workSizeBase) + workSizeBase)
          workSize -= workSizeBase * workSizeBase;
        else if(basis > targetBasis && workSize > workSizeBase + workSizeBase)
          workSize -= workSizeBase;

        if(workSize < workSizeBase)
          workSize = workSizeBase;

        lastRuns = runs.get();
      }
    }

    class ExecutionState implements Runnable {
      CLCommandQueue queue;
      final ByteBuffer buffer;
      final CLMem output;

      final int[] midstate2 = new int[16];

      final MessageDigest digestInside = MessageDigest.getInstance("SHA-256");
      final MessageDigest digestOutside = MessageDigest.getInstance("SHA-256");
      final ByteBuffer digestInput = ByteBuffer.allocate(80);
      byte[] digestOutput;

      final GetWorkParser currentWork;

      final PointerBuffer workSizeTemp = BufferUtils.createPointerBuffer(1);

      final IntBuffer errBuf = BufferUtils.createIntBuffer(1);
      int err;

      ExecutionState() throws NoSuchAlgorithmException {
        output = CL10.clCreateBuffer(context, CL10.CL_MEM_WRITE_ONLY, 4 * OUTPUTS, errBuf);
        buffer = BufferUtils.createByteBuffer(4 * OUTPUTS);
        buffer.putInt(0, 0);

        currentWork = this.new GetWorkParser();
      }

      public void run() {
        queue = CL10.clCreateCommandQueue(context, device, 0, errBuf);
        if(queue == null || errBuf.get(0) != CL10.CL_SUCCESS) {
          error("Failed to allocate queue");
          System.exit(0);
        }

        CL10.clEnqueueWriteBuffer(queue, output, CL10.CL_FALSE, 0, buffer, null, null);

        if(output == null || errBuf.get(0) != CL10.CL_SUCCESS) {
          error("Failed to allocate output buffer");
          System.exit(0);
        }

        while(running = true) {
          boolean submittedBlock = false;
          boolean updateBuffer = false;

          for(int z = 0; z < OUTPUTS; z++) {
            int nonce = buffer.getInt(z * 4);

            if(nonce > 0) {
              for(int j = 0; j < 19; j++)
                digestInput.putInt(j*4, currentWork.data[j]);

              digestInput.putInt(19*4, nonce);

              digestOutput = digestOutside.digest(digestInside.digest(digestInput.array()));

              long G = ((long)((0x000000FF & ((int)digestOutput[27])) << 24 |
                    (0x000000FF & ((int)digestOutput[26])) << 16 |
                    (0x000000FF & ((int)digestOutput[25])) << 8 |
                    (0x000000FF & ((int)digestOutput[24])))) & 0xFFFFFFFFL;

              long H = ((long)((0x000000FF & ((int)digestOutput[31])) << 24 |
                    (0x000000FF & ((int)digestOutput[30])) << 16 |
                    (0x000000FF & ((int)digestOutput[29])) << 8 |
                    (0x000000FF & ((int)digestOutput[28])))) & 0xFFFFFFFFL;

              debug("Attempt " + currentAttempts.incrementAndGet() + " found on " + deviceName);

              if(G <= currentWork.target[6]) {
                if(H == 0) {
                  if(currentWork.sendWork(nonce)) {
                    info("Block " + currentBlocks.incrementAndGet() + " found on " + deviceName);
                    debug("Header of " + currentWork.encodeBlock());
                  } else {
                    debug("Block found, but rejected by Bitcoin, on " + deviceName);
                  }

                  submittedBlock = true;
                } else {
                  error("Invalid block found on " + deviceName + ", possible driver or hardware issue");
                }
              }

              buffer.putInt(z * 4, 0);
              updateBuffer = true;
            }
          }

          if(updateBuffer == true)
            CL10.clEnqueueWriteBuffer(queue, output, CL10.CL_FALSE, 0, buffer, null, null);

          if(submittedBlock == true) {
            debug("Forcing getwork update due to block submission");
            currentWork.forceUpdate();
          }

          workSizeTemp.put(0, workSize);
          currentWork.update(workSizeTemp.get(0));

          System.arraycopy(currentWork.midstate, 0, midstate2, 0, 8);

          sharound(midstate2, 0, 1, 2, 3, 4, 5, 6, 7, currentWork.data[16], 0x428A2F98);
          sharound(midstate2, 7, 0, 1, 2, 3, 4, 5, 6, currentWork.data[17], 0x71374491);
          sharound(midstate2, 6, 7, 0, 1, 2, 3, 4, 5, currentWork.data[18], 0xB5C0FBCF);

          int fW0 = currentWork.data[16] + (rot(currentWork.data[17], 7) ^ rot(currentWork.data[17], 18) ^
                    (currentWork.data[17] >>> 3));
          int fW1 = currentWork.data[17] + (rot(currentWork.data[18], 7) ^ rot(currentWork.data[18], 18) ^
                    (currentWork.data[18] >>> 3)) + 0x01100000;
          int fW2 = currentWork.data[18] + (rot(fW0, 17) ^ rot(fW0, 19) ^ (fW0 >>> 10));
          int fW3 = 0x11002000 + (rot(fW1, 17) ^ rot(fW1, 19) ^ (fW1 >>> 10));
          int fW15 = 0x00000280 + (rot(fW0, 7) ^ rot(fW0, 18) ^ (fW0 >>> 3));
          int fW01r = fW0 + (rot(fW1, 7) ^ rot(fW1, 18) ^ (fW1 >>> 3));

          int fcty_e = currentWork.midstate[4] + (rot(midstate2[1], 6) ^ rot(midstate2[1], 11) ^ rot(midstate2[1], 25)) +
                       (midstate2[3] ^ (midstate2[1] & (midstate2[2] ^ midstate2[3]))) + 0xe9b5dba5;
          int fcty_e2 = (rot(midstate2[5], 2) ^ rot(midstate2[5], 13) ^ rot(midstate2[5], 22)) + ((midstate2[5] & midstate2[6]) |
                        (midstate2[7] & (midstate2[5] | midstate2[6])));

          kernel.setArg(0, fW0)
                .setArg(1, fW1)
                .setArg(2, fW2)
                .setArg(3, fW3)
                .setArg(4, fW15)
                .setArg(5, fW01r)
                .setArg(6, fcty_e)
                .setArg(7, fcty_e2)
                .setArg(8, currentWork.midstate[0])
                .setArg(9, currentWork.midstate[1])
                .setArg(10, currentWork.midstate[2])
                .setArg(11, currentWork.midstate[3])
                .setArg(12, currentWork.midstate[4])
                .setArg(13, currentWork.midstate[5])
                .setArg(14, currentWork.midstate[6])
                .setArg(15, currentWork.midstate[7])
                .setArg(16, midstate2[1])
                .setArg(17, midstate2[2])
                .setArg(18, midstate2[3])
                .setArg(19, midstate2[5])
                .setArg(20, midstate2[6])
                .setArg(21, midstate2[7])
                .setArg(22, (int) currentWork.base)
                .setArg(23, output);

          err = CL10.clEnqueueNDRangeKernel(queue, kernel, 1, null, workSizeTemp, localWorkSize, null, null);
          CL10.clEnqueueReadBuffer(queue, output, CL10.CL_TRUE, 0, buffer, null, null);

          if(err !=  CL10.CL_SUCCESS) {
            if(err != CL10.CL_INVALID_KERNEL_ARGS) {
              error("Failed to queue kernel, error " + err);
              System.exit(0);
            } else {
              debug("Spurious CL_INVALID_KERNEL_ARGS, ignoring");
            }
          } else {
            hashCount.addAndGet(workSizeTemp.get(0) * loops);
            currentWork.base += workSizeTemp.get(0);
            runs.incrementAndGet();
          }
        }
      }

      class GetWorkParser {
        final int[] data = new int[32];
        final int[] midstate = new int[8];
        final long[] target = new long[8];

        final ObjectMapper mapper = new ObjectMapper();
        final ObjectNode getworkMessage = mapper.createObjectNode();

        long lastPulled = 0;
        long base = 0;

        GetWorkParser() {
          getworkMessage.put("method", "getwork");
          getworkMessage.putArray("params");
          getworkMessage.put("id", 1);

          getWork();
        }

        void forceUpdate() {
          for(int i = 0; i < deviceStates.size(); i++) {
            for(int j = 0; j < EXECUTION_TOTAL; j++)
              deviceStates.get(i).executions[j].currentWork.lastPulled = 0;
          }
        }

        void update(long delta) {
          if(base + delta > Integer.MAX_VALUE / loops) {
            debug("Forcing getwork update due to nonce saturation");
            getWork();
          } else if(lastPulled + getworkRefresh < getNow()) {
            getWork();
          }
        }

        void getWork() {
          try {
            parse(doJSONRPC(bitcoind, userPass, mapper, getworkMessage));
          } catch(IOException e) {
            error("Can't connect to Bitcoin: " + e.getLocalizedMessage());
          }

          lastPulled = getNow();
          base = 0;
        }

        boolean sendWork(int nonce) {
          data[19] = nonce;

          ObjectNode sendworkMessage = mapper.createObjectNode();
          sendworkMessage.put("method", "getwork");
          ArrayNode params = sendworkMessage.putArray("params");
          params.add(encodeBlock());
          sendworkMessage.put("id", 1);

          try {
            return doJSONRPC(bitcoind, userPass, mapper, sendworkMessage).getBooleanValue();
          } catch(IOException e) {
            error("Can't connect to Bitcoin: " + e.getLocalizedMessage());
            return false;
          }
        }

        JsonNode doJSONRPC(URL bitcoind, String userPassword, ObjectMapper mapper, ObjectNode requestMessage) throws IOException {
        	HttpURLConnection connection;

          if(proxy == null)
            connection = (HttpURLConnection) bitcoind.openConnection();
          else
            connection = (HttpURLConnection) bitcoind.openConnection(proxy);

          connection.setRequestProperty("Authorization", userPassword);
          connection.setRequestProperty("Accept-Encoding", "gzip,deflate");
          connection.setDoOutput(true);

          OutputStream requestStream = connection.getOutputStream();
          Writer request = new OutputStreamWriter(requestStream);
          request.write(requestMessage.toString());
          request.close();
          requestStream.close();

          ObjectNode responseMessage = null;

          InputStream responseStream = null;

          try {
            if(connection.getContentEncoding() != null) {
              if(connection.getContentEncoding().equalsIgnoreCase("gzip"))
                responseStream = new GZIPInputStream(connection.getInputStream());
              else if(connection.getContentEncoding().equalsIgnoreCase("deflate"))
                responseStream = new InflaterInputStream(connection.getInputStream());
            } else {
              responseStream = connection.getInputStream();
            }

            if(responseStream == null)
              throw new IOException("Bitcoin disconnected during response");

            responseMessage = (ObjectNode) mapper.readTree(responseStream);
            responseStream.close();
          } catch (IOException e) {
            InputStream errorStream = null;

            if(connection.getContentEncoding() != null) {
              if(connection.getContentEncoding().equalsIgnoreCase("gzip"))
                errorStream = new GZIPInputStream(connection.getErrorStream());
              else if(connection.getContentEncoding().equalsIgnoreCase("deflate"))
                errorStream = new InflaterInputStream(connection.getErrorStream());
            } else {
              errorStream = connection.getErrorStream();
            }

            if(errorStream == null)
              throw new IOException("Bitcoin disconnected during response");

            byte[] error = new byte[1024];
            errorStream.read(error);

            errorStream.close();

            if(responseStream != null)
              responseStream.close();

            IOException e2 = new IOException("Failed to communicate with Bitcoin: " + new String(error).trim());
            e2.setStackTrace(e.getStackTrace());
            throw e2;
          }

          return responseMessage.get("result");
        }

        void parse(JsonNode responseMessage) {
          String datas = responseMessage.get("data").getValueAsText();
          String midstates = responseMessage.get("midstate").getValueAsText();
          String targets = responseMessage.get("target").getValueAsText();

          for(int i = 0; i < data.length; i++) {
            String parse = datas.substring(i*8, (i*8)+8);
            data[i] = Integer.reverseBytes((int)Long.parseLong(parse, 16));
          }

          for(int i = 0; i < midstate.length; i++) {
            String parse = midstates.substring(i*8, (i*8)+8);
            midstate[i] = Integer.reverseBytes((int)Long.parseLong(parse, 16));
          }

          for(int i = 0; i < target.length; i++) {
            String parse = targets.substring(i*8, (i*8)+8);
            target[i] = (Long.reverseBytes(Long.parseLong(parse, 16) << 16)) >>> 16;
          }
        }

        String encodeBlock() {
          StringBuilder builder = new StringBuilder();

          for(int d : data)
            builder.append(String.format("%08x", Integer.reverseBytes(d)));

          return builder.toString();
        }
      }
    }
  }
}
