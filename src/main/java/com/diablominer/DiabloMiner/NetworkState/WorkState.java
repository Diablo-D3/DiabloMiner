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

import com.diablominer.DiabloMiner.DiabloMiner;
import com.diablominer.DiabloMiner.DeviceState.DeviceState.ExecutionState;

public class WorkState {
	final int[] data = new int[32];
	final int[] midstate = new int[8];
	final long[] target = new long[8];

	long timestamp;
	long base;

	boolean rollNTimeEnable;
	int rolledNTime;

	DiabloMiner diabloMiner;
	NetworkState networkState;
	ExecutionState executionState;

	WorkState(NetworkState networkState) {
		this.networkState = networkState;
		this.diabloMiner = networkState.getDiabloMiner();

		this.timestamp = DiabloMiner.now();
		this.base = 0;
		this.rolledNTime = 0;
	}

	public boolean update(long delta) {
		boolean getWork;

		if((DiabloMiner.now() - timestamp) + 1000 >= networkState.getWorkLifetime()) {
			diabloMiner.debug(executionState.getExecutionName() + ": Refresh work: work expired");
			getWork = true;
		} else if(networkState.getRefreshTimestamp() > timestamp) {
			diabloMiner.debug(executionState.getExecutionName() + ": Refresh work: longpoll");
			getWork = true;
		} else if(base + delta > DiabloMiner.TWO32) {
			if(networkState.getRollNTime()) {
				diabloMiner.debug(executionState.getExecutionName() + ": Rolled NTime");
				base = 0;
				data[17] = Integer.reverseBytes(Integer.reverseBytes(data[17]) + 1);
				rolledNTime++;
				getWork = false;
			} else {
				diabloMiner.debug(executionState.getExecutionName() + ": Refresh work: range expired");
				getWork = true;
			}
		} else {
			base += delta;
			getWork = false;
		}

		if(getWork) {
			networkState.addGetQueue(executionState);
			return true;
		} else {
			return false;
		}
	}

	public void submitNonce(int nonce) {
		data[19] = nonce;

		networkState.addSendQueue(this);
	}

	public long getBase() {
		return base;
	}

	public ExecutionState getExecutionState() {
		return executionState;
	}

	public void setExecutionState(ExecutionState executionState) {
		this.executionState = executionState;
	}

	public NetworkState getNetworkState() {
		return networkState;
	}

	public int getRolledNTime() {
		return rolledNTime;
	}

	public long getTimestamp() {
		return timestamp;
	}

	public int[] getData() {
		return data;
	}

	public int getData(int n) {
		return data[n];
	}

	public void setData(int n, int x) {
		data[n] = x;
	}

	public int getMidstate(int n) {
		return midstate[n];
	}

	public int[] getMidstate() {
		return midstate;
	}

	public void setMidstate(int n, int x) {
		midstate[n] = x;
	}

	public long getTarget(int n) {
		return target[n];
	}

	public void setTarget(int n, long x) {
		target[n] = x;
	}
}
