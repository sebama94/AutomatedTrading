//+------------------------------------------------------------------+
//|                                                           NN.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#define MAX_LAYERS 10
#define MAX_NEURONS 1024

//+------------------------------------------------------------------+
//| Neural Network Class                                             |
//+------------------------------------------------------------------+
class NeuralNetwork
  {
private:
   int               m_numLayers;
   int               m_layerSizes[MAX_LAYERS];
   double            m_neurons[MAX_LAYERS][MAX_NEURONS];
   double            m_weights[MAX_LAYERS-1][MAX_NEURONS][MAX_NEURONS];
   double            m_biases[MAX_LAYERS-1][MAX_NEURONS];
   double            m_learningRate;

public:
                     NeuralNetwork(double learningRate=0.01);
                    ~NeuralNetwork();
   
   bool              Initialize(int &layerSizes[], int numLayers);
   void              SetWeights(double &weights[]);
   void              SetBiases(double &biases[]);
   void              FeedForward(double &inputs[]);
   void              GetOutputs(double &outputs[]);
   void              BuildModel(int &layerSizes[], int numLayers);
   void              Train(double &inputs[], double &targets[], int epochs, double learningRate, int batchSize);
   void              PrintWeights();
   
private:
   double            Activate(double x);
   double            ActivateDerivative(double x);
   void              BackPropagate(double &inputs[], double &targets[], double learningRate);
   double            MeanSquaredError(double &targets[], double &outputs[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
NeuralNetwork::NeuralNetwork(double learningRate=0.01)
  {
   m_numLayers = 0;
   m_learningRate = learningRate;
   ArrayInitialize(m_layerSizes, 0);
   ArrayInitialize(m_neurons, 0);
   ArrayInitialize(m_weights, 0);
   ArrayInitialize(m_biases, 0);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
NeuralNetwork::~NeuralNetwork()
  {
  }

//+------------------------------------------------------------------+
//| Initialize the neural network                                    |
//+------------------------------------------------------------------+
bool NeuralNetwork::Initialize(int &layerSizes[], int numLayers)
  {
   if(numLayers > MAX_LAYERS)
     {
      Print("Error: Number of layers exceeds MAX_LAYERS");
      return false;
     }

   m_numLayers = numLayers;
   
   for(int i = 0; i < numLayers; i++)
     {
      if(layerSizes[i] > MAX_NEURONS)
        {
         Print("Error: Number of neurons in layer ", i, " exceeds MAX_NEURONS");
         return false;
        }
      m_layerSizes[i] = layerSizes[i];
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Set weights for the neural network                               |
//+------------------------------------------------------------------+
void NeuralNetwork::SetWeights(double &weights[])
  {
   int index = 0;
   for(int layer = 0; layer < m_numLayers - 1; layer++)
     {
      for(int i = 0; i < m_layerSizes[layer+1]; i++)
        {
         for(int j = 0; j < m_layerSizes[layer]; j++)
           {
            if(index >= ArraySize(weights))
              {
               Print("Error: Weights array is smaller than expected");
               return;
              }
            m_weights[layer][i][j] = weights[index++];
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Set biases for the neural network                                |
//+------------------------------------------------------------------+
void NeuralNetwork::SetBiases(double &biases[])
  {
   int index = 0;
   for(int layer = 0; layer < m_numLayers - 1; layer++)
     {
      for(int i = 0; i < m_layerSizes[layer+1]; i++)
        {
         if(index >= ArraySize(biases))
           {
            Print("Error: Biases array is smaller than expected");
            return;
           }
         m_biases[layer][i] = biases[index++];
        }
     }
  }

//+------------------------------------------------------------------+
//| Feed forward through the neural network                          |
//+------------------------------------------------------------------+
void NeuralNetwork::FeedForward(double &inputs[])
  {
   if(ArraySize(inputs) < m_layerSizes[0])
     {
      Print("Error: Input size is smaller than the input layer size");
      return;
     }
   
   // Set input layer
   for(int i = 0; i < m_layerSizes[0]; i++)
     {
      m_neurons[0][i] = inputs[i];
     }
   
   // Feed forward through hidden layers and output layer
   for(int layer = 1; layer < m_numLayers; layer++)
     {
      for(int i = 0; i < m_layerSizes[layer]; i++)
        {
         double sum = 0;
         for(int j = 0; j < m_layerSizes[layer-1]; j++)
           {
            sum += m_neurons[layer-1][j] * m_weights[layer-1][i][j];
           }
         sum += m_biases[layer-1][i];
         m_neurons[layer][i] = Activate(sum);
        }
     }
  }

//+------------------------------------------------------------------+
//| Get the outputs of the neural network                            |
//+------------------------------------------------------------------+
void NeuralNetwork::GetOutputs(double &outputs[])
  {
   int outputLayer = m_numLayers - 1;
   if(ArrayResize(outputs, m_layerSizes[outputLayer]) != m_layerSizes[outputLayer])
     {
      Print("Error: Failed to resize outputs array");
      return;
     }
   for(int i = 0; i < m_layerSizes[outputLayer]; i++)
     {
      outputs[i] = m_neurons[outputLayer][i];
     }
  }

//+------------------------------------------------------------------+
//| Build the model                                                  |
//+------------------------------------------------------------------+
void NeuralNetwork::BuildModel(int &layerSizes[], int numLayers)
  {
   if(Initialize(layerSizes, numLayers))
     {
      double weights[];
      double biases[];
      int totalWeights = 0;
      int totalBiases = 0;
      
      for(int i = 0; i < numLayers - 1; i++)
        {
         totalWeights += layerSizes[i] * layerSizes[i+1];
         totalBiases += layerSizes[i+1];
        }
      
      if(ArrayResize(weights, totalWeights) != totalWeights || ArrayResize(biases, totalBiases) != totalBiases)
        {
         Print("Error: Failed to resize weights or biases array");
         return;
        }
      
      int weightIndex = 0;
      int biasIndex = 0;
      
      for(int layer = 0; layer < numLayers - 1; layer++)
        {
         int fanIn = layerSizes[layer];
         int fanOut = layerSizes[layer + 1];
         double scale = MathSqrt(2.0 / (fanIn + fanOut));
         
         for(int i = 0; i < fanOut; i++)
           {
            for(int j = 0; j < fanIn; j++)
              {
               weights[weightIndex++] = scale * (2.0 * MathRand() / 32768.0 - 1.0);
              }
            biases[biasIndex++] = 0.0; // Initialize biases to zero
           }
        }
      
      SetWeights(weights);
      SetBiases(biases);
     }
   else
     {
      Print("Failed to initialize the neural network");
     }
  }

//+------------------------------------------------------------------+
//| Activation function (ReLU)                                       |
//+------------------------------------------------------------------+
double NeuralNetwork::Activate(double x)
  {
   return MathMax(0, x);
  }

//+------------------------------------------------------------------+
//| Derivative of activation function (ReLU)                         |
//+------------------------------------------------------------------+
double NeuralNetwork::ActivateDerivative(double x)
  {
   return x > 0 ? 1 : 0;
  }

//+------------------------------------------------------------------+
//| Back propagation                                                 |
//+------------------------------------------------------------------+
void NeuralNetwork::BackPropagate(double &inputs[], double &targets[], double learningRate)
  {
   FeedForward(inputs);
   
   int outputLayer = m_numLayers - 1;
   double errors[MAX_LAYERS][MAX_NEURONS];
   
   if(ArraySize(targets) < m_layerSizes[outputLayer])
     {
      Print("Error: Targets array is smaller than the output layer size");
      return;
     }
   
   // Calculate output layer errors
   for(int i = 0; i < m_layerSizes[outputLayer]; i++)
     {
      double error = targets[i] - m_neurons[outputLayer][i];
      errors[outputLayer][i] = error * ActivateDerivative(m_neurons[outputLayer][i]);
     }
   
   // Backpropagate errors
   for(int layer = outputLayer; layer > 0; layer--)
     {
      for(int i = 0; i < m_layerSizes[layer]; i++)
        {
         // Update biases
         m_biases[layer-1][i] += learningRate * errors[layer][i];
         
         // Update weights
         for(int j = 0; j < m_layerSizes[layer-1]; j++)
           {
            m_weights[layer-1][i][j] += learningRate * errors[layer][i] * m_neurons[layer-1][j];
           }
        }
      
      // Calculate errors for the previous layer
      if(layer > 1)
        {
         for(int j = 0; j < m_layerSizes[layer-1]; j++)
           {
            double error = 0;
            for(int i = 0; i < m_layerSizes[layer]; i++)
              {
               error += errors[layer][i] * m_weights[layer-1][i][j];
              }
            errors[layer-1][j] = error * ActivateDerivative(m_neurons[layer-1][j]);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Train the neural network                                         |
//+------------------------------------------------------------------+
void NeuralNetwork::Train(double &inputs[], double &targets[], int epochs, double learningRate, int batchSize)
  {
   int inputSize = ArraySize(inputs) / m_layerSizes[0];
   int targetSize = ArraySize(targets) / m_layerSizes[m_numLayers-1];
   
   if(inputSize != targetSize)
     {
      Print("Error: Number of input samples does not match number of target samples");
      return;
     }
   
   int numBatches = (int)MathCeil((double)inputSize / batchSize);
   
   for(int epoch = 0; epoch < epochs; epoch++)
     {
      for(int batch = 0; batch < numBatches; batch++)
        {
         int startIdx = batch * batchSize;
         int endIdx = MathMin(startIdx + batchSize, inputSize);
         int batchInputSize = endIdx - startIdx;
         
         double batchInputs[];
         double batchTargets[];
         
         if(ArrayResize(batchInputs, batchInputSize * m_layerSizes[0]) != batchInputSize * m_layerSizes[0] ||
            ArrayResize(batchTargets, batchInputSize * m_layerSizes[m_numLayers-1]) != batchInputSize * m_layerSizes[m_numLayers-1])
           {
            Print("Error: Failed to resize batch arrays");
            return;
           }
         
         for(int i = 0; i < batchInputSize; i++)
           {
            for(int j = 0; j < m_layerSizes[0]; j++)
              {
               batchInputs[i * m_layerSizes[0] + j] = inputs[(startIdx + i) * m_layerSizes[0] + j];
              }
            for(int j = 0; j < m_layerSizes[m_numLayers-1]; j++)
              {
               batchTargets[i * m_layerSizes[m_numLayers-1] + j] = targets[(startIdx + i) * m_layerSizes[m_numLayers-1] + j];
              }
           }
         
         BackPropagate(batchInputs, batchTargets, learningRate);
        }
      
      if(epoch % 100 == 0)  // Print every 100 epochs
        {
         Print("Epoch ", epoch, ":");
         PrintWeights();
        }
     }
  }

//+------------------------------------------------------------------+
//| Print weights of the neural network                              |
//+------------------------------------------------------------------+
void NeuralNetwork::PrintWeights()
  {
   for(int layer = 0; layer < m_numLayers - 1; layer++)
     {
      Print("Layer ", layer, " weights:");
      for(int i = 0; i < m_layerSizes[layer+1]; i++)
        {
         string weightStr = "";
         for(int j = 0; j < m_layerSizes[layer]; j++)
           {
            weightStr += DoubleToString(m_weights[layer][i][j], 4) + " ";
           }
         Print("  Neuron ", i, ": ", weightStr);
        }
     }
  }

//+------------------------------------------------------------------+
//| Mean Squared Error                                               |
//+------------------------------------------------------------------+
double NeuralNetwork::MeanSquaredError(double &targets[], double &outputs[])
  {
   double sum = 0;
   int size = ArraySize(targets);
   for(int i = 0; i < size; i++)
     {
      double error = targets[i] - outputs[i];
      sum += error * error;
     }
   return sum / size;
  }
