/*
 * DiabloMiner - OpenCL miner for BitCoin
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

package com.diablominer.DiabloMiner.NetworkState;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.net.HttpURLConnection;
import java.net.Proxy;
import java.net.URL;
import java.util.Formatter;
import java.util.concurrent.LinkedBlockingDeque;
import java.util.zip.GZIPInputStream;
import java.util.zip.InflaterInputStream;

import org.apache.commons.codec.binary.Base64;
import org.codehaus.jackson.JsonNode;
import org.codehaus.jackson.JsonProcessingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.codehaus.jackson.node.ArrayNode;
import org.codehaus.jackson.node.NullNode;
import org.codehaus.jackson.node.ObjectNode;

import com.diablominer.DiabloMiner.DiabloMiner;
import com.diablominer.DiabloMiner.DeviceState.DeviceState.ExecutionState;

public class JSONRPCNetworkState extends NetworkState {
	URL longPollUrl;
	String userPass;

	boolean rollNTime = false;
	boolean noDelay = false;
	String rejectReason = null;

	final GetWorkAsync getWorkAsync = this.new GetWorkAsync();
	final SendWorkAsync sendWorkAsync = this.new SendWorkAsync();

	LongPollAsync longPollAsync = null;
	LinkedBlockingDeque<WorkState> incomingQueue = new LinkedBlockingDeque<WorkState>();

	final ObjectMapper mapper = new ObjectMapper();

	public JSONRPCNetworkState(DiabloMiner diabloMiner, URL queryUrl, String user, String pass, byte hostChain) {
		super(diabloMiner, queryUrl, user, pass, hostChain);
		this.userPass = "Basic " + Base64.encodeBase64String((user + ":" + pass).getBytes()).trim().replace("\r\n", "");

		Thread thread = new Thread(getWorkAsync, "DiabloMiner JSONRPC GetWorkAsync for " + queryUrl.getHost());
		thread.start();
		diabloMiner.addThread(thread);

		thread = new Thread(sendWorkAsync, "DiabloMiner JSONRPC SendWorkAsync for " + queryUrl.getHost());
		thread.start();
		diabloMiner.addThread(thread);
	}

	JsonNode doJSONRPCCall(boolean longPoll, ObjectNode message) throws IOException {
      HttpURLConnection connection = null;
		try {
	      URL url;

	      if(longPoll)
	      	url = longPollUrl;
	      else
	      	url = queryUrl;

	      Proxy proxy = diabloMiner.getProxy();

	      if(proxy == null)
	      	connection = (HttpURLConnection) url.openConnection();
	      else
	      	connection = (HttpURLConnection) url.openConnection(proxy);

	      if(longPoll) {
	      	connection.setConnectTimeout(10 * 60 * 1000);
	      	connection.setReadTimeout(10 * 60 * 1000);
	      } else {
	      	connection.setConnectTimeout(15 * 1000);
	      	connection.setReadTimeout(15 * 1000);
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
	      request.write(message.toString());
	      request.close();
	      requestStream.close();

	      ObjectNode responseMessage = null;

	      InputStream responseStream = null;

	      try {
	      	String xLongPolling = connection.getHeaderField("X-Long-Polling");

	      	if(xLongPolling != null && !"".equals(xLongPolling) && longPollAsync == null) {
	      		if(xLongPolling.startsWith("http"))
	      			longPollUrl = new URL(xLongPolling);
	      		else if(xLongPolling.startsWith("/"))
	      			longPollUrl = new URL(queryUrl.getProtocol(), queryUrl.getHost(), queryUrl.getPort(), xLongPolling);
	      		else
	      			longPollUrl = new URL(queryUrl.getProtocol(), queryUrl.getHost(), queryUrl.getPort(), (url.getFile() + "/" + xLongPolling).replace("//", "/"));

	      		longPollAsync = new LongPollAsync();
	      		Thread thread = new Thread(longPollAsync, "DiabloMiner JSONRPC LongPollAsync for " + url.getHost());
	      		thread.start();
	      		diabloMiner.addThread(thread);

	      		workLifetime = 60000;

	      		diabloMiner.debug(queryUrl.getHost() + ": Enabling long poll support");
	      	}

	      	String xRollNTime = connection.getHeaderField("X-Roll-NTime");

	      	if(xRollNTime != null && !"".equals(xRollNTime)) {
	      		if(!"n".equalsIgnoreCase(xRollNTime) && rollNTime == false) {
	      			rollNTime = true;

	      			if(xRollNTime.startsWith("expire=")) {
	      				try {
	      					workLifetime = Integer.parseInt(xRollNTime.substring(7)) * 1000;
	      				} catch(NumberFormatException ex) { }
	      			} else {
	      				workLifetime = 60000;
	      			}

	      			diabloMiner.debug(queryUrl.getHost() + ": Enabling roll ntime support, expire after " + (workLifetime / 1000) + " seconds");
	      		} else if("n".equalsIgnoreCase(xRollNTime) && rollNTime == true) {
	      			rollNTime = false;

	      			if(longPoll)
	      				workLifetime = 60000;
	      			else
	      				workLifetime = diabloMiner.getWorkLifetime();

	      			diabloMiner.debug(queryUrl.getHost() + ": Disabling roll ntime support");
	      		}
	      	}

	      	String xSwitchTo = connection.getHeaderField("X-Switch-To");

	      	if(xSwitchTo != null && !"".equals(xSwitchTo)) {
	      		String oldHost = queryUrl.getHost();
	      		JsonNode newHost = mapper.readTree(xSwitchTo);

	      		queryUrl = new URL(queryUrl.getProtocol(), newHost.get("host").asText(), newHost.get("port").getIntValue(), queryUrl.getPath());

	      		if(longPollUrl != null)
	      			longPollUrl = new URL(longPollUrl.getProtocol(), newHost.get("host").asText(), newHost.get("port").getIntValue(), longPollUrl.getPath());

	      		diabloMiner.info(oldHost + ": Switched to " + queryUrl.getHost());
	      	}

	      	String xRejectReason = connection.getHeaderField("X-Reject-Reason");

	      	if(xRejectReason != null && !"".equals(xRejectReason)) {
	      		rejectReason = xRejectReason;
	      	}

	      	String xIsP2Pool = connection.getHeaderField("X-Is-P2Pool");

	      	if(xIsP2Pool != null && !"".equals(xIsP2Pool)) {
	      		if(!noDelay)
	      			diabloMiner.info("P2Pool no delay mode enabled");

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

	      	if(NullNode.class.equals(output.getClass())) {
	      		throw new IOException("Bitcoin returned unparsable JSON");
	      	} else {
	      		try {
	      			responseMessage = (ObjectNode) output;
	      		} catch(ClassCastException e) {
	      			throw new IOException("Bitcoin returned unparsable JSON");
	      		}
	      	}

	      	responseStream.close();
	      } catch(JsonProcessingException e) {
	      	throw new IOException("Bitcoin returned unparsable JSON");
	      } catch(IOException e) {
	      	InputStream errorStream = null;
	      	IOException e2 = null;

	      	if(connection.getErrorStream() == null)
	      		throw new IOException("Bitcoin disconnected during response: " + connection.getResponseCode() + " " + connection.getResponseMessage());

	      	if(connection.getContentEncoding() != null) {
	      		if(connection.getContentEncoding().equalsIgnoreCase("gzip"))
	      			errorStream = new GZIPInputStream(connection.getErrorStream());
	      		else if(connection.getContentEncoding().equalsIgnoreCase("deflate"))
	      			errorStream = new InflaterInputStream(connection.getErrorStream());
	      	} else {
	      		errorStream = connection.getErrorStream();
	      	}

	      	if(errorStream == null)
	      		throw new IOException("Bitcoin disconnected during response: " + connection.getResponseCode() + " " + connection.getResponseMessage());

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
	      				try {
	      					responseMessage = (ObjectNode) output;
	      				} catch(ClassCastException f) {
	      					throw new IOException("Bitcoin returned unparsable JSON");
	      				}

	      			if(responseMessage.get("error") != null) {
	      				if(responseMessage.get("error").get("message") != null && responseMessage.get("error").get("message").asText() != null) {
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
	      	if(responseMessage.get("error").get("message") != null && responseMessage.get("error").get("message").asText() != null) {
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
      } catch(IOException e) {
      	if(connection != null)
      		connection.disconnect();

	      throw e;
      }
	}

	WorkState doGetWorkMessage(boolean longPoll) throws IOException {
		ObjectNode getWorkMessage = mapper.createObjectNode();

		getWorkMessage.put("method", "getwork");
		getWorkMessage.putArray("params");
		getWorkMessage.put("id", 1);

		JsonNode responseMessage = doJSONRPCCall(longPoll, getWorkMessage);

		String datas;
		String midstates;
		String targets;

		try {
			datas = responseMessage.get("data").asText();
			midstates = responseMessage.get("midstate").asText();
			targets = responseMessage.get("target").asText();
		} catch(Exception e) {
			throw new IOException("Bitcoin returned unparsable JSON");
		}

		WorkState workState = new WorkState(this);

		String parse;

		for(int i = 0; i < 32; i++) {
			parse = datas.substring(i * 8, (i * 8) + 8);
			workState.setData(i, Integer.reverseBytes((int) Long.parseLong(parse, 16)));
		}

		for(int i = 0; i < 8; i++) {
			parse = midstates.substring(i * 8, (i * 8) + 8);
			workState.setMidstate(i, Integer.reverseBytes((int) Long.parseLong(parse, 16)));
		}

		for(int i = 0; i < 8; i++) {
			parse = targets.substring(i * 8, (i * 8) + 8);
			workState.setTarget(i, (Long.reverseBytes(Long.parseLong(parse, 16) << 16)) >>> 16);
		}

		return workState;
	}

	boolean doSendWorkMessage(WorkState workState) throws IOException {
		StringBuilder dataOutput = new StringBuilder(8 * 32 + 1);
		Formatter dataFormatter = new Formatter(dataOutput);
		int[] data = workState.getData();

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

		ObjectNode sendWorkMessage = mapper.createObjectNode();
		sendWorkMessage.put("method", "getwork");
		ArrayNode params = sendWorkMessage.putArray("params");
		params.add(dataOutput.toString());
		sendWorkMessage.put("id", 1);

		JsonNode responseMessage = doJSONRPCCall(false, sendWorkMessage);

		boolean accepted;

		dataFormatter.close();

		try {
			accepted = responseMessage.getBooleanValue();
		} catch(Exception e) {
			throw new IOException("Bitcoin returned unparsable JSON");
		}

		return accepted;
	}

	class GetWorkAsync implements Runnable {
		public void run() {
			while(diabloMiner.getRunning()) {
				ExecutionState executionState = null;

				try {
					executionState = getQueue.take();
				} catch(InterruptedException e) {
					continue;
				}

				if(executionState != null) {
					WorkState workState = incomingQueue.poll();

					if(workState == null) {
						try {
							workState = doGetWorkMessage(false);
						} catch (IOException e) {
							diabloMiner.error("Cannot connect to " + queryUrl.getHost() + ": " + e.getLocalizedMessage());

							networkStateNext.addGetQueue(executionState);

							try {
								if(!noDelay)
									Thread.sleep(250);
							} catch(InterruptedException f) { }

							continue;
						}
					}

					workState.setExecutionState(executionState);
					executionState.addIncomingQueue(workState);
				}
			}
		}
	}

	class SendWorkAsync implements Runnable {
		public void run() {
			while(diabloMiner.getRunning()) {
				WorkState workState = null;

				try {
					workState = sendQueue.take();
				} catch(InterruptedException e) {
					continue;
				}

				if(workState != null) {
					boolean accepted;

					try {
						accepted = doSendWorkMessage(workState);
					} catch (IOException e) {
						diabloMiner.error("Cannot connect to " + queryUrl.getHost() + ": " + e.getLocalizedMessage());
						sendQueue.addFirst(workState);

					try {
						if(!noDelay)
							Thread.sleep(250);
						} catch(InterruptedException f) { }

						continue;
					}

					if(accepted) {
						diabloMiner.info(queryUrl.getHost() + " accepted block " + diabloMiner.incrementBlocks() + " from " + workState.getExecutionState().getExecutionName());
					} else {
						diabloMiner.info(queryUrl.getHost() + " rejected block " + diabloMiner.incrementRejects() + " from " + workState.getExecutionState().getExecutionName());
						diabloMiner.debug("Rejected block " + (float) ((DiabloMiner.now() - workState.timestamp) / 1000.0) + " seconds old, roll ntime set to " + workState.getNetworkState().getRollNTime() + ", rolled " + workState.getRolledNTime() + " times");
					}

					if(rejectReason != null) {
						diabloMiner.info("Reject reason: " + rejectReason);
						rejectReason = null;
					}
				}
			}
		}
	}

	class LongPollAsync implements Runnable {
		public void run() {
			while(diabloMiner.getRunning()) {
				try {
					WorkState workState = doGetWorkMessage(true);
					incomingQueue.add(workState);
					refreshTimestamp.set(workState.getTimestamp());

					diabloMiner.debug(queryUrl.getHost() + ": Long poll returned");
				} catch(IOException e) {
					diabloMiner.error("Cannot connect to " + queryUrl.getHost() + ": " + e.getLocalizedMessage());
				}

				try {
					if(!noDelay)
						Thread.sleep(250);
				} catch(InterruptedException e) { }
			}
		}
	}
}
