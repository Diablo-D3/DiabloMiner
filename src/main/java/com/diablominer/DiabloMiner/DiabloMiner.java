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
  int forceVectorWidth = 0;
  boolean forceBitAlign = false;
  boolean debug = false;
  boolean forceSplit = false;
  
  String source;

  boolean running = true;
  
  AtomicLong hashCount = new AtomicLong(0);
  
  long startTime;
  AtomicLong now = new AtomicLong(0);
  int currentBlocks = 1;
  int currentAttempts = 1;
  
  final static int EXECUTION_TOTAL = 3;

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
    options.addOption("v", "vectorwidth", true, "override vector width");
    options.addOption("o", "host", true, "bitcoin host IP");
    options.addOption("p", "port", true," bitcoin host port");
    options.addOption("a", "bitalign", false, "force bitalign on for Radeon 5xxx + ATI SDK 2.1");
    options.addOption("d", "debug", false, "enable extra debug output");
    options.addOption("s", "split", false, "enable payload split, faster on Radeon 4xxx");
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
    
    if(line.hasOption("vectorwidth")) {
      forceVectorWidth = Integer.parseInt(line.getOptionValue("vectorwidth"));
      
      if(!(forceVectorWidth == 1 || forceVectorWidth == 2 || forceVectorWidth == 4 ||
          forceVectorWidth == 8 || forceVectorWidth == 16)) {
        System.err.println("Error: Vector width must be 1, 2, 4, 8, or 16");
        System.exit(0);
      }
    }

    if(line.hasOption("bitalign"))
      forceBitAlign = true;
    
    if(line.hasOption("debug"))
      debug = true;
    
    if(line.hasOption("split"))
      forceSplit = true;
    
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
    List<DeviceState> deviceStates = new ArrayList<DeviceState>();
      
    if(platforms == null)
      throw new Exception("No OpenCL platforms found.");
        
    for(CLPlatform platform : platforms) {         
      List<CLDevice> devices = platform.getDevices(CL10.CL_DEVICE_TYPE_GPU | CL10.CL_DEVICE_TYPE_ACCELERATOR);
        
      for (CLDevice device : devices)
        deviceStates.add(this.new DeviceState(platform, device));
    }
    
    long then = startTime = System.nanoTime() / 1000000;
    now.set((long) then);

    for(int i = 0; i < deviceStates.size(); i++)
      deviceStates.get(i).checkDevice();
    
    System.out.println("Started at " + DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.MEDIUM).format(new Date()));
    
    System.out.print("Waiting...");
    
    while(running) {     
      now.set(System.nanoTime() / 1000000);
      
      for(int i = 0; i < deviceStates.size(); i++)
        deviceStates.get(i).checkDevice();
            
      if(now.get() - startTime > 10000) {
        long adjustedCount = hashCount.get() / ((now.get() - startTime) / 1000) / 1000;
        System.out.print("\r" + adjustedCount + " khash/sec");
        then = now.get();
      }
      
      try {
        if(now.get() - startTime < 5000) {
          Thread.sleep(1);
          
          if(now.get() - startTime < 100) {
            hashCount.set(0);
          }
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
    final CLKernel kernel0;
    final CLKernel kernel1;
    final CLKernel kernel2;

    long workSize;
    long workSizeMax;
    long workSizeBase;
    final PointerBuffer localWorkSize = BufferUtils.createPointerBuffer(1);

    final int vectorWidth;
    
    final ExecutionState executions[];
        
    AtomicLong runs = new AtomicLong(0);
    AtomicLong runsThen = new AtomicLong(0);
    
    DeviceState(CLPlatform platform, CLDevice device) throws Exception {
      this.device = device;
      
      PointerBuffer properties = BufferUtils.createPointerBuffer(3);
      properties.put(CL10.CL_CONTEXT_PLATFORM).put(platform.getPointer()).put(0).flip();
      int err = 0;
      
      deviceName = device.getInfoString(CL10.CL_DEVICE_NAME);
      int deviceCU = device.getInfoInt(CL10.CL_DEVICE_MAX_COMPUTE_UNITS);
      long deviceWorkSize = device.getInfoSize(CL10.CL_DEVICE_MAX_WORK_GROUP_SIZE);
      
      if(forceVectorWidth == 0)
        //vectorWidth = device.getInfoInt(CL10.CL_DEVICE_PREFERRED_VECTOR_WIDTH_);
        vectorWidth = 1;
      else
        vectorWidth = forceVectorWidth;

      System.out.print("Added " + deviceName + " (" + deviceCU + " CU, " + vectorWidth +
          "x vector, local work size of ");
      
      context = CL10.clCreateContext(properties, device, new CLContextCallback() {
        protected void handleMessage(String errinfo, ByteBuffer private_info) {
          System.out.println("ERROR: " + errinfo);
        }
      }, null);
      
      String compileOptions = "-D VECTORS=" + vectorWidth;
      
      String ns;
      String checkOutput = "";

      ns = "(u)(";
        
      for(int i = 0; i < vectorWidth; i++) {
        ns += "(nonce * " + vectorWidth + ") + " + i;
          
        String s;
        
        if(vectorWidth > 1)
          s = ".s" + "0123456789abcdef".charAt(i);
        else
          s = "";
          
        checkOutput += "if(H" + s + " == 0) {" 
                    + "output[" + i + "] = ns" + s + ";"
                    + "}";
          
        if(i != vectorWidth - 1) {
          ns += ", ";
        }
      }
        
      ns += ")";    

      compileOptions += " -D NS=\"" + ns + "\"";
      compileOptions += " -D CHECKOUTPUT=\"" + checkOutput + "\"";
      
      if(forceBitAlign)
        compileOptions += " -D FORCEBITALIGN";
      
      if(forceWorkSize > 0)
        compileOptions += " -D WORKGROUPSIZE=\"__attribute__((reqd_work_group_size(" + forceWorkSize + ", 1, 1)))\"";
      else
        compileOptions += " -D WORKGROUPSIZE=\"\"";
      
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

      if(!forceSplit) {
        kernel0 = CL10.clCreateKernel(program, "search0", null);
        if(kernel0 == null) {
          System.out.println();
          throw new Exception("Failed to create kernel on " + deviceName);
        }
        
        kernel1 = null;
        kernel2 = null;
      } else {
        kernel0 = null;
        
        kernel1 = CL10.clCreateKernel(program, "search1", null);
        if(kernel1 == null) {
          System.out.println();
          throw new Exception("Failed to create first kernel on " + deviceName);
        }
      
        kernel2 = CL10.clCreateKernel(program, "search2", null);
        if(kernel2 == null) {
          System.out.println();
          throw new Exception("Failed to create second kernel on " + deviceName);
        }
      }
      
      if(forceWorkSize == 0) {
        ByteBuffer rkwgs = BufferUtils.createByteBuffer(8);
        err = CL10.clGetKernelWorkGroupInfo(kernel1, device, CL10.CL_KERNEL_WORK_GROUP_SIZE, rkwgs, null);
        localWorkSize.put(0, rkwgs.getLong(0));
      
        if(!(err == CL10.CL_SUCCESS) || localWorkSize.get(0) == 0)
          localWorkSize.put(0, deviceWorkSize);
      } else {
        localWorkSize.put(0, forceWorkSize);
      }
      
      System.out.println(localWorkSize.get(0) + ")");
      
      workSizeBase = localWorkSize.get(0) * deviceCU;
      
      if(!forceSplit)
        workSizeMax = (long) (Math.pow(2, 32) - 1);
      else
        workSizeMax = 16*1024*1024 / 4 / vectorWidth;
      
      workSize = workSizeBase * workSizeBase;

      executions = new ExecutionState[EXECUTION_TOTAL];
      
      for(int i = 0; i < EXECUTION_TOTAL; i++) {
        executions[i] = this.new ExecutionState();
        Thread executionThread = new Thread(executions[i]);
        executionThread.start();
      }
    }
    
    void checkDevice() {
      long elapsed = now.get() - startTime;
      
      if(runs.get() > (runsThen.get() + targetFPS)) {
        long basis = elapsed / runs.get();
        
        if(basis < 1000 / targetFPS * 2 && workSizeMax > workSize + (workSizeBase * workSizeBase))
          workSize += (workSizeBase * workSizeBase);
        else if(basis < 1000 / targetFPS && workSizeMax > workSize + workSizeBase)
          workSize += workSizeBase;
        else if(basis > 1000 / targetFPS / 2 && workSize > (workSizeBase * workSizeBase) + workSizeBase)
          workSize -= (workSizeBase * workSizeBase);
        else if(basis > 1000 / targetFPS && workSize > workSizeBase * 2)
          workSize -= workSizeBase;
        
        runsThen.set(runs.get());
      }
    }

    class ExecutionState implements Runnable {
      CLCommandQueue queue;
      
      final ByteBuffer buffer;
      final CLMem output;
      final CLMem store[] = new CLMem[8];
      
      final PointerBuffer workSizeTemp = BufferUtils.createPointerBuffer(1);
      
      final int[] state2 = new int[16];    
      
      final MessageDigest digestInside = MessageDigest.getInstance("SHA-256");
      final MessageDigest digestOutside = MessageDigest.getInstance("SHA-256");
      final ByteBuffer digestInput = ByteBuffer.allocate(80);
      byte[] digestOutput;
      
      final GetWorkParser currentWork;
      
      long base;
      
      ExecutionState() throws NoSuchAlgorithmException {
        buffer = BufferUtils.createByteBuffer(vectorWidth * 4);
        
        for(int i = 0; i < vectorWidth; i++)
          buffer.putInt(i*4, 0);
        
        output = CL10.clCreateBuffer(context, CL10.CL_MEM_WRITE_ONLY, vectorWidth * 4, null);
        
        if(forceSplit)
          for(int i = 0; i < 8; i++)
            store[i] = CL10.clCreateBuffer(context, CL10.CL_MEM_READ_WRITE, 16*1024*1024, null);
        
        currentWork = new GetWorkParser();
        currentWork.lastPull = now.get();
      }
      
      public void run() {
        queue = CL10.clCreateCommandQueue(context, device, 0, null);
        
        CL10.clEnqueueWriteBuffer(queue, output, CL10.CL_FALSE, 0, buffer, null, null);
        
        while(running == true) {       
          boolean reset = false;
          
          for(int i = 0; i < vectorWidth; i++) {
            if(buffer.getInt(i*4) > 0) {     
              for(int j = 0; j < 19; j++)
                digestInput.putInt(j*4, currentWork.block[j]);
              
              digestInput.putInt(19*4, buffer.getInt(i*4));

              digestOutput = digestOutside.digest(digestInside.digest(digestInput.array()));
              
              long G = ((long)((0x000000FF & ((int)digestOutput[27])) << 24 | 
                  (0x000000FF & ((int)digestOutput[26])) << 16 |
                  (0x000000FF & ((int)digestOutput[25])) << 8 | 
                  (0x000000FF & ((int)digestOutput[24])))) & 0xFFFFFFFFL;
              
              if(debug) {
                System.out.println("\rAttempt " + currentAttempts + " found on " + deviceName + " at " +
                    DateFormat.getTimeInstance(DateFormat.MEDIUM).format(new Date()));
                currentAttempts++;
              }
              
              if(G <= currentWork.target[6]) {
                System.out.println("\rBlock " + currentBlocks + " found on " + deviceName + " at " +
                    DateFormat.getTimeInstance(DateFormat.MEDIUM).format(new Date()));
              
                currentWork.sendWork(buffer.getInt(i*4));
                currentWork.lastPull = now.get();
                base = 0;
              
                currentBlocks++;
              }
              
              buffer.putInt(i*4, 0);
              reset = true;
            }
          }
          
          if(reset)
            CL10.clEnqueueWriteBuffer(queue, output, CL10.CL_FALSE, 0, buffer, null, null);
          
          if(currentWork.lastPull + 5000 < now.get() || base > (Math.pow(2, 32) / vectorWidth)) {
            currentWork.getWork();
            currentWork.lastPull = now.get();
            base = 0;
          }
        
          System.arraycopy(currentWork.state, 0, state2, 0, 8);
        
          sharound(state2, 0, 1, 2, 3, 4, 5, 6, 7, currentWork.block[16], 0x428A2F98);
          sharound(state2, 7, 0, 1, 2, 3, 4, 5, 6, currentWork.block[17], 0x71374491);
          sharound(state2, 6, 7, 0, 1, 2, 3, 4, 5, currentWork.block[18], 0xB5C0FBCF);
        
          int offset = (int)base;
          workSizeTemp.put(0, workSize);
          
          if(!forceSplit) {
            kernel0.setArg(0, currentWork.block[16])
                   .setArg(1, currentWork.block[17])
                   .setArg(2, currentWork.block[18])
                   .setArg(3, currentWork.state[0])
                   .setArg(4, currentWork.state[1])
                   .setArg(5, currentWork.state[2])
                   .setArg(6, currentWork.state[3])
                   .setArg(7, currentWork.state[4])
                   .setArg(8, currentWork.state[5])
                   .setArg(9, currentWork.state[6])
                   .setArg(10, currentWork.state[7])
                   .setArg(11, state2[1])
                   .setArg(12, state2[2])
                   .setArg(13, state2[3])
                   .setArg(14, state2[5])
                   .setArg(15, state2[6])
                   .setArg(16, state2[7])
                   .setArg(17, offset)
                   .setArg(18, output);

            CL10.clEnqueueNDRangeKernel(queue, kernel0, 1, null, workSizeTemp, localWorkSize, null, null);
          } else {
            kernel1.setArg(0, currentWork.block[16])
                   .setArg(1, currentWork.block[17])
                   .setArg(2, currentWork.block[18])
                   .setArg(3, currentWork.state[0])
                   .setArg(4, currentWork.state[4])
                   .setArg(5, state2[1])
                   .setArg(6, state2[2])
                   .setArg(7, state2[3])
                   .setArg(8, state2[5])
                   .setArg(9, state2[6])
                   .setArg(10, state2[7])
                   .setArg(11, offset)
                   .setArg(12, store[0])
                   .setArg(13, store[1])
                   .setArg(14, store[2])
                   .setArg(15, store[3])
                   .setArg(16, store[4])
                   .setArg(17, store[5])
                   .setArg(18, store[6])
                   .setArg(19, store[7]);

            CL10.clEnqueueNDRangeKernel(queue, kernel1, 1, null, workSizeTemp, localWorkSize, null, null);
          
            kernel2.setArg(0, currentWork.state[0])
                   .setArg(1, currentWork.state[1])
                   .setArg(2, currentWork.state[2])
                   .setArg(3, currentWork.state[3])
                   .setArg(4, currentWork.state[4])
                   .setArg(5, currentWork.state[5])
                   .setArg(6, currentWork.state[6])
                   .setArg(7, currentWork.state[7])
                   .setArg(8, offset)
                   .setArg(9, output)
                   .setArg(10, store[0])
                   .setArg(11, store[1])
                   .setArg(12, store[2])
                   .setArg(13, store[3])
                   .setArg(14, store[4])
                   .setArg(15, store[5])
                   .setArg(16, store[6])
                   .setArg(17, store[7]);
          
            CL10.clEnqueueNDRangeKernel(queue, kernel2, 1, null, workSizeTemp, localWorkSize, null, null);
          }
          
          hashCount.addAndGet(workSizeTemp.get(0) * vectorWidth);
          base += workSizeTemp.get(0);
          runs.incrementAndGet();
          
          CL10.clEnqueueReadBuffer(queue, output, CL10.CL_TRUE, 0, buffer, null, null);
        }
      }
    }
  }
  
  class GetWorkParser {
    final int[] block = new int[32];
    final int[] state = new int[8];
    final long[] target = new long[8];
    int extraNonce = 0;
    
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
        System.out.println("\rCan't connect to Bitcoin: " + e.getLocalizedMessage());
      }
    }
    
    void sendWork(int nonce) {
      block[19] = nonce;
      
      ObjectNode sendworkMessage = mapper.createObjectNode();
      sendworkMessage.put("method", "getwork");
      ArrayNode params = sendworkMessage.putArray("params");
      params.add(extraNonce);
      params.add(encodeBlock());
      sendworkMessage.put("id", 1);             

      try {
        parse(doJSONRPC(bitcoind, userPass, mapper, sendworkMessage));
      } catch(IOException e) {
        System.out.println("\rCan't connect to Bitcoin: " + e.getLocalizedMessage());
      }
    }
    
    ObjectNode doJSONRPC(URL bitcoind, String userPassword, ObjectMapper mapper, ObjectNode requestMessage)
        throws IOException {
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
      
      return (ObjectNode) responseMessage.get("result");
    }
    
    void parse(ObjectNode responseMessage) {
      String blocks = responseMessage.get("block").getValueAsText();
      String states = responseMessage.get("state").getValueAsText();
      String targets = responseMessage.get("target").getValueAsText();
      extraNonce = responseMessage.get("extraNonce").getValueAsInt();
      
      for(int i = 0; i < block.length; i++) {
        String parse = blocks.substring(i*8, (i*8)+8);
        block[i] = Integer.reverseBytes((int)Long.parseLong(parse, 16));
      }

      for(int i = 0; i < state.length; i++) {
        String parse = states.substring(i*8, (i*8)+8);
        state[i] = Integer.reverseBytes((int)Long.parseLong(parse, 16));
      }
      
      for(int i = 0; i < target.length; i++) {
        String parse = targets.substring(i*8, (i*8)+8);
        target[i] = (Long.reverseBytes(Long.parseLong(parse, 16) << 16)) >>> 16;
      }
    }

    String encodeBlock() {
      StringBuilder builder = new StringBuilder();
      
      for(int b : block)
        builder.append(String.format("%08x", Integer.reverseBytes(b)));
      
      return builder.toString();
    }
  }
}
