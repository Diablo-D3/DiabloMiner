/*
 *  DiabloMiner - OpenCL miner for BitCoin
 *  Copyright (C) 2010 Patrick McFarland <diablod3@gmail.com>
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
import java.net.HttpURLConnection;
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
  int forceWorkSize = 0;
  boolean forceBitAlign = false;
  boolean debug = false;
  
  String source;

  boolean running = true;
  
  AtomicLong hashCount = new AtomicLong(0);
  
  List<DeviceState> deviceStates = new ArrayList<DeviceState>();
  long startTime;
  AtomicLong now = new AtomicLong(0);
  int currentBlocks = 1;
  int currentAttempts = 1;
  
  final static int EXECUTION_TOTAL = 3;
  final static long TIME_OFFSET = 15000;
  
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
    options.addOption("a", "bitalign", false, "force bitalign on for Radeon 5xxx + ATI SDK 2.1");
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

    if(line.hasOption("bitalign"))
      forceBitAlign = true;
    
    if(line.hasOption("debug"))
      debug = true;
    
    if(line.hasOption("host"))
      ip = line.getOptionValue("host");
    
    if(line.hasOption("port"))
      port = line.getOptionValue("port");
    
    bitcoind = new URL("http://"+ ip + ":" + port + "/");    
    userPass = "Basic " + Base64.encodeBase64String((user + ":" + pass).getBytes()).trim();
 
    InputStream stream = DiabloMiner.class.getResourceAsStream("/DiabloMiner.cl");
    byte[] data = new byte[64 * 1024];
    stream.read(data);
    source = new String(data).trim();
    stream.close();

    CL.create();

    List<CLPlatform> platforms = CLPlatform.getPlatforms();
      
    if(platforms == null)
      throw new Exception("No OpenCL platforms found.");
  
    int count = 1;
    
    for(CLPlatform platform : platforms) {         
      List<CLDevice> devices = platform.getDevices(CL10.CL_DEVICE_TYPE_GPU | CL10.CL_DEVICE_TYPE_ACCELERATOR);
        
      for (CLDevice device : devices) {
        deviceStates.add(this.new DeviceState(platform, device, count));
        count++;
      }
    }
    
    long previousCount = 0;
    long averageStartTime = startTime = System.nanoTime() / 1000000;
    now.set((long) startTime);

    for(int i = 0; i < deviceStates.size(); i++) {
      for(int j = 0; j < EXECUTION_TOTAL; j++)
        deviceStates.get(i).executions[j].threadStartTime = 
          deviceStates.get(i).executions[j].lastTime = now.get();
      
      deviceStates.get(i).checkDevice();
    }
    
    System.out.println("Started at " + DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.MEDIUM).format(new Date()));
    
    System.out.print("Waiting...");
    
    while(running) {     
      now.set(System.nanoTime() / 1000000);
      
      for(int i = 0; i < deviceStates.size(); i++)
        deviceStates.get(i).checkDevice();
            
      long adjustedCount = hashCount.get() / (now.get() - averageStartTime);
      
      if(now.get() - startTime > TIME_OFFSET) {
        long averageCount = (adjustedCount + previousCount) / 2;
        System.out.print("\r" + averageCount + " khash/sec");
      }
      
      if(now.get() - TIME_OFFSET > averageStartTime) {
        previousCount = adjustedCount;
        averageStartTime = now.get();
        hashCount.set(0);
      }
      
      try {
        if(now.get() - startTime < TIME_OFFSET) {
          Thread.sleep(1);
        } else {
          Thread.sleep(1000);
        }
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
  
  class DeviceState {
    final String deviceName;
 
    final CLDevice device;
    final CLContext context;

    final CLProgram program;
    final CLKernel kernel;

    long workSize;
    long workSizeMax;
    long workSizeBase;
    final PointerBuffer localWorkSize = BufferUtils.createPointerBuffer(1);
    
    final ExecutionState executions[];
        
    AtomicLong runs = new AtomicLong(0);
    AtomicLong runsThen = new AtomicLong(0);
    
    DeviceState(CLPlatform platform, CLDevice device, int count) throws Exception {
      this.device = device;
      
      PointerBuffer properties = BufferUtils.createPointerBuffer(3);
      properties.put(CL10.CL_CONTEXT_PLATFORM).put(platform.getPointer()).put(0).flip();
      int err = 0;
      
      deviceName = device.getInfoString(CL10.CL_DEVICE_NAME) + " (#" + count + ")";
      int deviceCU = device.getInfoInt(CL10.CL_DEVICE_MAX_COMPUTE_UNITS);
      long deviceWorkSize = device.getInfoSize(CL10.CL_DEVICE_MAX_WORK_GROUP_SIZE);

      System.out.print("Added " + deviceName + " (" + deviceCU + " CU, local work size of ");
      
      context = CL10.clCreateContext(properties, device, new CLContextCallback() {
        protected void handleMessage(String errinfo, ByteBuffer private_info) {
          System.err.println("\nERROR: " + errinfo);
        }
      }, null);

      String compileOptions = "";
      
      if(forceBitAlign)
        compileOptions += " -D FORCEBITALIGN";
      
      if(forceWorkSize > 0)
        compileOptions += " -D WORKGROUPSIZE=" + forceWorkSize;
      
      program = CL10.clCreateProgramWithSource(context, source, null);
      err = CL10.clBuildProgram(program, device, compileOptions, null);
      if(err != CL10.CL_SUCCESS) {
        System.out.println();

        ByteBuffer logBuffer = BufferUtils.createByteBuffer(1024);
        byte[] log = new byte[1024];
        
        CL10.clGetProgramBuildInfo(program, device, CL10.CL_PROGRAM_BUILD_LOG, logBuffer, null);
        
        logBuffer.get(log);
        
        System.out.println(new String(log));
        
        throw new Exception("Failed to build program on " + deviceName);
      }

      kernel = CL10.clCreateKernel(program, "search", null);
      if(kernel == null) {
        System.out.println();
        throw new Exception("Failed to create kernel on " + deviceName);
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
      
      System.out.println(localWorkSize.get(0) + ")");
      
      workSizeBase = localWorkSize.get(0) * deviceCU;

      workSizeMax = (long) (Math.pow(2, 32) - 1);
      
      workSize = workSizeBase * workSizeBase;

      executions = new ExecutionState[EXECUTION_TOTAL];
      
      for(int i = 0; i < EXECUTION_TOTAL; i++) {
        executions[i] = this.new ExecutionState();
        new Thread(executions[i]).start();
      }
    }
    
    void checkDevice() throws NoSuchAlgorithmException {
      long elapsed = now.get() - startTime;
      
      if(runs.get() > (runsThen.get() + targetFPS)) {
        float basis = elapsed / runs.get();
        float targetBasis = 1000 / targetFPS;
        
        if(basis < targetBasis / 2 && workSizeMax > workSize + (workSizeBase * workSizeBase))
          workSize += (workSizeBase * workSizeBase);
        else if(basis < targetBasis && workSizeMax > workSize + workSizeBase)
          workSize += workSizeBase;
        else if(basis > targetBasis * 2 && workSize > (workSizeBase * workSizeBase) + workSizeBase)
          workSize -= (workSizeBase * workSizeBase);
        else if(basis > targetBasis && workSize > workSizeBase + workSizeBase)
          workSize -= workSizeBase;
        
        runsThen.set(runs.get());
      }
      
      for(int i = 0; i < EXECUTION_TOTAL; i++) {
        if((executions[i].threadStartTime + TIME_OFFSET < now.get()) && (executions[i].lastTime  + TIME_OFFSET < now.get())) {
          System.err.println("\rERROR: Executor on " + deviceName + " locked up, restarting it");
          
          executions[i].threadRunning = false;
          
          executions[i] = this.new ExecutionState();
          new Thread(executions[i]).start();
        }
      }
    }

    class ExecutionState implements Runnable {
      boolean threadRunning = true;
      
      CLCommandQueue queue;
      
      final ByteBuffer buffer;
      final CLMem output;
      final CLMem store[] = new CLMem[8];
      
      final PointerBuffer workSizeTemp = BufferUtils.createPointerBuffer(1);
      
      final int[] midstate2 = new int[16];    
      
      final MessageDigest digestInside = MessageDigest.getInstance("SHA-256");
      final MessageDigest digestOutside = MessageDigest.getInstance("SHA-256");
      final ByteBuffer digestInput = ByteBuffer.allocate(80);
      byte[] digestOutput;
      
      final GetWorkParser currentWork;
      
      long base;
      
      long threadStartTime;
      long lastTime;
      
      IntBuffer errBuf = BufferUtils.createIntBuffer(1);
      
      ExecutionState() throws NoSuchAlgorithmException {
        buffer = BufferUtils.createByteBuffer(4);
        
        buffer.putInt(0, 0);
        
        output = CL10.clCreateBuffer(context, CL10.CL_MEM_WRITE_ONLY, 4, errBuf);
        
        if(output == null || errBuf.get(0) != CL10.CL_SUCCESS) {
          running = false;
          System.err.println("\rERROR: Failed to allocate output buffer");
        }

        currentWork = new GetWorkParser();
        threadStartTime = lastTime = currentWork.lastPull = now.get();
      }
      
      public void run() {
        queue = CL10.clCreateCommandQueue(context, device, 0, errBuf);
        
        if(queue == null || errBuf.get(0) != CL10.CL_SUCCESS) {
          running = false;
          System.err.println("\rERROR: Failed to allocate queue");
        }
        
        CL10.clEnqueueWriteBuffer(queue, output, CL10.CL_FALSE, 0, buffer, null, null);
        
        while(running == true && threadRunning == true) {       
          if(buffer.getInt(0) > 0) {     
            for(int j = 0; j < 19; j++)
              digestInput.putInt(j*4, currentWork.data[j]);
              
            digestInput.putInt(19*4, buffer.getInt(0));

            digestOutput = digestOutside.digest(digestInside.digest(digestInput.array()));
              
            long G = ((long)((0x000000FF & ((int)digestOutput[27])) << 24 | 
                (0x000000FF & ((int)digestOutput[26])) << 16 |
                (0x000000FF & ((int)digestOutput[25])) << 8 | 
                (0x000000FF & ((int)digestOutput[24])))) & 0xFFFFFFFFL;
              
            long H = ((long)((0x000000FF & ((int)digestOutput[31])) << 24 | 
                (0x000000FF & ((int)digestOutput[30])) << 16 |
                (0x000000FF & ((int)digestOutput[29])) << 8 | 
                (0x000000FF & ((int)digestOutput[28])))) & 0xFFFFFFFFL;
              
            if(debug) {
              System.out.println("\rDEBUG: Attempt " + currentAttempts + " found on " + deviceName + " at " +
                  DateFormat.getTimeInstance(DateFormat.MEDIUM).format(new Date()));
              currentAttempts++;
            }
              
            if(G <= currentWork.target[6]) {
              if(H == 0) {
                if(currentWork.sendWork(buffer.getInt(0))) {
                  System.out.print("\rBlock " + currentBlocks + " found on " + deviceName + " at " +
                      DateFormat.getTimeInstance(DateFormat.MEDIUM).format(new Date()));
                    
                  if(debug)
                    System.out.println(" with header of " + currentWork.encodeBlock());
                  else
                    System.out.println();
                } else {
                  if(debug)
                    System.out.println("\rDEBUG: Block found, but rejected by Bitcoin, on " + deviceName +
                        " at " + DateFormat.getTimeInstance(DateFormat.MEDIUM).format(new Date()));
                }
                  
                for(int i = 0; i < deviceStates.size(); i++) {
                  DeviceState device = deviceStates.get(i);
                    
                  for(int j = 0; j < EXECUTION_TOTAL; j++)
                    device.executions[j].currentWork.lastPull = 0;
                }
                  
                currentBlocks++;
              } else {
                System.err.println("\rERROR: Invalid block found on " + deviceName + " at " +
                    DateFormat.getTimeInstance(DateFormat.MEDIUM).format(new Date()) +
                    ", possible driver or hardware issue");
              }
            }
              
            buffer.putInt(0, 0);
            CL10.clEnqueueWriteBuffer(queue, output, CL10.CL_TRUE, 0, buffer, null, null);
          }            
          
          if(currentWork.lastPull + 5000 < now.get() || base > (Math.pow(2, 32))) {
            currentWork.getWork();
            currentWork.lastPull = now.get();
            base = 0;
          }
          
          System.arraycopy(currentWork.midstate, 0, midstate2, 0, 8);
        
          sharound(midstate2, 0, 1, 2, 3, 4, 5, 6, 7, currentWork.data[16], 0x428A2F98);
          sharound(midstate2, 7, 0, 1, 2, 3, 4, 5, 6, currentWork.data[17], 0x71374491);
          sharound(midstate2, 6, 7, 0, 1, 2, 3, 4, 5, currentWork.data[18], 0xB5C0FBCF);
        
          int offset = (int)base;
          workSizeTemp.put(0, workSize);
          int err = 0;

          kernel.setArg(0, currentWork.data[16])
                .setArg(1, currentWork.data[17])
                .setArg(2, currentWork.data[18])
                .setArg(3, currentWork.midstate[0])
                .setArg(4, currentWork.midstate[1])
                .setArg(5, currentWork.midstate[2])
                .setArg(6, currentWork.midstate[3])
                .setArg(7, currentWork.midstate[4])
                .setArg(8, currentWork.midstate[5])
                .setArg(9, currentWork.midstate[6])
                .setArg(10, currentWork.midstate[7])
                .setArg(11, midstate2[1])
                .setArg(12, midstate2[2])
                .setArg(13, midstate2[3])
                .setArg(14, midstate2[5])
                .setArg(15, midstate2[6])
                .setArg(16, midstate2[7])
                .setArg(17, offset)
                .setArg(18, output);
          
          err = CL10.clEnqueueNDRangeKernel(queue, kernel, 1, null, workSizeTemp, localWorkSize, null, null);
            
          if(err !=  CL10.CL_SUCCESS) {
            if(err != CL10.CL_INVALID_KERNEL_ARGS) {
              System.err.println("\rERROR: Failed to queue kernel, error " + err);
              running = false;
            } else {
              if(debug)
                System.out.println("\rDEBUG: Spurious CL_INVALID_KERNEL_ARGS, ignoring");
            }
          } else {                  
            hashCount.addAndGet(workSizeTemp.get(0));
            base += workSizeTemp.get(0);
            runs.incrementAndGet();
          }
          
          lastTime = now.get();
          
          CL10.clEnqueueReadBuffer(queue, output, CL10.CL_TRUE, 0, buffer, null, null);
        }
        
        CL10.clFinish(queue);
                
        CL10.clReleaseCommandQueue(queue);
        
        CL10.clReleaseMemObject(output);
      }
    }
  }
  
  class GetWorkParser {
    final int[] data = new int[32];
    final int[] midstate = new int[8];
    final long[] target = new long[8];
    
    final ObjectMapper mapper = new ObjectMapper();
    final ObjectNode getworkMessage;

    long lastPull = 0;
    
    GetWorkParser() {
      getworkMessage = mapper.createObjectNode();
      getworkMessage.put("method", "getwork");
      getworkMessage.putArray("params");
      getworkMessage.put("id", 1);
      
      getWork();
    }
    
    void getWork() {
      try {
        parse(doJSONRPC(bitcoind, userPass, mapper, getworkMessage));
      } catch(IOException e) {
        System.err.println("\rERROR: Can't connect to Bitcoin: " + e.getLocalizedMessage());
      }
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
        System.err.println("\rERROR: Can't connect to Bitcoin: " + e.getLocalizedMessage());
        return false;
      }
    }
    
    JsonNode doJSONRPC(URL bitcoind, String userPassword, ObjectMapper mapper, ObjectNode requestMessage) throws IOException {
      HttpURLConnection connection = (HttpURLConnection) bitcoind.openConnection();
      connection.setRequestProperty("Authorization", userPassword);
      connection.setDoOutput(true);

      OutputStream requestStream = connection.getOutputStream();
      Writer request = new OutputStreamWriter(requestStream);
      request.write(requestMessage.toString());
      request.close();
      requestStream.close();

      ObjectNode responseMessage = null;

      try {
        InputStream response = connection.getInputStream();
        responseMessage = (ObjectNode) mapper.readTree(response);
        response.close();
      } catch (IOException e) {
        InputStream errorStream = connection.getErrorStream();
        byte[] error = new byte[1024];
        errorStream.read(error);

        IOException e2 = new IOException("Failed to communicate with bitcoind: " + new String(error).trim());
        e2.setStackTrace(e.getStackTrace());

        throw e2;
      }

      connection.disconnect();

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
