
# Automated Trading System

This project implements an automated trading system using MetaTrader 5 (MQL5) with a neural network for decision-making. The system consists of three main components:

1. `main.mq5`: The main Expert Advisor (EA) script
2. `NN.mqh`: A custom neural network implementation
3. `Currency.mqh`: A class for managing currency-specific operations

## Components

### 1. main.mq5

This is the entry point of the Expert Advisor. It initializes the Currency object, which in turn sets up the neural network. The main functions include:

- `OnInit()`: Initializes the Currency object with the specified parameters
- `OnDeinit()`: Cleans up resources
- `OnTick()`: Executes the main trading logic on each tick

### 2. NN.mqh

This file contains the implementation of a feedforward neural network. Key features include:

- Configurable number of layers and neurons
- Sigmoid activation function
- Backpropagation for training
- Methods for forward propagation and getting outputs

Key methods:
- `Initialize()`: Sets up the network structure
- `SetWeights()` and `SetBiases()`: Configure network parameters
- `FeedForward()`: Processes inputs through the network
- `BackPropagate()`: Adjusts weights and biases during training
- `Train()`: Executes the training process
- `GetOutputs()`: Retrieves the network's output

### 3. Currency.mqh

This class manages currency-specific operations and integrates the neural network for trading decisions. It includes methods for:

- Initializing and training the neural network
- Processing market data
- Executing trades based on neural network outputs
- Managing open positions

Key methods:
- `Init()`: Sets up the Currency object and initializes the neural network
- `Run()`: Executes the main trading logic
- `checkAndCloseSingleProfitOrders()`: Manages individual profitable orders
- `checkAndCloseAllOrdersForProfit()`: Closes all orders if a profit target is met

## Usage

1. Place all three files (`main.mq5`, `NN.mqh`, and `Currency.mqh`) in your MetaTrader 5 Experts folder.
2. Compile the `main.mq5` file.
3. Attach the compiled Expert Advisor to a chart in MetaTrader 5.
4. Configure the input parameters as needed.

## Configuration

The main script allows for configuration of various parameters, including:

- Neural network architecture (number of neurons in each layer)
- Training parameters (epochs, learning rate, batch size)
- Trading parameters (symbol, lot size, profit target)

Please refer to the input parameters in `main.mq5` for a complete list of configurable options.

## System Architecture

The system architecture can be represented by the following diagram:
