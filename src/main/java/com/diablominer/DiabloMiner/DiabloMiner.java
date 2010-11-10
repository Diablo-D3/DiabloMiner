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
import org.lwjgl.opencl.CL11;
import org.lwjgl.opencl.CLCommandQueue;
import org.lwjgl.opencl.CLContext;
import org.lwjgl.opencl.CLContextCallback;
import org.lwjgl.opencl.CLDevice;
import org.lwjgl.opencl.CLEvent;
import org.lwjgl.opencl.CLEventCallback;
import org.lwjgl.opencl.CLKernel;
import org.lwjgl.opencl.CLMem;
import org.lwjgl.opencl.CLPlatform;
import org.lwjgl.opencl.CLProgram;

class DiabloMiner {
  URL bitcoind;
  String userPass;
  int targetFPS = 60;
  int forceWorkSize = 0;
  int forceVectorWidth = 0;
  
  String source;

  AtomicLong hashCount = new AtomicLong(0);
  
  long startTime;
  AtomicLong now = new AtomicLong(0);
  int currentBlocks = 1;
  
  final static int EXECUTION_TOTAL = 3;
  
  final static String VECTOR[] = new String[] { "0", "1", "2", "3", "4", "5", "6", "7",
                                                "8", "9", "a", "b", "c", "d", "e", "f"};

  public static void main(String [] args) throws Exception {
    DiabloMiner diabloMiner = new DiabloMiner();
    
    diabloMiner.execute(args);
  }
  
  void execute(String[] args) throws Exception {    
    String user = "diablo";
    String pass = "miner";
    String ip = "127.0.0.1";
    
    Options options = new Options();
    options.addOption("f", "fps", true, "target execution timing");
    options.addOption("w", "worksize", true, "override worksize");
    options.addOption("v", "vectorwidth", true, "override vector width");
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
      targetFPS = Integer.parseInt(line.getOptionValue("fps"));
    
    if(line.hasOption("worksize"))
      forceWorkSize = Integer.parseInt(line.getOptionValue("worksize"));
    
    if(line.hasOption("vectorwidth"))
      forceVectorWidth = Integer.parseInt(line.getOptionValue("vectorwidth"));

    bitcoind = new URL("http://"+ ip + ":8332/");    
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
  
    boolean running = true;
    
    long then = startTime = System.nanoTime() / 1000000;
    now.set((long) then);

    for(int i = 0; i < deviceStates.size(); i++)
      deviceStates.get(i).checkDevice();
    
    System.out.println("Started at " + DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.MEDIUM).format(new Date()));
    
    while(running) {     
      now.set(System.nanoTime() / 1000000);
      
      for(int i = 0; i < deviceStates.size(); i++)
        deviceStates.get(i).checkDevice();
      
      if(now.get() > then + 1000) {          
        long adjustedCount = hashCount.get() / ((now.get() - startTime) / 1000) / 1000;
        
        System.out.print("\r" + adjustedCount + " khash/sec");
        
        then = now.get();
      }
      
      if(!(now.get() - startTime > 10000))
        Thread.sleep(1);
      else
        Thread.sleep(1000);
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
 
    final CLContext context;
    final CLCommandQueue queue;

    final CLProgram program;
    final CLKernel kernel;
    
    long workSizeBase;
    final PointerBuffer workSize;
    final PointerBuffer localWorkSize;

    final int vectorWidth;
    
    final ExecutionState executions[];

    int base;
        
    AtomicLong runs = new AtomicLong(0);
    AtomicLong runsThen = new AtomicLong(0);
    
    DeviceState(CLPlatform platform, CLDevice device) throws Exception { 
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

      // OoOE doesn't work on OSX yet
      //queue = CL10.clCreateCommandQueue(context, device, CL10.CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE, null);
      queue = CL10.clCreateCommandQueue(context, device, 0, null);
      
      String deviceSource;
      String ns;
      String checkOutput = "";

      ns = "(uintv)(";
        
      for(int i = 0; i < vectorWidth; i++) {
        ns += "nonce + " + (((long)Math.pow(2, 32) / vectorWidth) * i);
          
        String s;
        
        if(vectorWidth > 1)
          s = ".s" + VECTOR[i];
        else
          s = "";
          
        checkOutput += "if(H" + s + " == 0) { \n" 
                    + "output[" + i + " * 2] = 0;\n"
                    + "output[" + i + " * 2 + 1] = ns" + s + ";\n"
                    + "}\n";
          
        if(i != vectorWidth - 1) {
          ns += ", ";
        }
      }
        
      ns += ")";
              
      deviceSource = source.replace("$ns", ns);
      deviceSource = deviceSource.replace("$checkOutput", checkOutput);
      
      if(forceWorkSize > 0)
        deviceSource = deviceSource.replace("$forcelocalsize",
            "__attribute__((reqd_work_group_size(" + forceWorkSize + ", 1, 1)))");
      else
        deviceSource = deviceSource.replace("$forcelocalsize", "");
      
      if(vectorWidth > 1)
        deviceSource = deviceSource.replace("uintv", "uint" + vectorWidth);
      else
        deviceSource = deviceSource.replace("uintv", "uint");

      program = CL10.clCreateProgramWithSource(context, deviceSource, null);
      err = CL10.clBuildProgram(program, device, "", null);
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
        throw new Exception("Failed to create kernel " + deviceName);
      }
      
      if(forceWorkSize == 0) {
        ByteBuffer rkwgs = BufferUtils.createByteBuffer(8);
        err = CL10.clGetKernelWorkGroupInfo(kernel, device, CL10.CL_KERNEL_WORK_GROUP_SIZE, rkwgs, null);
        workSizeBase = rkwgs.getLong(0);
      
        if(!(err == CL10.CL_SUCCESS) || workSizeBase == 0)
          workSizeBase = deviceWorkSize;
      } else {
        workSizeBase = forceWorkSize;
      }
      
      System.out.println(workSizeBase + ")");
            
      localWorkSize = BufferUtils.createPointerBuffer(1);
      localWorkSize.put(0, workSizeBase);
      
      workSizeBase *= workSizeBase;
      
      workSize = BufferUtils.createPointerBuffer(1);
      workSize.put(0, workSizeBase);
      
      executions = new ExecutionState[EXECUTION_TOTAL];
      
      for(int i = 0; i < EXECUTION_TOTAL; i++) {
        executions[i] = this.new ExecutionState();
        executions[i].checkExecution();
        CL10.clFlush(queue);
      }
    }
    
    void checkDevice() throws IOException {     
      if(runs.get() > runsThen.get()) {
        if((now.get() - startTime) / runs.get() < 1000 / (targetFPS * 2))
          workSize.put(0, workSize.get(0) + workSizeBase * 2);            
        
        if((now.get() - startTime) / runs.get() > 1000 / targetFPS)
          if(workSize.get(0) > workSizeBase * 2)
            workSize.put(0, workSize.get(0) - workSizeBase);
        
        runsThen.set(runs.get());
      }
    }

    class ExecutionState extends CLEventCallback {
      final ByteBuffer buffer;
      final IntBuffer bufferInt;
      final CLMem output;
      
      CLEvent event;      
      
      final PointerBuffer eventPointer1 = BufferUtils.createPointerBuffer(1);
      final PointerBuffer eventPointer2 = BufferUtils.createPointerBuffer(1);
      final PointerBuffer eventPointer3 = BufferUtils.createPointerBuffer(1);
      final ByteBuffer scratchBuffer = BufferUtils.createByteBuffer(8);
      
      final int[] state2 = new int[16];    
      
      final MessageDigest digest = MessageDigest.getInstance("SHA-256");
      final ByteBuffer digestFirst = BufferUtils.createByteBuffer(128);
      final IntBuffer digestFirstInt = digestFirst.asIntBuffer();
      byte[] digestSecond;
      
      final GetWorkParser currentWork;
      
      ExecutionState() throws Exception {
        buffer = BufferUtils.createByteBuffer(vectorWidth*2*4);
        bufferInt = buffer.asIntBuffer();
        
        for(int i = 0; i < vectorWidth; i++)
          bufferInt.put((i * 2), 1);
        
        output = CL10.clCreateBuffer(context, CL10.CL_MEM_WRITE_ONLY, vectorWidth*2*4, null);
        
        CL10.clEnqueueWriteBuffer(queue, output, CL10.CL_FALSE, 0, buffer, null, eventPointer1);
        event = queue.getCLEvent(eventPointer1.get(0));
        
        currentWork = new GetWorkParser();
      }
      
      void checkExecution() throws IOException {
        runs.incrementAndGet();

        CL10.clReleaseEvent(event);
        
        boolean reset = false;
          
        for(int i = 0; i < vectorWidth; i++) {
          if(bufferInt.get(i * 2) == 0) {             
            digestFirstInt.put(currentWork.block);
            digestFirstInt.put(19, bufferInt.get((i * 2) + 1));
            digestFirstInt.flip();
            digest.update(digestFirst);
            digestFirst.flip();
            digestSecond = digest.digest();
            digest.update(digestSecond);
            digestFirst.put(digest.digest());
            digestFirst.flip();
            
            long G = ((long)((0x000000FF & ((int)digestFirst.get(24))) << 24 | 
                (0x000000FF & ((int)digestFirst.get(25))) << 16 |
                (0x000000FF & ((int)digestFirst.get(26))) << 8 | 
                (0x000000FF & ((int)digestFirst.get(27))))) & 0xFFFFFFFFL;
                
            if(G <= currentWork.target[6]) {
              System.out.println("\rBlock " + currentBlocks + " found on " + deviceName + " at " +
                  DateFormat.getTimeInstance(DateFormat.MEDIUM).format(new Date()));
              
              currentWork.sendWork(bufferInt.get((i * 2) + 1));
              currentWork.lastPull = now.get();
              
              currentBlocks++;
            }
              
            bufferInt.put(i * 2, 1);
            reset = true;
          }
        }
                 
        if(currentWork.lastPull + 5000 < now.get()) {
          currentWork.getWork();
          currentWork.lastPull = now.get();
        }
        
        System.arraycopy(currentWork.state, 0, state2, 0, 8);
        
        sharound(state2, 0, 1, 2, 3, 4, 5, 6, 7, currentWork.block[16], 0x428A2F98);
        sharound(state2, 7, 0, 1, 2, 3, 4, 5, 6, currentWork.block[17], 0x71374491);
        sharound(state2, 6, 7, 0, 1, 2, 3, 4, 5, currentWork.block[18], 0xB5C0FBCF);
        
        kernel.setArg(0, currentWork.block[16])
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
              .setArg(17, base)
              .setArg(18, output);
        
        if(reset) {
          CL10.clEnqueueWriteBuffer(queue, output, CL10.CL_FALSE, 0, buffer, null, eventPointer1);
          CL10.clEnqueueNDRangeKernel(queue, kernel, 1, null, workSize, localWorkSize, eventPointer1, eventPointer2);
          CL10.clReleaseEvent(queue.getCLEvent(eventPointer1.get(0)));
        } else {
          CL10.clEnqueueNDRangeKernel(queue, kernel, 1, null, workSize, localWorkSize, null, eventPointer2);
        }
        
        CL10.clEnqueueReadBuffer(queue, output, CL10.CL_FALSE, 0, buffer, eventPointer2, eventPointer3);
        event = queue.getCLEvent(eventPointer3.get(0));
          
        hashCount.addAndGet(workSize.get(0) * vectorWidth);
        base += workSize.get(0);

        CL10.clReleaseEvent(queue.getCLEvent(eventPointer2.get(0)));
        
        CL11.clSetEventCallback(event, CL10.CL_COMPLETE, this);
        CL10.clFlush(queue);
      }

      @Override
      protected void handleMessage(CLEvent event, int event_command_exec_status) {
        if(event_command_exec_status == CL10.CL_SUCCESS)
          try {
            this.checkExecution();
          } catch (IOException e) {}
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
    
    GetWorkParser() throws IOException {
      getworkMessage = mapper.createObjectNode();
      getworkMessage.put("method", "getwork");
      getworkMessage.putArray("params");
      getworkMessage.put("id", 1);
      
      getWork();
    }
    
    void getWork() throws IOException {
      parse(doJSONRPC(bitcoind, userPass, mapper, getworkMessage));
    }
    
    void sendWork(int nonce) throws IOException {
      block[19] = nonce;
      
      ObjectNode sendworkMessage = mapper.createObjectNode();
      sendworkMessage.put("method", "getwork");
      ArrayNode params = sendworkMessage.putArray("params");
      params.add(extraNonce);
      params.add(encodeBlock());
      sendworkMessage.put("id", 1);             

      parse(doJSONRPC(bitcoind, userPass, mapper, sendworkMessage));
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
