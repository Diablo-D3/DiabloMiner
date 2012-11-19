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

package com.diablominer.DiabloMiner.NetworkState;

import java.net.URL;
import java.util.concurrent.LinkedBlockingDeque;
import java.util.concurrent.atomic.AtomicLong;

import com.diablominer.DiabloMiner.DiabloMiner;
import com.diablominer.DiabloMiner.DeviceState.DeviceState.ExecutionState;

public abstract class NetworkState {
	DiabloMiner diabloMiner;

	URL queryUrl;
	String user;
	String pass;

	byte hostChain;
	byte hostProtocol;

	long workLifetime;
	boolean rollNTime;

	AtomicLong refreshTimestamp = new AtomicLong(0);

	LinkedBlockingDeque<ExecutionState> getQueue = new LinkedBlockingDeque<ExecutionState>();
	LinkedBlockingDeque<WorkState> sendQueue = new LinkedBlockingDeque<WorkState>();

	NetworkState networkStateNext = null;

	public static final byte PROTOCOL_JSONRPC = 0;
	public static final byte PROTOCOL_STRATUM = 1;
	public static final byte CHAIN_BITCOIN = 0;
	public static final byte CHAIN_LITECOIN = 1;

	public NetworkState(DiabloMiner diabloMiner, URL queryUrl, String user, String pass, byte hostChain) {
		this.diabloMiner = diabloMiner;
		this.queryUrl = queryUrl;
		this.user = user;
		this.pass = pass;
		this.hostChain = hostChain;
		this.workLifetime = diabloMiner.getWorkLifetime();
		this.rollNTime = false;

		if("stratum".equals(queryUrl.getProtocol()))
			hostProtocol = PROTOCOL_STRATUM;
	}

	public void addGetQueue(ExecutionState executionState) {
		getQueue.add(executionState);
	}

	public void addSendQueue(WorkState workState) {
		sendQueue.add(workState);
	}

	public DiabloMiner getDiabloMiner() {
		return diabloMiner;
	}

	public NetworkState getNetworkStateNext() {
		return networkStateNext;
	}

	public void setNetworkStateNext(NetworkState networkState) {
		networkStateNext = networkState;
	}

	public URL getQueryUrl() {
		return queryUrl;
	}

	public long getWorkLifetime() {
		return workLifetime;
	}

	public long getRefreshTimestamp() {
		return refreshTimestamp.get();
	}

	public boolean getRollNTime() {
		return rollNTime;
	}
}
