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

package com.diablominer.DiabloMiner.DeviceState;

import java.util.concurrent.LinkedBlockingDeque;
import java.util.concurrent.atomic.AtomicLong;

import com.diablominer.DiabloMiner.DiabloMiner;
import com.diablominer.DiabloMiner.DiabloMinerFatalException;
import com.diablominer.DiabloMiner.NetworkState.WorkState;

abstract public class DeviceState {
	String deviceName;
	DiabloMiner diabloMiner;

	double basis;
	AtomicLong deviceHashCount = new AtomicLong(0);

	long resetNetworkState;

	abstract public void checkDevice();

	public double getBasis() {
		return basis;
	}

	public long getDeviceHashCount() {
		return deviceHashCount.get();
	}

	abstract public class ExecutionState implements Runnable  {
		String executionName;

		WorkState workState;
		LinkedBlockingDeque<WorkState> incomingQueue = new LinkedBlockingDeque<WorkState>();

		public ExecutionState(String executionName) throws DiabloMinerFatalException {
			this.executionName = executionName;
			this.workState = null;
		}

		public void addIncomingQueue(WorkState workState) {
			incomingQueue.add(workState);
		}

		abstract public void run();

		public String getExecutionName() {
			return executionName;
		}
	}
}
